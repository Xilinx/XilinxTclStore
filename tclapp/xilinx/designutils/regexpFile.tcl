####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
namespace eval ::tclapp::xilinx::designutils {
    namespace export regexpFile
}

proc ::tclapp::xilinx::designutils::regexpFile {expression fileIn} {
    # Summary : returns all lines that match occurrence of regular expression matched in the file

    # Argument Usage:
    # expression : regular expresion
    # fileIn : file to process

    # Return Value:
    # file matches
    
    set lineMatches [list]
    set FILEIN ""
    puts "INFO: Opening $fileIn for read operation"
    if {[catch "set FILEIN [open $fileIn r]"]} {
        puts "ERROR:  error opening $fileIn"
    }
    while {[gets $FILEIN line] >= 0} {
        if {[regexp $expression $line]} {
            lappend lineMatches $line
        }
    }
    close $FILEIN
    return $lineMatches
}

