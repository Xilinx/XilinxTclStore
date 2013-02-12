####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export checkSync checkRelated checkAllRelated
}

proc ::tclapp::xilinx::designutils::checkSync {pathList} {
    # Summary : Check for clock domain synchronization
    
    # Argument Usage:
    # pathList : list of timing paths
    
    # Return Value:
    # returns 0 if paths are found between clock domains 
    # and they are not synchronized 1 otherwise
    
    if {[llength $pathList] == 0} {
        # nothing to check if list is empty
        return 1
    }
    foreach path $pathList {
        puts "DEBUG:  $path"
        if {[get_property LOGIC_LEVELS $path] > 1} {
            puts "DEBUG:  Inter-clock path has > 1 logic level on path $path"
            puts "WARNING:  You have a non-synchronized inter-clock path!"
            puts "WARNING:  This path has more than 1 level of logic $path"
            return 0
        } else {
            set endPoint [get_pin [get_property ENDPOINT_PIN $path]]
            set startPoint [get_pin [get_property STARTPOINT_PIN $path]]
            if {[get_property CLASS $startPoint] != "pin" ||
                [get_property CLASS $endPoint] != "pin"} {
                # if this path starts at anything other than a pin (eg a port) then
                # this is not a synchronizer, report a warning and return
                puts "WARNING:  You have a non-synchronized inter-clock path!"
                puts "WARNING:  This path does not start and end at a cell pin $path"
                return 0
            }
            set endPointCell [get_cells -of $endPoint]
            set startPointCell [get_cells -of [get_pins $startPoint]]
            if {[get_property PRIMITIVE_SUBGROUP $startPointCell] != "flop" ||
                [get_property PRIMITIVE_SUBGROUP $endPointCell] != "flop"} {
                puts "WARNING:  You have a non-synchronized inter-clock path!"
                puts "WARNING:  This path does not start and end at synchronous flip flops $path"
                return 0
            }
            puts "DEBUG:  Looks like this might be a synchronizer chain! $path"
            set net [get_nets -of $endPoint]
            if {[get_property ASYNC_REG $net] != "TRUE"} {
                puts "WARNING:  You have a inter-clock path that is not properly synchronized!"
                puts "WARNING:  You have a path that might be a synchronizer chain but it does not have ASYNC_REG attribute on the net $net"
                return 0
            }
            # TODO - A sync chain can be N levels - this will go down 1 level.
            # TODO - this could be recursive
            # TODO - we could pass number of levels to trace in as a param
            set downPath [get_timing_paths -from $endPointCell]
            puts "DEBUG:  Found downstream path:  $downPath"
            if {[get_property LOGIC_LEVELS $downPath] > 1} {
                puts "DEBUG:  Downstream path has > 1 logic level: $downPath"
                puts "This is not properly synchronized:  $path"
                return 0
            }
            puts "INFO:  Suggested set_max_delay -datapath_only command that is equivalent to DATAPATHONLY in ISE TRCE:"
            puts "set_max_delay -datapath_only -from $startPoint -to $endpoint 0.5"
        }
        # there are no non-synchronized paths found - exit with true return code
        return 1
    }
}

proc ::tclapp::xilinx::designutils::lcm {p q} {
    # Summary: compute the least common multiple; currently only works on integers

    # Argument Usage:
    # p : first integer
    # q : second integer

    # Return Value:   the least common multiple of the input integers
    
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

proc ::tclapp::xilinx::designutils::checkRelated {clk1 clk2} {
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


proc ::tclapp::xilinx::designutils::checkAllRelated {} {
    # Summary: checks to see if all clocks are related
    
    # Argument Usage:
    # none
    
    # Return Value:
    # none
    
    set clkList [get_clocks]
    foreach clk1 $clkList {
        foreach clk2 [filter $clkList "NAME != $clk1"] {
            if {[checkRelated $clk1 $clk2]} {
                # if the clocks are obviously related - don't check for synchronizer chain
                #	 puts "INFO:  Skipping because clocks appear to be related - $clk1 - $clk2"
                continue
            }
            # -quiet suppresses warnings when no paths are found
            if {![checkSync [get_timing_paths -max_paths 1 -nworst 1 -quiet -from $clk1 -to $clk2]]} {
                puts "ERROR:  There are paths from $clk1 to $clk2 that do not appear to be synchronized."
            }
            if {![checkSync [get_timing_paths -max_paths 1 -nworst 1 -quiet -from $clk2 -to $clk1]]} {
                puts "ERROR:  There are paths from $clk2 to $clk1 that do not appear to be synchronized."
            }
        }
    }
}
####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
