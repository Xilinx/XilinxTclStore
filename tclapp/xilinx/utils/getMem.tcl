package require Vivado 2012.2
package require ::tclapp::xilinx::utils 1.0

namespace eval ::tclapp::xilinx::utils {
    namespace export getMem
}

proc ::tclapp::xilinx::utils::getMem {pid} {
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
