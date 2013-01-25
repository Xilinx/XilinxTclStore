package require Vivado 2013.1

namespace eval ::tclapp::xilinx::utils {
    namespace export insertLUT insertLUTs
}

proc ::tclapp::xilinx::utils::insertLUT {net lutInNet} {
    # Summary : insert single lut
    
    # Argument Usage:
    # net : net to insert lut on
    # lutInNet : name of created net

    # Return Value:
    # none
    
    set lutOutNet [get_nets $net]
    set lutSrcPin [get_pins -of $lutOutNet -filter {direction == out && is_leaf == 1}]
    set lutCellName ${lutOutNet}_LUT1
    set lutCellRef [get_lib_cells [get_libs]/LUT1]
    debug::create_cell -reference $lutCellRef $lutCellName
    set lutCellName [get_cells $lutCellName]
    set lutInPin [get_pins -of $lutCellName -filter {direction == in}]
    set lutOutPin [get_pins -of $lutCellName -filter {direction == out}]

    # connect buffer input
    debug::create_net $lutInNet
    debug::disconnect_net -net $lutOutNet -obj $lutSrcPin
    debug::connect_net -net $lutInNet -obj [list $lutSrcPin $lutInPin]

    # connect buffer output
    debug::connect_net -net $lutOutNet -obj $lutOutPin

    set_property INIT "10" [get_cells $lutCellName]
    set_property BEL "A6LUT" [get_cells $lutCellName]
    set_property MARK_DEBUG TRUE [get_nets $lutOutNet]

    puts "Inserted delay LUT between nets $lutInNet -> $lutOutNet"
}


proc ::tclapp::xilinx::utils::insertLUTs {net numLUTs} {
    # Summary : insert chain of LUTs
    
    # Argument Usage:
    # net : net to insert on
    # numLUTS : number of luts to insert

    # Return Value:
    # none
    
    set netName $net
    set counter 0
    while {$counter < $numLUTs} {
        set newNetName ${net}_$counter
        insertLUT $netName $newNetName
        set netName $newNetName
        incr counter
    }
}
