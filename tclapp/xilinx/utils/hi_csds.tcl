package require Vivado 2012.2

namespace eval ::tclapp::xilinx::utils {
    namespace export HighlightControlSetDestinationSlice
}

proc ::tclapp::xilinx::utils::HighlightControlSetDestinationSlice {} {
    # Summary : HighlightControlSetDestinationSlice for PA 13.2
    
    # Argument Usage:
    # none

    # Return Value:
    # none
    
    set controlSetReport "control_set_sdc_tut.txt"
    
    report_control_set -verbose -file $controlSetReport
    
    set inputFile [open $controlSetReport "r"]
    set lineNumber 0
    while { [gets $inputFile line] >=0 } {
        puts "[incr lineNumber]: $line"
        if {![regexp "^|" $line] } {
            # skip the header info
            puts "DEBUG - Skipping header line"
            continue
        }
        
        set enableSignalNet [lindex [split $line {|}] 2]
        
        if {[regexp {^\s*$} $enableSignalNet] || [regexp {Clock Signal} $enableSignalNet] } {
            continue
        }
        puts "DEBUG: $enableSignalNet"
        set netList [get_nets $enableSignalNet]
        
        if {[llength $netList] == 0} {
            puts "No such net found in design : $enableSignalNet"
            continue
        }
        set cellList [get_cells -of [get_pins -leaf -of [lindex $netList 0] -filter {direction == IN}]]
        if {[llength $cellList] == 0} {
            puts "Empty list of cells - net: $netList"
            continue
        }
        
        foreach site [get_sites] {set usedSites($site) 0}
        foreach c $cellList {
            set site [get_property SITE $c]
            if {$site == ""} {
                puts "Warning - unplaced cell - $c"
                continue
            }
            set usedSites($site) 1
        }
        foreach site [array names usedSites] {
            if {$usedSites($site) == 1} {
                puts $site
                highlight_objects -color yellow [get_sites $site]
            }
        }
    }
    close $inputFile
    
}
