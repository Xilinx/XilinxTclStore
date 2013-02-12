####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

package require ::tclapp::xilinx::designutils 1.0

namespace eval ::tclapp::xilinx::designutils {
    namespace export getMem
}

proc ::tclapp::xilinx::designutils::getMem {pid} {
    # Summary : queries the kernel for current heap memory

    # Argument Usage:
    # pid : process id

    # Return Value:
    # the amount of heap memory
    
    set mem ""
    if {$pid != ""} {
        if {[getFileSystem] == "windows"} {
            # handle windows kernel call
            # TODO - implement the windows tasklist command call...
            # TODO - review to make sure mem is 16th token, and is always in Kbytes???
            # TODO - exec is currently broken on windows in jacl - 3910
            set mem [lindex [exec tasklist /FI "PID eq $pid"] 16]
        } else {
            # handle linux/unix kernel call through the ps command
            # RSS - Resident Set Size - is the best memory metric we have, it's the 18th field returned from ps
            set mem [lindex [exec ps v -p $pid] 17]
        }
    }
    return $mem
}
####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
