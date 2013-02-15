####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export getHighFanoutRegs copyReg replicateRegs limitRegFanout
}

proc ::tclapp::xilinx::designutils::getHighFanoutRegs {maxFan inst hiFanRegs hiFanNets hiFanLoads} {
    # Summary : get high fanout registers
    
    # Argument Usage:
    # maxFan : the desired fanout limi
    #  hiFanRegs: a list of reg insts that have fanout above maxFan
    #  hiFanNets: a dictionary of nets driven by each high-fanout reg
    #  hiFanLoads: a dictionary of load pins driven by each high-fanout reg
    
    # Return Value:
    # none, results returned in the input variables
    
    upvar $hiFanRegs regs
    upvar $hiFanNets nets
    upvar $hiFanLoads loads
    set regs {}
    set maxMaxFan 0
    set regMaxFan {}
    puts "Searching for high-fanout registers in $inst..."
    set filterPattern "lib_cell =~ FD* && name =~ $inst"
    foreach reg [get_cells -hier * -filter $filterPattern] {
        # get the network driven by the reg
        set output [get_pins -leaf -of_objects $reg -filter {direction == OUT}]
        set net [get_nets -of_objects $output]
        set cond {direction != "OUT"}      ; # exclude the high-fanout driver
        set cond "$cond && is_clock == 0"  ; # add clock pins to exclusion
        set cond "$cond && is_clear == 0"  ; # add async clear pins to exclusion
        set cond "$cond && is_preset == 0" ; # add async set pins to exclusion
        set cond "$cond && name !~ */R"    ; # add sync clear pins to exclusion
        set cond "$cond && name !~ */S"    ; # add sync set pins to exclusion
        set cond "$cond && name !~ */CE"  ; # add clock enable pins to exclusion
        set loadPins [get_pins -of_objects $net -filter $cond]
        # if high-fanout, add the Reg to the list of high-fanout Regs
        set fanout [llength $loadPins]
        if {$fanout > $maxFan} {
            lappend regs $reg
            dict set nets $reg $net
            dict append loads $reg $loadPins
            puts -nonewline "  High-fanout reg: $reg, Fanout: [llength $loadPins],"
            puts " drives net: $net"
        }
        # keep track of the reg with highest fanout
        if {$fanout > $maxMaxFan} {
            set maxMaxFan $fanout
            set regMaxFan $reg
        }
    }
    set regCount [llength $regs]
    if {$regCount > 0} {
        puts "Found $regCount high-fanout regs:"
        puts "Highest fanout reg is $regMaxFan, fanout $maxMaxFan"
    } else {
        puts "No high-fanout regs found."
        puts "Highest fanout reg is $regMaxFan, fanout $maxMaxFan"
    }
}

proc ::tclapp::xilinx::designutils::copyReg {regOrig netOrig copyIndex} {
    # Summary : creates a copy of the reg and connects the input pins
    
    # Argument Usage:
    # regOrig : reg to copy
    # netOrig : net driven by register
    # copyIndex : an ID
    
    # Return Value:
    # creates and returns a new net driven by the copy reg output
    
    # change the hierarchy separator here, if not a '/'
    set hierSep /
    set libcell [get_property LIB_CELL $regOrig]
    set inst "${regOrig}_cpy$copyIndex"
    while {[llength [get_cells -quiet $inst]] > 0} {
        set inst "${inst}_$copyIndex" ; # rename to prevent clash
    }
    ::debug::create_cell -reference $libcell $inst
    # get the list of input pins to connect
    set inputPins [get_pins -of_objects $regOrig -filter \
                       {direction != "OUT"}]
    foreach input $inputPins {
        set pinName [lindex [split $input $hierSep] end]
        set pinCopy $inst$hierSep$pinName
        ::debug::connect_net -net [get_nets -of_objects $input] \
            -objects $pinCopy
    }
    set netCopy "${netOrig}_cpy$copyIndex"
    while {[llength [get_nets -quiet $netCopy]] > 0} {
        set netCopy "${netCopy}_$copyIndex" ; # rename to prevent clash
    }
    ::debug::create_net $netCopy
    # assume Reg output pin is always called 'Q'
    ::debug::connect_net -net $netCopy -objects "$inst/Q"
    return [get_net $netCopy]
}

proc ::tclapp::xilinx::designutils::replicateRegs {maxFan hiFanNets hiFanLoads} {
    # Summary : 
    # takes the max fanout limit and the nets and load pins of all
    # high-fanout regs
    # divides the loads into different groups according to max fanout
    # disconnects loads from orig reg and connects to new reg copy

    # Argument Usage:
    # maxFan : max fanout limit
    # hiFanNets : the high fanout nets
    # hiFanLoads : hi fanout loads

    # Return Value:
    # none
    
    foreach net [dict values $hiFanNets] reg [dict keys $hiFanNets] {
        set regOrig [get_cells $reg]
        # figure out how many groups of load pins
        set loads [dict get $hiFanLoads $reg]
        set fanout [llength $loads]
        set groups [expr $fanout / $maxFan]
        set rem [expr $fanout % $maxFan]
        if {$rem > 0} {
            incr groups
        }
        puts "\nDEBUG: Replicating reg $regOrig"
        puts "DEBUG: Original net: $net will be split into $groups groups"
        # divide each group according to number of loads divided by max fanout
        # create a new reg copy to drive each subset of loads
        for {set idxGrp 1} {$idxGrp < $groups} {incr idxGrp} {
            # call proc copyReg to replicate reg and return the copy's net
            set netCopy [copyReg $regOrig $net [expr $idxGrp - 1]]
            set idxStart [expr $idxGrp * $maxFan]
            set idxEnd [expr $idxStart + $maxFan - 1]
            if {$idxEnd > $fanout} {
                set idxEnd [expr $idxStart + $rem - 1]
            }
            set loadGroup [lrange $loads $idxStart $idxEnd]
            ::debug::disconnect_net -net $net -objects $loadGroup
            ::debug::connect_net -net $netCopy -objects $loadGroup
            puts "DEBUG: Group [expr $idxGrp + 1]: driven by new net: $netCopy"
            puts -nonewline "DEBUG: Connecting loads [expr $idxStart + 1] to "
            puts "[expr $idxEnd + 1] of $fanout total loads to net: $netCopy\n"
        }
    }
}


proc ::tclapp::xilinx::designutils::limitRegFanout { {maxFan 100} {inst *} {reportOnly 0} } {
    # Summary :     # Replicate logic to limit register fanout to maxFan.  Run after synthesis
    
    # Argument Usage:
    # [maxFan=100] : the fanout limit
    # [inst=*] : the hierarchical scope
    # [reportOnly=0] : if non-zero will only report, not replicate

    # Return Value:
    # none
    
    set hiFanRegs {} ; # list of reg insts that have fanout above maxFan
    set hiFanNets [dict create]  ; # nets driven by each high-fanout reg
    set hiFanLoads [dict create] ; # load pins driven by each high-fanout reg
    set pass 1
    
    getHighFanoutRegs $maxFan $inst hiFanRegs hiFanNets hiFanLoads
    
    # As each pass is run, replication may increase fanouts above maxFan
    # Keep iterating while there are high-fanout regs
    while {[llength $hiFanRegs] > 0 && $reportOnly == 0} {
        replicateRegs $maxFan $hiFanNets $hiFanLoads
        set hiFanRegs {}
        set hiFanNets [dict create]
        set hiFanLoads [dict create]
        puts "Finished pass $pass\n"
        incr pass
        getHighFanoutRegs $maxFan $inst hiFanRegs hiFanNets hiFanLoads
    }
}
