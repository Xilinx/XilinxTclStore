package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::incrcompile {
    namespace export get_non_reused
}

proc ::tclapp::xilinx::incrcompile::get_non_reused { args } {
  # Summary : get non reused objects

  # Argument Usage:
  # [-cells]: Get reused cells
  # [-ports]: Get reused ports
  # [-sites]: Get reused sites
  # [-nets]: Get reused nets
  # [-pins]: Get reused pins
  # [-usage]: Usage information

  # Return Value:
  # list of non reused objects

  # Categories: xilinxtclstore, incrcompile

  set object {}
  set error 0
  set help 0

  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
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
              puts " -E- option '$name' is not a valid option. Use the -help option for more details"
              incr error
            } else {
              puts " -E- option '$name' is not a valid option. Use the -help option for more details"
              incr error
            }
      }
    }
  }
  if { $object eq "" } {
    puts "-E- Please specify object type."
    incr error
  }
  if {$help} {
    puts [format {
  Usage: get_non_reused
              [-cells]             - Get non reused cells
              [-sites]             - Get non reused sites
              [-ports]             - Get non reused ports
              [-nets]              - Get non reused nets
              [-pins]              - Get non reused pins
              [-usage|-u]          - This help message

  Description: Get non reused objects
  Example:
     get_non_reused -cells
     get_non_reused -nets
} ]
    # HELP -->
    return {}
  }
  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  #-------------------------------------------------------
  # Get non reused objects
  #-------------------------------------------------------
  set ret_values {}
  if { $object eq "cells" } {
    set ret_values [get_cells -filter { IS_REUSED ==0 && IS_PRIMITIVE==1 && REF_NAME!=GND && REF_NAME!=VCC} -hierarchical ]
  }

  if { $object eq "nets" } {
    set ret_values [get_nets -filter { REUSE_STATUS=="NON_REUSED" && ROUTE_STATUS!=INTRASITE} -hierarchical ]
  }

  if { $object eq "pins" } {
    set ret_values [get_pins -filter { is_reused==0 } -hierarchical ]
  }

  if { $object eq "ports" } {
    set ret_values [get_ports -filter { is_reused==0 }]
  }
  if { $object eq "sites" } {
    set non_reused_sites "";
    foreach site [get_sites -filter {IS_USED==1} ] {
      set reused [llength [get_cells -of_objects [get_sites $site] -filter {is_reused==1}]];
      if { $reused == 0 } {
        lappend non_reused_sites $site;
      }
    }
    set ret_values $non_reused_sites
  }
  return $ret_values
}
