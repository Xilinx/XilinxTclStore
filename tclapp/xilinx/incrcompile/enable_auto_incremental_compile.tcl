package require Vivado 1.2015.1

namespace eval ::tclapp::xilinx::incrcompile {
    namespace export enable_auto_incremental_compile 
}

proc ::tclapp::xilinx::incrcompile::enable_auto_incremental_compile { args } {
  # Summary : Enables the auto detection and enablement of incremental flow. 

  # Argument Usage:
  # [-fixed <arg>]: <arg> run's routed (or placed) checkpoint  will be used a reference checkpoint for subsequent incremental runs
  # [-lastRun]: last modified run's routed (or placed) checkpoint  will be used a reference checkpoint for subsequent incremental runs
  # [-bestWNS]: best WNS runs's routed (or placed) checkpoint will be used as reference checkpoint for subsequent incremental runs
  # [-bestTNS]: best TNS run's routed (or placed) checkpoint will be used as reference checkpoint for subsequent incremental runs 
  # [-usage]: Usage information

  # Return Value:
  # 

  # Categories: xilinxtclstore, incrcompile


  variable ::tclapp::xilinx::incrcompile::autoIncrCompileScheme 
  variable ::tclapp::xilinx::incrcompile::autoIncrCompileScheme_RunName
  variable ::tclapp::xilinx::incrcompile::swapRuns

  #-------------------------------------------------------
  # Process command line arguments
  #-------------------------------------------------------
  if { 0 == [llength $args] } {
   puts " ERROR: Please specify scheme name for incremental flow" 
   error " ERROR: some error(s) happened. Cannot continue"
  }
  set help 0
  set error 0
  set schemeName ""
  while {[llength $args]} {
    set name [::tclapp::xilinx::incrcompile::lshift args]
    switch -regexp -- $name {
      -fixed - 
      {^-f(i(x(ed?)?)?)?$} {
         set schemeName "Fixed"
         set runname [::tclapp::xilinx::incrcompile::lshift args ]
         if {[ string length [ get_runs $runname] ] == 0 } {
          incr error
         } elseif {[string length [ ::tclapp::xilinx::incrcompile::get_placed_or_routed_dcp [get_runs $runname ] ]] } {
           set ::tclapp::xilinx::incrcompile::autoIncrCompileScheme_RunName $runname
         } else {
            puts "AutoIncrementalCompile: $runname provided for -fixed scheme does not have a placed or routed checkpoint to use for incremetnal flow"
            incr error
         }
      }
      -lastRun -
      {^-l(a(s(t(R(un?)?)?)?)?)?$} {
         set schemeName "LastRun"
      }
      -bestWNS - 
      {^-b(e(s(t(W(NS?)?)?)?)?)?$} {
         set schemeName "BestWNS"
      }
      -bestTNS - 
      {^-b(e(s(t(T(NS?)?)?)?)?)?$} {
         set schemeName "BestTNS"
      }
      -usage -
      {^-u(s(a(ge?)?)?)?$} {
           set help 1
      }
      default {
            if {[string match "-*" $name]} {
              puts " ERROR: option '$name' is not a valid option. Use the -usage option for more details"
              incr error
            } else {
              puts " ERROR: option '$name' is not a valid option. Use the -usage option for more details"
              incr error
            }
      }
    }
  }
  if {$help} {
    puts [format {
  Usage: enable_auto_incremental_compile: Enables the auto detection and enablement of incremental flow. 
				 Reference checkpoint for incrmental flow is configured based on the argument provided to enable_auto_incremental_compile
         [-lastRun]          	- Last Modified Run
         [-fixed <run_name>]	- <run_names> 
         [-bestWNS]          	- Run with the best WNS.
         [-bestTNS]           - Run with the best TNS.
         [-usage|-u]          - This help message

  Description: Enables Auto Detection and Enablement of Incremental Compile Flow.
  
  Examples:
     	::xilinx::incrcompile::enable_auto_incremental_compile -lastRun
     	::xilinx::incrcompile::enable_auto_incremental_compile -fixed impl_1
     	::xilinx::incrcompile::enable_auto_incremental_compile -bestWNS
     	::xilinx::incrcompile::enable_auto_incremental_compile -bestTNS

  Also See:
			::xilinx::incrcompile::disable_auto_incremental_compile
	
} ]
    # HELP -->
    return {}
  }
  if {$error} {
    error " ERROR: some error(s) happened. Cannot continue"
  }


# if help or err should return before this
  #-------------------------------------------------------
  # sainath reddy
  #-------------------------------------------------------
  set ::tclapp::xilinx::incrcompile::autoIncrCompileScheme $schemeName
  puts "AutoIncrementalCompile: Enabled with scheme $::tclapp::xilinx::incrcompile::autoIncrCompileScheme " 
  if {![isLaunchRunsSwappedWithIncr]} {
    swapLaunchRunsWithIncrLaunchRuns
  }
}

# pre-condition: assumes the convention impl_dir/top_routed.dcp
proc ::tclapp::xilinx::incrcompile::get_placed_or_routed_dcp { run } {
  # Summary :
  # Argument Usage:
  # Return Value :

  set dcpFile ""
  set is_impl_run [ get_property  IS_IMPLEMENTATION $run ] 

  if {!$is_impl_run} {
  	return $dcpFile
  }
  #set top 			[ get_property TOP [ get_designs $run] ]
  set impl_dir 	[ get_property DIRECTORY $run ]
  
  if {[::tclapp::xilinx::incrcompile::is_run_routed $run]} {
  	set dcpFile [ glob -directory $impl_dir *_routed.dcp ]
  } elseif {[::tclapp::xilinx::incrcompile::is_run_placed_but_not_routed $run]} {
  	set dcpFile [glob -directory $impl_dir *_placed.dcp ]
  }
	return $dcpFile
}

proc ::tclapp::xilinx::incrcompile::isLaunchRunsSwappedWithIncr {} {
  # Summary :
  # Argument Usage :
  # Return Value :

  variable ::tclapp::xilinx::incrcompile swapRuns
  if {![info exists ::tclapp::xilinx::incrcompile::swapRuns] || $::tclapp::xilinx::incrcompile::swapRuns==0} {
    return 0
  } else {
    return 1
  }
}

proc ::tclapp::xilinx::incrcompile::swapLaunchRunsWithIncrLaunchRuns {} {
  # Summary :
  # Argument Usage:
  # Return Value:

  variable ::tclapp::xilinx::incrcompile ::tclapp::xilinx::incrcompile::swapRuns
	uplevel 2 rename ::launch_runs 			::_real_launch_runs
	uplevel 2 rename ::tclapp::xilinx::incrcompile::incr_launch_runs ::launch_runs
  set ::tclapp::xilinx::incrcompile::swapRuns 1
}
				
proc ::tclapp::xilinx::incrcompile::incr_launch_runs { args } {
  # Summary :
  # Argument Usage:
  # Return Value:

  set orig_args $args
	# takes all arguments of launch_runs
	# parse args to filter out args with switches
	# remaining args are of runs ; set INCREMENTAL_CHECKPOINT property for those runs
	# real_launch_runs with modified INCREMENTAL_CHECKPOINT properties for applicable runs


  while {[llength $args]} {
    set name [::tclapp::xilinx::incrcompile::lshift args]
		# launch_runs  [-jobs <arg>] [-scripts_only] [-lsf <arg>] [-sge <arg>]
     #        [-dir <arg>] [-to_step <arg>] [-next_step] [-host <args>]
     #        [-remote_cmd <arg>] [-email_to <args>] [-email_all]
     #        [-pre_launch_script <arg>] [-post_launch_script <arg>] [-force]
     #        [-quiet] [-verbose] <runs>...

    switch $name {
      -jobs -
      -lsf -
      -sge -
      -dir -
      -to_step -
      -host -
      -remote_cmd -
      -email_to -
      -pre_launch_script -
      -post_launch_script { ::tclapp::xilinx::incrcompile::lshift args; }
			-scripts_only -
      -next_step -
      -email_all -
      -force -
      -quiet -
      -help  -
      -verbose { }
		default {
      ::tclapp::xilinx::incrcompile::configure_incr_flow $name 
      }
    }
		# processing all args ends
   }
  eval ::_real_launch_runs $orig_args 
}

proc ::tclapp::xilinx::incrcompile::configure_incr_flow { run_name } {
  # Summary :
  # Argument Usage:
  # Return Value:

  variable ::tclapp::xilinx::incrcompile autoIncrCompileScheme 
  variable ::tclapp::xilinx::incrcompile autoIncrCompileScheme_RunName

  set run [get_runs $run_name ]

	set all_impl_runs 									[get_runs -filter IS_IMPLEMENTATION]
	set all_impl_runs_placed_or_routed 	[get_impl_runs_placed_or_routed $all_impl_runs]

  puts "AutoIncrementalCompile: Scheme Enabled: $::tclapp::xilinx::incrcompile::autoIncrCompileScheme "
	switch $::tclapp::xilinx::incrcompile::autoIncrCompileScheme {
	LastRun {
	  set refRun [ lindex [ lsort -command compare_runs_dcp_time $all_impl_runs_placed_or_routed ] 0 ]
  } 	 
	Fixed {
	   set refRun [ get_runs $::tclapp::xilinx::incrcompile::autoIncrCompileScheme_RunName ]  
  } 	 
  BestWNS {
		 set refRun [ lindex [ lsort -command compare_runs_wns $all_impl_runs_placed_or_routed ] 0 ]
  } 	 
	BestTNS {
	  set refRun [ lindex [ lsort -command compare_runs_tns $all_impl_runs_placed_or_routed ] 0 ]
  } 	 
  }
	# set the guide file if it exists
	set guideFile [ ::tclapp::xilinx::incrcompile::get_placed_or_routed_dcp $refRun ]
	if {![ file exists $guideFile]} {
		puts "AutoIncrementalCompile: Incremental Flow not enabled as $guideFile for scheme $::tclapp::xilinx::incrcompile::autoIncrCompileScheme does not exist"
		return;
		} else {
			puts "AutoIncrementalCompile: Incremental Flow enabled for $run with $refRun 's  $guideFile as the reference checkpoint"
			set_property INCREMENTAL_CHECKPOINT $guideFile $run
		}
}

proc ::tclapp::xilinx::incrcompile::get_impl_runs_placed_or_routed { impl_runs } {
  # Summary :
  # Argument Usage:
  # Return Value:

	set runs_placed_or_routed [ list  ]
	foreach run $impl_runs {
			if {[::tclapp::xilinx::incrcompile::is_run_routed $run] || [::tclapp::xilinx::incrcompile::is_run_placed_but_not_routed $run] } { 
				lappend runs_placed_or_routed $run
			}
	}
	return $runs_placed_or_routed
}

proc ::tclapp::xilinx::incrcompile::compare_runs_dcp_time {run_a run_b} {
  # Summary :
  # Argument Usage:
  # Return Value:

  set dcp_a [ get_placed_or_routed_dcp $run_a ]
  set dcp_b [ get_placed_or_routed_dcp $run_b ]
  return [ expr {[file mtime $dcp_a] < [file mtime $dcp_b]} ]
}

proc ::tclapp::xilinx::incrcompile::compare_runs_wns {run_a run_b} {
  # Summary :
  # Argument Usage:
  # Return Value:

  set wns_a  [ get_property STATS.WNS $run_a]
  set wns_b  [ get_property STATS.WNS $run_b]
  return [ expr {$wns_a < $wns_b} ]
}

proc ::tclapp::xilinx::incrcompile::compare_runs_tns {run_a run_b} {
  # Summary :
  # Argument Usage:
  # Return Value:

  set tns_a  [ get_property STATS.TNS $run_a]
  set tns_b  [ get_property STATS.TNS $run_b]
  return [ expr {$tns_a < $tns_b} ]
}

proc ::tclapp::xilinx::incrcompile::is_run_routed { run } {
  # Summary :
  # Argument Usage:
  # Return Value:

			return [ string match "route_design Complete*" [ get_property STATUS $run ]  ]
}

proc ::tclapp::xilinx::incrcompile::is_run_placed_but_not_routed { run } {
  # Summary :
  # Argument Usage:
  # Return Value:

			return [ string match "place_design Complete*" [ get_property STATUS $run ]  ]
}

