
########################################################################################
## 10/20/2015 - Initial release
########################################################################################

###########################################################################
##
## Common Procedures for Designutils
##
###########################################################################

package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
}

proc ::tclapp::xilinx::designutils::lshift {inputlist} {
  # Summary :
  # Argument Usage:
  # Return Value:

  upvar $inputlist argv
  set arg  [lindex $argv 0]
  set argv [lrange $argv 1 end]
  return $arg
}

# Alias to make lshift easy to find/use from other namespaces
# interp alias {} lshift {} ::tclapp::xilinx::designutils::lshift

proc ::tclapp::xilinx::designutils::getArchitecture {} {
  # Summary :
  # Argument Usage:
  # Return Value:

  # Example of returned value: artix7 diabloevalarch elbertevalarch kintex7 kintexu kintexum olyevalarch v7evalarch virtex7 virtex9 virtexu virtexum zynq zynque ...
  #    7-Serie    : artix7 kintex7 virtex7 zynq
  #    UltraScale : kintexu kintexum virtexu virtexum
  #    Diablo (?) : virtex9 virtexum zynque
  return [get_property -quiet ARCHITECTURE [get_property -quiet PART [current_project]]]
}

proc ::tclapp::xilinx::designutils::max {x y} {
  # Summary :
  # Argument Usage:
  # Return Value:

  return [expr {$x>$y?$x:$y}]
}

proc ::tclapp::xilinx::designutils::min {x y} {
  # Summary :
  # Argument Usage:
  # Return Value:

  return [expr {$x<$y? $x:$y}]
}


##-----------------------------------------------------------------------
## duration
##-----------------------------------------------------------------------
## Convert a number of seconds in a human readable string.
## Example:
##      set startTime [clock seconds]
##      ...
##      set endTime [clock seconds]
##      puts "The runtime is: [duration [expr $endTime - $startTime]]"
##-----------------------------------------------------------------------

proc ::tclapp::xilinx::designutils::duration { int_time } {
  # Summary :
  # Argument Usage:
  # Return Value:

   set timeList [list]
   if {$int_time == 0} { return "0 sec" }
   foreach div {86400 3600 60 1} mod {0 24 60 60} name {day hr min sec} {
     set n [expr {$int_time / $div}]
     if {$mod > 0} {set n [expr {$n % $mod}]}
     if {$n > 1} {
       lappend timeList "$n ${name}s"
     } elseif {$n == 1} {
       lappend timeList "$n $name"
     }
   }
   return [join $timeList]
}
