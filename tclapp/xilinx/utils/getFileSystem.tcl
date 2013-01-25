package require Vivado 2013.1

namespace eval ::tclapp::xilinx::utils {
    namespace export getFileSystem
}
    
proc ::tclapp::xilinx::utils::getFileSystem {} {
    # Summary : tries to determine what the host platform is
    
    # Argument Usage:
    # none
    
    # Return Value:
    # either "windows" or "linux" depending on which platform we're on
    
    if {[info exists tcl_platform(host_platform)]} {
        # this is a jacl (planAhead-only) tcl var
        return $tcl_platform(host_platform)
    } elseif {[info exists tcl_platform(platform)]} {
        # this is a general tcl platform variable
        return $tcl_platform(platform)
    } else {
        # else try to determine from the PATH environment varaible
        set path $::env(PATH)
        if {[regexp {^[A-Za-z]:} $path]} {
            return windows
        } else {
            return unix
        }
    }
}
