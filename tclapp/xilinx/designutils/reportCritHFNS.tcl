package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export reportCritHFNS lsortSlack lsortFanout
}

proc ::tclapp::xilinx::designutils::reportCritHFNS {{sortBy slack} {limitFO 256}  {limitSlack 0}} {
    # Summary : report Critical high fanout nets
    
    # Argument Usage:
    # [sortBy=slack] : sorting critierion
    # [limitFO=256] : fanout limit
    # [limitSlack=0] :

    # Return Value:
    # none
    
    set count 0
    global slackList
    global fanoutList
    if {$sortBy != "slack" && $sortBy != "fanout"} {
        return "ERROR:  Unknown sortBy value"
    }
    foreach net [get_nets * -hierarchical -filter "FLAT_PIN_COUNT >= $limitFO && TYPE != \"Global Clock\""] {
        set driver [get_pins -leaf -of $net -filter "DIRECTION == OUT"]
        set slack [get_property SETUP_SLACK $driver]
        set fanout [get_property FLAT_PIN_COUNT $net]
        if {$slack > $limitSlack} {
            continue
        }
        set slackList($net) $slack
        set fanoutList($net) $fanout
        #      puts "$net $slack $fanout"
        incr count
    }
    puts "NET FANOUT SLACK"
    # TODO - debug why sort by slack and fanout is not working...
    if {$sortBy == "slack"} {
        foreach net [lsort -command lsortSlack [array names slackList]] {
            puts "$net $fanoutList($net) $slackList($net)"
        }
    } else {
        foreach net [lsort -command lsortFanout [array names slackList]] {
            puts "$net $fanoutList($net) $slackList($net)"
        }
    }
    puts "INFO:  Found $count critical high fanout nets"
}

proc ::tclapp::xilinx::designutils::lsortSlack {left right} {
    # Summary : sorting appity proc

    # Argument Usage:
    # left : left value to be compared
    # right : right value to be compares
    
    # Return Value:
    # -1 if left slack < right slack
    #  1 if left slack > right slack
    #  0 otherwise
    
    set leftSlack slackList($left)
    set rightSlack slackList($right)
    if { $leftSlack < $rightSlack } {
        return -1
    } elseif { $leftSlack > $rightSlack} {
        return 1
    } else {
        return 0
    }
}

proc ::tclapp::xilinx::designutils::lsortFanout {left right} {
    # Summary : sorting appity proc

    # Argument Usage:
    # left : left value to be compared
    # right : right value to be compares
    
    # Return Value:
    # -1 if left fo < right fo
    #  1 if left fo > right fo
    #  0 otherwise
    
    set leftFO fanoutList($left)
    set rightFO fanoutList($right)
    if { $leftFO < $rightFO } {
        return -1
    } elseif { $leftFO > $rightFO} {
        return 1
    } else {
        return 0
    }
}
