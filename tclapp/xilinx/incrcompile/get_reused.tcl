package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::incrcompile {
    namespace export get_reused
}

proc ::tclapp::xilinx::incrcompile::get_reused { args } {
  # Summary : get reused objects

  # Argument Usage:
  # [-cells]: Get reused cells
  # [-ports]: Get reused ports
  # [-sites]: Get reused sites
  # [-nets]: Get reused nets
  # [-pins]: Get reused pins
  # [-reuse_category <arg> = all]: Specify reuse category, valid values are all, fully or partially
  # [-usage]: Usage information

  # Return Value:
  # list of reused objects

  # Categories: xilinxtclstore, incrcompile

  #-------------------------------------------------------
  # Process command line arguments
  #-------------------------------------------------------
  set object {}
  set type {}
  set error 0
  set help 0

  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      -reuse_category -
      {^-reuse_category$} {
           set type [string tolower [lshift args]]
           if {![regexp {^(all|fully|partially)$} $type]} {
             incr error
             puts " -E- the supported values for -reuse_category are all, fully or partially"
           }
      }
      -usage -
      {^-u(s(a(ge?)?)?)?$} {
           set help 1
      }
      -color -
      {^-co(l(or?)?)?$} {
         lshift args
      }
      -cells -
      {^-c(e(l(ls?)?)?)?$} {
           if { $object ne "" } {
             puts "-E- -$object and -cells cannot be used together."
             incr error
           }
           set object {cells}
      }
      -pins -
      {^-pi(ns?)?$} {
           if { $object ne "" } {
             puts "-E- -$object and -pins cannot be used together."
             incr error
           }
           set object {pins}
      }
      -nets -
      {^-n(e(ts?)?)?$} {
           if { $object ne "" } {
             puts "-E- -$object and -nets cannot be used together."
             incr error
           }
           set object {nets}
      }
      -sites -
      {^-s(i(t(es?)?)?)?$} {
           if { $object ne "" } {
             puts "-E- -$object and -sites cannot be used together."
             incr error
           }
           set object {sites}
      }
      -ports -
      {^-po(r(ts?)?)?$} {
           if { $object ne "" } {
             puts "-E- -$object and -ports cannot be used together."
             incr error
           }
           set object {ports}
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
  if { $type ne "" && ($object ne "nets" && $object ne "sites") } {
    puts "-E- Illegal use of argument reuse_category, reuse_category is allowed only with either -sites or -nets."
    incr error
  }
  if { $type eq "" && ($object eq "nets" || $object eq "sites") } {
    set type "all"
  }
  if { $object eq "" } {
    puts "-E- Please specify object type."
    incr error
  }
  if {$help} {
    puts [format {
  Usage: get_reused
              [-cells]             - Get reused cells
              [-sites]             - Get reused sites
              [-ports]             - Get reused ports
              [-nets]              - Get reused nets
              [-pins]              - Get reused pins
              [-reuse_category]    - Specify reuse category. Valid values are all, fully or partially.
              [-usage|-u]          - This help message

  Description: Get reused objects
  Example:
     get_reused -cells
     get_reused -nets
     get_reused -sites -reuse_category fully
} ]
    # HELP -->
    return {}
  }
  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  #-------------------------------------------------------
  # Get reused objects
  #-------------------------------------------------------
  set ret_values {}
  if { $object eq "cells" } {
    set ret_values [get_cells -filter { REUSE_STATUS=="Reused" } -hierarchical ]
  }

  if { $object eq "nets" } {
    if { $type eq "all" } {
      set ret_values [get_nets -filter { REUSE_STATUS=="Reused" || REUSE_STATUS=="PARTIALLY_REUSED" } -hierarchical ]
    } elseif { $type eq "fully" } {
      set ret_values [get_nets -filter { REUSE_STATUS=="Reused" } -hierarchical ]
    } else {
      set ret_values [get_nets -filter { REUSE_STATUS=="PARTIALLY_REUSED" } -hierarchical ]
    }
  }

  if { $object eq "pins" } {
    set ret_values [get_pins -filter { is_reused==1 } -hierarchical ]
  }

  if { $object eq "ports" } {
    set ret_values [get_ports -filter { is_reused==1 }]
  }
  if { $object eq "sites" } {
    set fully_reused_sites "";
    set partially_reused_sites "";
    set non_reused_sites "";
    foreach site [get_sites -filter {IS_USED==1} ] {
      set total [llength [get_cells -of_objects [get_sites $site]]];
      set reused [llength [get_cells -of_objects [get_sites $site] -filter {is_reused==1}]];
      if { $reused == 0 } {
        lappend non_reused_sites $site;
      } elseif { $reused == $total } {
        lappend fully_reused_sites $site;
        lappend reused_sites $site;
      } else {
        lappend partially_reused_sites $site;
        lappend reused_sites $site;
      }
    }
    if { $type eq "all" } {
      set ret_values $reused_sites
    } elseif { $type eq "fully" } {
      set ret_values $fully_reused_sites
    } else {
      set ret_values $partially_reused_sites
    }
  }

  return $ret_values
}
proc ::tclapp::xilinx::incrcompile::lshift {inputlist} {
  # Summary :
  # Argument Usage:
  # Return Value:

  upvar $inputlist argv
  set arg  [lindex $argv 0]
  set argv [lrange $argv 1 end]
  return $arg
}
