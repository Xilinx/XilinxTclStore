package require Vivado 1.2014.1

namespace eval ::tclapp::mycompany::myapp6 {
    # Export procs that should be allowed to import into other namespaces
    namespace export myproc1
}
    
proc ::tclapp::mycompany::myapp6::myproc1 {arg1 {optional1 ,}} {

    # Summary : 
    # A one line summary of what this proc does
    # In branch 8_19_2014, modifying the same line on 2_26_2015 branch
    # decided to keep above line and add comments
    # This line is at 8_19_2014.3 branch
    # Merged back to 8_19_2014
    # Now branch to 2_26_2015
    # new feature on develop (2_26_2015)
    
    # Argument Usage:
    # arg1 : A one line summary of this argument
    # [optional1=,] : A one line summary of this argument

    # Return Value: 
    # TCL_OK is returned with result set to a string

    puts "Calling ::tclapp::mycompany::myapp6::myproc1 '$arg1' '$optional1'"
    
    return -code ok "myproc1 result"
}

