package require Vivado 2012.2

namespace eval ::tclapp::xilinx::utils {
    namespace export isLineWellFormedCSV
}

proc ::tclapp::xilinx::utils::isLineWellFormedCSV {headerList expectedNumberOfHeaders} {
    # Summary : Test whether line is CSV or not
    
    # Argument Usage:
    # headerList :
    # expectedNumberOfHeaders :
    
    # Return Value:
    # returns 1 if a line is a well-formed CSV line, 0 otherwise...
    
    if {[llength $headerList]i != $expectedNumberOfHeaders} {
        return 1
    } else return 0
}
