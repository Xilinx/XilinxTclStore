package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export bisect_pblock
}

proc ::tclapp::xilinx::designutils::bisect_pblock {{pb {}} {first {top}} {second {left}} } {
  # Summary : Bisect a PBlock

  # Argument Usage:
  # pb : PBlock (default: )
  # first : default: top
  # second : default: left

  # Return Value:
  # 0

  # Categories: xilinxtclstore, designutils

  if {$first != "bottom" && $first != "top"} {
    error " error - unknown option $first - expecting \"bottom\" or \"top\""
 }
  if {$second != "left" && $second != "right"} {
    error " error - unknown option $second - expecting \"left\" or \"right\""
  }
  set rangeList [get_property -quiet GRID_RANGES $pb]
  foreach range $rangeList {
    if {[regexp {^SLICE} $range]} {
      # pull out the x and y coordinates from the range string
      regexp {_X(\d+)Y(\d+):.+_X(\d+)Y(\d+)} $range result x1 y1 x2 y2
      #         puts "DEBUG:  $pb $x1 $y1 $x2 $y2"
      set newRange ""
      set xBound [expr $x1 + (($x2 - $x1) / 2)]
      set yBound [expr $y1 + (($y2 - $y1) / 2)]
      if {$first == "top"} {
        if {$second == "left"} {
          set newX1 $x1
          set newX2 [expr $x1 + 1]
          for {set y $y1} {$y <= $y2} {incr y} {
            set newRange "$newRange SLICE_X${x1}Y${y}:SLICE_X${newX2}Y${y}"
            #         puts "DEBUG_TL:  $y $newRange"
            if {[expr $y % 2] == 1} {
              incr newX2 2
            }
          }
        } else {
          set newX1 [expr $x2 - 1]
          set newX2 $x2
          for {set y $y1} {$y <= $y2} {incr y} {
            set newRange "$newRange SLICE_X${newX1}Y${y}:SLICE_X${newX2}Y${y}"
            #         puts "DEBUG_TR:  $y $newRange"
            if {[expr $y % 2] == 1} {
              incr newX1 -2
            }
          }
        }
      } else {
        if {$second == "left"} {
          set newX1 [expr $x2 - 1]
          set newX2 $x2
          for {set y $y1} {$y <= $y2} {incr y} {
            set newRange "$newRange SLICE_X${x1}Y${y}:SLICE_X${newX2}Y${y}"
            #         puts "DEBUG_BL:  $y $newRange"
            if {[expr $y % 2] == 1} {
              incr newX2 -2
            }
          }
        } else {
          # TODO
          set newX1 $x1
          set newX2 $x2
          for {set y $y1} {$y <= $y2} {incr y} {
            set newRange "$newRange SLICE_X${newX1}Y${y}:SLICE_X${x2}Y${y}"
            #         puts "DEBUG_BR:  $y $newRange"
            if {[expr $y % 2] == 1} {
              incr newX1 2
            }
          }
        }
      }
#       puts "DEBUG_NEWRANGE:  $newRange"
      resize_pblock -remove $range -locs keep_all $pb
      resize_pblock -add $newRange $pb
    }
  }
  return 0
}
