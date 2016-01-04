package require Vivado 1.2015.1

namespace eval ::tclapp::xilinx::incrcompile {
    namespace export disable_auto_incremental_compile
}

proc ::tclapp::xilinx::incrcompile::disable_auto_incremental_compile { args } {
  # Summary : Disables the auto detection and enablement of incremental flow. 

  # Argument Usage:
  # [-usage]: Usage information

  # Return Value:
  # 

  # Categories: xilinxtclstore, incrcompile


  #-------------------------------------------------------
  # Process command line arguments
  #-------------------------------------------------------
  set help 0
  set error 0

  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
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
  if {$help} {
    puts [format {
  Usage: disable_auto_incremental_compile: Disables the auto detection and enablement of incremental flow. 
         [-usage|-u]          - This help message

  Description: Disables Auto Detection and Enablement of Incremental Compile Flow.
  Examples:
     	::xilinx::incrcompile::disable_auto_incremental_compile

  Also See:
			::xilinx::incrcompile::enable_auto_incremental_compile
	
} ]
    # HELP -->
    return {}
  }
  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }


# if help or err should return before this
  #-------------------------------------------------------
  # sainath reddy
  #-------------------------------------------------------
  if {[isLaunchRunsSwappedWithIncr]} {
    swapIncrLaunchRunsWithLaunchRuns
    variable ::tclapp::xilinx::incrcompile::autoIncrCompileScheme 
    variable ::tclapp::xilinx::incrcompile::autoIncrCompileScheme_RunName
    puts "AutoIncrementalCompile: Disabled " 
    set ::tclapp::xilinx::incrcompile::autoIncrCompileScheme  ""
    set ::tclapp::xilinx::incrcompile::autoIncrCompileScheme_RunName ""
  } else {
    puts "AutoIncrementalCompile: Is Already Disabled"
  }
}

proc ::tclapp::xilinx::incrcompile::swapIncrLaunchRunsWithLaunchRuns {} {
  # Summary :
  # Argument Usage :
  # Return Value :

  variable ::tclapp::xilinx::incrcompile::swapRuns
	uplevel 2 rename ::launch_runs 				::tclapp::xilinx::incrcompile::incr_launch_runs 
	uplevel 2 rename ::_real_launch_runs 	::launch_runs 
  set ::tclapp::xilinx::incrcompile::swapRuns 0
}

