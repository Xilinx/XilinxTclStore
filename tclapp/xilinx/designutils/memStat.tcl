package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export memStat
}

proc ::tclapp::xilinx::designutils::memStat {} {
    # Summary : queries the kernel for current heap memory and cpu usage stats
    
    # Argument Usage:
    
    # Return Value:
    # amount of memory
    
    set pid ""
    if {[catch "set pid [pid]"]} {
        # jacl has not implemented the pid tcl pid command (jacl is currenlty only Tcl 8.0 compliant
        if {[file exists planAhead.log]} {
            # attempt to get the pid from the planAhead log file - last "#Process ID:" string in log
            set pid [lindex [split [lindex [regexpFile {^# Process ID: \d+$} planAhead.log] end]] end]
        }
    }
    if {$pid != ""} {
        return [getMem $pid]
    } else {
         puts "ERROR:  Unable to determine process id"
         return ""
    }
}
