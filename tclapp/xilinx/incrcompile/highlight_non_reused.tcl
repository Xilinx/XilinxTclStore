package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::incrcompile {
    namespace export highlight_non_reused
}

proc ::tclapp::xilinx::incrcompile::highlight_non_reused { args } {
  # Summary : highlight non reused objects

  # Argument Usage:
  # [-cells]: Highlight non reused cells
  # [-ports]: Highlight non reused ports
  # [-sites]: Highlight non reused sites
  # [-nets] : Highlight non reused nets
  # [-pins] : Highlight non reused pins
  # [-color <arg> = green]: Specify color for non reused objects
  # [-usage]: Usage information

  # Return Value:
  # none, objects are highlighted with specified color on GUI

  # Categories: xilinxtclstore, incrcompile

  #-------------------------------------------------------
  # Process command line arguments
  #-------------------------------------------------------
  set object {}
  set help 0
  set color {red}
  set myargs $args

  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      -color -
      {^-c(o(l(or?)?)?)?$} {
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
  Usage: highlight_non_reused
              [-cells]             - Highlight non reused cells
              [-sites]             - Highlight non reused sites
              [-ports]             - Highlight non reused ports
              [-nets]              - Highlight non reused nets
              [-pins]              - Highlight non reused pins
              [-color <arg>=green] - Specify color for non reused objects
              [-usage|-u]          - This help message

  Description: Highlight non reused objects
  Example:
     highlight_non_reused -cells
     highlight_non_reused -nets
} ]
    # HELP -->
    return {}
  }

  #-------------------------------------------------------
  # Highlight non reused objects
  #-------------------------------------------------------
  highlight_objects -color $color [uplevel ::tclapp::xilinx::incrcompile::get_non_reused $myargs]
}
