package require Vivado 2013.1

namespace eval ::tclapp::topic::dyplo {
    # Export procs that should be allowed to import into other namespaces
    namespace export dyplo_hello_world
}
    
proc ::tclapp::topic::dyplo::dyplo_hello_world {arg1 {optional1 ,}} {

    # Summary : A one line summary of what this proc does
    
    # Argument Usage:
    # arg1 : A one line summary of this argument
    # [optional1=,] : A one line summary of this argument

    # Return Value: 
    # TCL_OK is returned with result set to a string

    puts "Calling ::tclapp::topic::dyplo::dyplo_hello_world '$arg1' '$optional1'"
	puts "Hello Dyplo user!"
	puts "Exit ::tclapp::topic::dyplo::dyplo_hello_world '$arg1' '$optional1'"
    
    return -code ok "dyplo_hello_world result"
}

