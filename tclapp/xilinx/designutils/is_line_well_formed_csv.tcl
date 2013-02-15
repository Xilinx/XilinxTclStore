####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export isLineWellFormedCSV
}

proc ::tclapp::xilinx::designutils::isLineWellFormedCSV {headerList expectedNumberOfHeaders} {
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

