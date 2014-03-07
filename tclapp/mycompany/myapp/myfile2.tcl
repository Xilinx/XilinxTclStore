package require Vivado 1.2014.1

namespace eval ::tclapp::mycompany::myapp {
    # Export procs that should be allowed to import into other namespaces
    namespace export myproc2
}
    
proc ::tclapp::mycompany::myapp::myproc2 {arg1 {optional1 ,}} {

    # Summary : A one line summary of what this proc does
    
    # Argument Usage:
    # arg1 : A one line summary of this argument
    # [optional1=,] : A one line summary of this argument

    # Return Value: 
    # TCL_ERROR is returned with result set to a string

    puts "Calling ::tclapp::mycompany::myapp::myproc2 '$arg1' '$optional1'"
    
    return -code error "myproc2 result"
}

