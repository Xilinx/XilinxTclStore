package require Vivado 2013.1

namespace eval ::tclapp::xilinx::utils {
    namespace export isFileGood
}

proc ::tclapp::xilinx::utils::isFileGood {fileIn {extension}} {
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
