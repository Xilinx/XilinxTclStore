####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
namespace eval ::tclapp::xilinx::designutils {
    namespace export quoteToCurly
}

proc ::tclapp::xilinx::designutils::quoteToCurly {str} {
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
####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
