package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export check_cdc_paths
}

proc ::tclapp::xilinx::designutils::check_cdc_paths {args} {
  # Summary : Checks all the Cross Domain Crossing paths for typical issues
  
  # Argument Usage: 
  # [-no_reset_paths] : Set this parameter if you want to skip asynchronous reset paths from the analysis.

  # Return Value:
  # 0
  
  # Categories: xilinxtclstore, designutils

  uplevel ::tclapp::xilinx::designutils::check_cdc_paths::check_cdc_paths $args
  return 0
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils::check_cdc_paths { 
  variable messages [list]
} ]

proc ::tclapp::xilinx::designutils::check_cdc_paths::check_cdc_paths {args} {
  # Summary: Checks all the CDC paths for typical issues
  
  # Argument Usage:
    
  # Return Value:
  # 0
  
  # Categories: xilinxtclstore, designutils
	
	## Set Default option values
	array set opts {}
	
	## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
        switch -regexp -- [lindex $args 0] {
			{-n(o(_(r(e(s(e(t(_(p(a(t(h(s)?)?)?)?)?)?)?)?)?)?)?)?)?$}  { set opts(-no_reset_paths) 1}
             default {
                return -code error "ERROR: \[check_cdc_paths\] Unknown option '[lindex $args 0]', please type 'check_cdc_paths -help' for usage info."
            }
        }
        lshift args
	}
    
	
  variable messages
  set messages [list]

  # Initialize the table objects
  set table [::tclapp::xilinx::designutils::prettyTable create {Summary of Crossing Clock Domain Issues}]
  $table header [list {From clock} {To Clock} {# CDC Paths} {# Paths with Sync Error} {Status}]
  set detailedTable [::tclapp::xilinx::designutils::prettyTable create]
  $detailedTable header [list {Path} {Status}]

  set clkList [get_clocks]
  foreach clk1 $clkList {
    foreach clk2 [filter $clkList "NAME != $clk1"] {
      if {[areClocksRelated $clk1 $clk2]} {
        # If the clocks are obviously related - don't check for synchronizer chain
        # Skipping because clocks appear to be related
        continue
      }
      set info {}
	  
	  # Ignore timing paths on asynchronous reset paths. These are not always synchronized to the destination clock, 
	  # and a false path is applied on them.
	  # Sometimes we want to put aside these paths and concentrate on the real crossings. 
	  set filter {}
	  if {[info exists opts(-no_reset_paths)]} {
		set filter {ENDPOINT_PIN !~ */CLR && ENDPOINT_PIN !~ */PRE}
	  }  
	  
      # -quiet suppresses warnings when no paths are found
      set paths [get_timing_paths -quiet -max_paths 101 -unique_pins -nworst 1 -from $clk1 -to $clk2 -filter $filter]
      set error 0
      foreach path $paths {
        if {![checkPathSynchronizer $path]} {
          set info "Some paths do not appear to be properly synchronized"
          incr error
        }
      }
      if {$info != {}} {
        if {[llength $paths] > 100} {
          set nbrPaths {100+}
        } else {
          set nbrPaths [llength $paths]
        }
        if {$error > 100} {
          set error {100+}
        }
        $table addrow [list $clk1 $clk2 $nbrPaths $error $info ]
      }
    }
  }
  puts [$table print]

  foreach msg $messages {
    foreach {path info} $msg {break}
    $detailedTable addrow [list $path $info]
  }
  $detailedTable configure -title "Details of Crossing Clock Domain Issues ([$detailedTable numrows])"
  puts [$detailedTable print]

  # Destroy the table objects to free memory
  catch {$table destroy}
  catch {$detailedTable destroy}
  
  # Release memory
  set messages [list]
  
  return 0
}

proc ::tclapp::xilinx::designutils::check_cdc_paths::checkPathSynchronizer {timingPath} {
  # Summary : Check for clock domain synchronization
  
  # Argument Usage:
  # timingPath : list of timing paths
  
  # Return Value:
  # returns 0 if paths are found between clock domains 
  # and they are not properly synchronized 1 otherwise
  
  # Categories: xilinxtclstore, designutils

  variable messages
  if {$timingPath == {}} {
    # nothing to check
    return 1
  }
  set logic_levels [get_property LOGIC_LEVELS $timingPath]
  if { $logic_levels > 1} {
    # Inter-clock path has > 1 logic level on path $timingPath
    # You have a non-synchronized inter-clock path!
    # This path has more than 1 level of logic $timingPath
    lappend messages [list $timingPath [format {Inter-clock path has > 1 logic level (%s levels)} $logic_levels] ]
    return 0
  } else {
    set endPoint [get_pin [get_property ENDPOINT_PIN $timingPath]]
    set startPoint [get_pin [get_property STARTPOINT_PIN $timingPath]]
    if {[get_property CLASS $startPoint] != "pin" ||
        [get_property CLASS $endPoint] != "pin"} {
      # if this path starts at anything other than a pin (eg a port) then
      # this is not a synchronizer, report a warning and return
      # You have a non-synchronized inter-clock path!
      # This path does not start and end at a cell pin $timingPath
      lappend messages [list $timingPath {Path does not start or end at a cell pin}]
      return 0
    }
    set endPointCell [get_cells -of $endPoint]
    set startPointCell [get_cells -of [get_pins $startPoint]]
    set startPrimitive [get_property PRIMITIVE_SUBGROUP $startPointCell]
    set endPrimitive [get_property PRIMITIVE_SUBGROUP $endPointCell]
    if {($startPrimitive != "flop") &&
        ($endPrimitive != "flop")} {
      # You have a non-synchronized inter-clock path!
      # This path does not start and end at synchronous flip flops $timingPath
      lappend messages [list $timingPath [format {Path does not start (%s) & end (%s) with synchronous registers} $startPrimitive $endPrimitive ] ]
      return 0
    } elseif {$startPrimitive != "flop"} {
      # You have a non-synchronized inter-clock path!
      # This path does not start and end at synchronous flip flops $timingPath
      lappend messages [list $timingPath [format {Path does not start (%s) at synchronous register} $startPrimitive] ]
      return 0
    } elseif {$endPrimitive != "flop"} {
      # You have a non-synchronized inter-clock path!
      # This path does not start and end at synchronous flip flops $timingPath
      lappend messages [list $timingPath [format {Path does not end (%s) at synchronous register} $endPrimitive] ]
      return 0
    }
    # Looks like this might be a synchronizer chain! $timingPath
    if {[get_property ASYNC_REG $endPointCell] != 1} {
      # You have a inter-clock path that is not properly synchronized!
      # You have a path that might be a synchronizer chain but it does not have ASYNC_REG attribute on the end cell $endPointCell
      lappend messages [list $timingPath {Missing ASYNC_REG attribute on the 1st synchronizer register}]
      return 0
    }
    # TODO - A sync chain can be N levels - this will go down 1 level.
    # TODO - this could be recursive
    # TODO - we could pass number of levels to trace in as a param
    set downPath [get_timing_paths -from $endPointCell]
    # Found downstream path:  $downPath
    if {[get_property LOGIC_LEVELS $downPath] > 1} {
      # Downstream path has > 1 logic level: $downPath
      # This is not properly synchronized:  $timingPath
      lappend messages [list $timingPath [format {Downstream path has > 1 logic level (%s)} $downPath] ]
      return 0
    }
    set endPointCell [get_cells -of [get_pin [get_property ENDPOINT_PIN $downPath]]]
    if {[get_property ASYNC_REG $endPointCell] != 1} {
      # You have a inter-clock path that is not properly synchronized!
      # You have a path that might be a synchronizer chain but it does not have ASYNC_REG attribute on the end cell $endPointCell
      lappend messages [list $timingPath {Missing ASYNC_REG attribute on the 2nd synchronizer register}]
      return 0
    }
    # INFO:  Suggested set_max_delay -datapath_only command that is equivalent to DATAPATHONLY in ISE TRCE:
    #  set_max_delay -datapath_only -from $startPoint -to $endpoint 0.5
  }
  # there are no non-synchronized paths found - exit with true return code
  return 1
}

proc ::tclapp::xilinx::designutils::check_cdc_paths::lcm {p q} {
  # Summary: compute the least common multiple; currently only works on integers

  # Argument Usage:
  # p : first integer
  # q : second integer

  # Return Value:   
  # the least common multiple of the input integers
  
  # Categories: xilinxtclstore, designutils

  set m [expr {$p * $q}]
  if {!$m} {return 0}
  while 1 {
    #      set p [expr {$p % $q}]
    set p [expr fmod($p,$q)]
    if {!$p} {return [expr {$m / $q}]}
    #      set q [expr {$q % $p}]
    set q [expr fmod($q,$p)]
    if {!$q} {return [expr {$m / $p}]}
  }
}

proc ::tclapp::xilinx::designutils::check_cdc_paths::areClocksRelated {clk1 clk2} {
  # Summary: checks to see if 2 clocks are related

  # Argument Usage:
  # clk1 : first clock
  # clk2 : second clock
  
  # Return Value:
  # returns 1 if they are and 0 if not
  
  # TODO - check generated clocks and return related
  set period1 [get_property PERIOD $clk1]
  set period2 [get_property PERIOD $clk2]
  if {$period1 == $period2} {
    # assume the clocks are related if the period is the same
    return 1
  } else {
    # if the least common multiple is greater than a huge number
    # then we assume the clocks have no integer multiple
    # and the clocks are asyncronous
    set mult [lcm $period1 $period2]
    if {$mult < 1000000} {
      return 1
    } else {
      #         puts "DEBUG:  $clk1 $period1 $clk2 $period2 $mult"
      # the clocks are not related
      return 0 
    }
  }
  # assume the clocks are related
  return 1
}

# #########################################################
#  lshift
# #########################################################
proc ::tclapp::xilinx::designutils::check_cdc_paths::lshift {varname {nth 0}} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	upvar $varname args
	set r [lindex $args $nth]
	set args [lreplace $args $nth $nth]
	return $r
}
