namespace eval ::tclapp::xilinx::designutils {
    namespace export parseCoreGenBOM
}

proc ::tclapp::xilinx::designutils::parseCoreGenBOM {fileName} {
    # Summary : parses a core generator bom and returns a list of expected files

    # Argument Usage:
    # fileName : file to process

    # Return Value:
    # list of expected files
    
    if {[catch "set BOMFILEIN [open $fileName r]"]} {
        puts "ERROR:  Error opening $fileName"
    }
    set fileList [list]
    while {[gets $BOMFILEIN line] >= 0} {
        if {[regexp {<File\s+name="(.+?)"\s+type} $line matchVar file]} {

            #         puts "DEBUG:  Found a file - $file"
            lappend fileList $file
        }
    }
    close $BOMFILEIN
    return $fileList
}
