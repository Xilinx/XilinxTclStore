####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export bisectPblock
}

proc ::tclapp::xilinx::designutils::bisectPblock {{pb {}} {first {top}} {second {left}} } {
    # Summary : bisect a P block
    
    # Argument Usage:
    # [pb={}] :
    # [first=top] :
    # [second=left] :
    
    # Return Value:
    # none
    
    if {$first != "bottom" && $first != "top"} {
        puts "ERROR!  Unknown option $first - expecting \"bottom\" or \"top\""
        return
    }
    if {$second != "left" && $second != "right"} {
        puts "ERROR!  Unknown option $second - expecting \"left\" or \"right\""
        return
    }
    set rangeList [get_property GRID_RANGES $pb]
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
            puts "DEBUG_NEWRANGE:  $newRange"
            resize_pblock -remove $range -locs keep_all $pb
            resize_pblock -add $newRange $pb
        }
    }
}


