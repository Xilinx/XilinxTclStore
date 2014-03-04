package require Vivado 1.2013.1

namespace eval ::tclapp::mycompany::myapp {
    # Export procs that should be allowed to import into other namespaces
    namespace export myproc1
}
    
proc ::tclapp::mycompany::myapp::myproc1 {arg1 {optional1 ,}} {

    # Summary : A one line summary of what this proc does
    
    # Argument Usage:
    # arg1 : A one line summary of this argument
    # [optional1=,] : A one line summary of this argument

    # Return Value: 
    # TCL_OK is returned with result set to a string

    puts "Calling ::tclapp::mycompany::myapp::myproc1 '$arg1' '$optional1'"
    
    return -code ok "myproc1 result"
}

