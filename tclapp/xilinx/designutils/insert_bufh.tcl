####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export insertBUFH
}
    
proc ::tclapp::xilinx::designutils::insertBUFH {net} {
    # Summary : quick/dirty proc to insert a BUFH on a net

    # Argument Usage:
    # net : net to insert buf on

    # Return Value:
    # none
    
    set bufOutNet [get_nets $net]
    set bufSrcPin [get_pins -of $bufOutNet -filter {direction == out && is_leaf == 1}]
    set bufCellName ${bufOutNet}_BUFH
    # note: there is a bug in debug::create_cells
    # it should take a lib_cell object, but only works with a string
    # uncomment below when this gets fixed
    set bufCellRef "BUFH"
    #set bufCellRef [get_lib_cells [get_libs]/BUFH]
    debug::create_cell -reference $bufCellRef $bufCellName
    set bufCellName [get_cells $bufCellName]
    set bufInPin [get_pins -of $bufCellName -filter {direction == in}]
    set bufOutPin [get_pins -of $bufCellName -filter {direction == out}]
    
    # connect buffer input
    set bufInNet ${bufCellName}_net
    debug::create_net $bufInNet
    debug::disconnect_net -net $bufOutNet -obj $bufSrcPin
    debug::connect_net -net $bufInNet -obj [list $bufSrcPin $bufInPin]
    
    # connect buffer output
    debug::connect_net -net $bufOutNet -obj $bufOutPin
    
    puts "Inserted BUFH to drive net $net"
}

