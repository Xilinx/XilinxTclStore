####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export isFileGood
}

proc ::tclapp::xilinx::designutils::isFileGood {fileIn {extension}} {
    # Summary : isfileGood
    
    # Argument Usage:
    # fileIn : file
    # [extension] : extention
    
    # Return Value:
    # none
    
    if {![file exists $file]} {
        puts "ERROR: File $file not found!"
    } elseif {[info exists extension]} {
        if {[file extension $fileIn] != $extension} {
            puts "ERROR: File $fileIn type is not the expected type"
            # TODO - do we want to fail if the extension doesn't match?
            return 0
        }
    }
    return [file readable $fileIn]
}

