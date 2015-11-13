package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export get_inter_slr_nets
}

proc ::tclapp::xilinx::designutils::get_inter_slr_nets { args } {
  # Summary : Get all inter-SLR nets

  # Argument Usage:
  # [-from <arg>]: Source SLR
  # [-to <arg>]: Destination SLR

  # Return Value:
  # list of SLR-crossing net objects

  # Categories: xilinxtclstore, designutils

  #-------------------------------------------------------
  # Process command line arguments
  #-------------------------------------------------------
  set error 0
  set help 0
  set from {}
  set to {}
  while {[llength $args]} {
    set name [::tclapp::xilinx::designutils::lshift args]
    switch -regexp -- $name {
      -from -
      {^-f(r(om?)?)?$} {
           set from [string toupper [::tclapp::xilinx::designutils::lshift args]]
      }
      -to -
      {^-to?$} {
           set to [string toupper [::tclapp::xilinx::designutils::lshift args]]
      }
      -usage -
      {^-u(s(a(ge?)?)?)?$} {
           set help 1
      }
      default {
            if {[string match "-*" $name]} {
              puts " -E- option '$name' is not a valid option. Use the -help option for more details"
              incr error
            } else {
              puts " -E- option '$name' is not a valid option. Use the -help option for more details"
              incr error
            }
      }
    }
  }

  if {$help} {
    puts [format {
  Usage: get_inter_slr_nets
              [-from <SLR>]        - Source SLR (e.g SLR0)
              [-to <SLR>]          - Destination SLR (e.g SLR1)
              [-usage|-u]          - This help message

  Description: Get all inter-SLR nets

     This command returns the inter-SLR nets. By default, all inter-SLR nets
     are returned. The command options -from/-to must be used together to
     filter inter-SLR nets between 2 SLRs.

     This command must be run on a placed or routed design.

  Example:
     set xnets [::xilinx::designutils::get_inter_slr_nets]
     set xnets [::xilinx::designutils::get_inter_slr_nets -from SLR0 -to SLR1]
} ]
    # HELP -->
    return {}
  }

  if {($from == {} && $to != {}) || ($from != {} && $to == {})} {
  	incr error
  	puts " -E- options -from and -to must be used together"
  } elseif {$from != {} && $to != {}} {
  	set SLRs [get_slrs -quiet]
  	if {[lsearch $SLRs $from] == -1} {
  		puts " -E- SLR '$from' does not exist. List of available SLRs: $SLRs"
  		incr error
  	}
  	if {[lsearch $SLRs $to] == -1} {
  		puts " -E- SLR '$to' does not exist. List of available SLRs: $SLRs"
  		incr error
  	}
  	if {($error == 0) && ($from == $to)} {
  		puts " -E- option -from/-to cannot specify the same SLR"
  		incr error
  	}
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  set inter_slr_nets [list]

  # Scenario 1: no source & destination SLR is specified
  if {($from == {}) && ($to == {})} {
    catch {unset ar}
    foreach SLR [get_slrs -quiet] {
      set cells [get_cells -quiet -of [get_sites -quiet -of $SLR]]
      set nets [get_nets -quiet -of $cells -filter {(TYPE != POWER) && (TYPE != GROUND) && (ROUTE_STATUS != INTRASITE)}]
      set props [lsort -uniq [get_property -quiet PARENT $nets]]
      foreach prop $props { lappend ar($prop) $SLR }
    }

    set slrs [list]
    foreach net [array names ar] {
      if {[llength $ar($net)] > 1} {
        lappend slrs $net
      }
    }

    set inter_slr_nets [get_nets -quiet $slrs]
    return $inter_slr_nets
  }

  # Scenario 2: a source & destination SLR is specified
  catch {unset ar}
  set fromSlr $from
  set toSlr $to
  set from_cells [get_cells -quiet -of [get_sites -quiet -of [get_slrs -quiet $fromSlr]]]
  set from_nets [get_nets -quiet -of $from_cells -filter {(TYPE != POWER) && (TYPE != GROUND) && (ROUTE_STATUS != INTRASITE)}]
  set from_props [lsort -uniq [get_property -quiet parent $from_nets]]
  foreach prop $from_props { lappend ar($prop) $fromSlr }

  set to_cells [get_cells -quiet -of [get_sites -quiet -of [get_slrs -quiet $toSlr]]]
  set to_nets [get_nets -quiet -of $to_cells -filter {(TYPE != POWER) && (TYPE != GROUND) && (ROUTE_STATUS != INTRASITE)}]
  set to_props [lsort -uniq [get_property -quiet parent $to_nets]]
  foreach prop $to_props { lappend ar($prop) $toSlr }

  set slrs [list]
  foreach net [array names ar] {
    if {[llength $ar($net)] > 1} {
      lappend slrs $net
    }
  }

  set inter_slr_nets [get_nets -quiet $slrs]

  return $inter_slr_nets
}
