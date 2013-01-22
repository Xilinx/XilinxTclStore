namespace eval ::tclapp::xilinx::utils {
    namespace export quoteToCurly
}

proc ::tclapp::xilinx::utils::quoteToCurly {str} {
    # Summary : convert comment formats

    # Argument Usage:
    # str : string

    # Return Value:
    # converted string
    
    # delete leading quote char if exists
    regsub {^\s*"} $str {} str
      # delete closing quote char if exists
      regsub {"\s*$} $str {} str
    if {[regexp {\[|\]} $str]} {
        # if string contains Tcl special chars square brackets
        # wrap in curly braces
        set str "\{$str\}"
    }
    return $str
}
