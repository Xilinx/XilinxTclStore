package require Vivado 1.2014.1

namespace eval ::tclapp::mycompany::template {
    # Export procs that should be allowed to import into other namespaces
    namespace export my_command2 my_command3
}
    
proc ::tclapp::mycompany::template::my_command2 {arg1 {optional1 ,}} {

    # Summary : A one line summary of what this proc does
    
    # Argument Usage:
    # arg1 : A one line summary of this argument
    # [optional1=,] : A one line summary of this argument

    # Return Value: 
    # TCL_OK is returned with result set to a string

    # Categories: xilinxtclstore, template

    puts "Calling ::tclapp::mycompany::template::my_command2 '$arg1' '$optional1'"
    ::tclapp::mycompany::template::helper1
    helper2
    
    return -code ok "my_command2 result"
}

proc ::tclapp::mycompany::template::my_command3 {arg2 {optional2 ,}} {

    # Summary : A one line summary of what this proc does
    
    # Argument Usage:
    # arg2 : A one line summary of this argument
    # [optional2=,] : A one line summary of this argument

    # Return Value: 
    # TCL_ERROR is returned with result set to a string

    # Categories: xilinxtclstore, template

    puts "Calling ::tclapp::mycompany::template::my_command3 '$arg2' '$optional2'"
    
#     return -code error "my_command3 result"
    return -code ok "my_command3 result"
}

proc ::tclapp::mycompany::template::helper1 {args} {
   # Summary :
   # Argument Usage:
   # Return Value:
   # Categories:

    puts "Calling ::tclapp::mycompany::template::helper1"
    
    return -code ok "helper1 result"
}

proc ::tclapp::mycompany::template::helper2 {args} {
   # Summary :
   # Argument Usage:
   # Return Value:
   # Categories:

    puts "Calling ::tclapp::mycompany::template::helper2"
    
    return -code ok "helper2 result"
}

