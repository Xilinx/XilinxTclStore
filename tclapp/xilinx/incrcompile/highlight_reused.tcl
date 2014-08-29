package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::incrcompile {
    namespace export highlight_reused
}

proc ::tclapp::xilinx::incrcompile::highlight_reused { args } {
  # Summary : highlight reused objects

  # Argument Usage:
  # [-cells]: Highlight reused cells
  # [-ports]: Highlight reused ports
  # [-sites]: Highlight reused sites
  # [-nets] : Highlight reused nets
  # [-pins] : Highlight reused pins
  # [-color <arg> = green]: Specify color for reused objects
  # [-reuse_category <arg> = all]: Specify reuse category, valid values are all, fully or partially
  # [-usage]: Usage information

  # Return Value:
  # none, objects are highlighted with specified color on GUI

  # Categories: xilinxtclstore, incrcompile

  #-------------------------------------------------------
  # Process command line arguments
  #-------------------------------------------------------
  set object {}
  set type {}
  set help 0
  set color {green}
  set myargs $args

  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      -color -
      {^-co(l(or?)?)?$} {
         set color [string tolower [lshift args]]
      }
      -usage -
      {^-u(s(a(ge?)?)?)?$} {
         set help 1
      }
      default {
      }
    }
  }
  if {$help} {
    puts [format {
  Usage: highlight_reused
              [-cells]             - Highlight reused cells
              [-sites]             - Highlight reused sites
              [-ports]             - Highlight reused ports
              [-nets]              - Highlight reused nets
              [-pins]              - Highlight reused pins
              [-reuse_category]    - Specify reuse category. Valid values are all, fully or partially.
              [-color <arg>=green] - Specify color for reused objects
              [-usage|-u]          - This help message

  Description: Highlight reused objects
  Example:
     highlight_reused -cells
     highlight_reused -nets
     highlight_reused -sites -reuse_category fully
} ]
    # HELP -->
    return {}
  }

  #-------------------------------------------------------
  # Highlight reused objects
  #-------------------------------------------------------
  highlight_objects -color $color [uplevel ::tclapp::xilinx::incrcompile::get_reused $myargs]
}
