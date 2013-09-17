####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export insert_buffer insert_buffer_chain
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils::insert_buffer {
} ]


proc ::tclapp::xilinx::designutils::insert_buffer {net {bufferType BUFH}} {
  # Summary : insert a buffer or any 2-pins cell on a net

  # Argument Usage:
  # net : net to insert buffer on
  # bufferType : type of 2-pins cell to insert

  # Return Value:
  # none

  if {$net == {}} {
    error " error - no net specified"
  }
  
  set bufferType [string toupper $bufferType]
  set bufCellRef [get_lib_cells -quiet [get_libs]/$bufferType]
  if {$bufCellRef == {}} {
    error " error - cannot find cell type $bufferType"
  }
  if {[get_property -quiet NUM_PINS $bufCellRef] != 2} {
    error " error - only 2-pins cells can be inserted"
  }

  set bufOutNet [get_nets -quiet $net]
  switch [llength $bufOutNet] {
    0 {
      error " error - cannot find net $net"
    }
    1 {
      # Ok
    }
    default {
      # More than 1 net
      error " error - more than 1 net match $net"
    }
  }

  # Is the driver leaf pin connected to this net segment?
  if {[get_pins -quiet -of $bufOutNet -filter {IS_LEAF && DIRECTION==OUT}] == {}} {
    # No, then search for the driver pin connected to any of the net segments
    set driverPin [get_pins -quiet -leaf -of $bufOutNet -filter {IS_LEAF && DIRECTION==OUT}]
    # Found one?
    if {$driverPin == {}} {
      # No
      error " error - no driver pin is connected to the net ($net)"
    } else {
      # Yes
      # Since there is one driver leaf pin connected somewhere on the net, we need to find which
      # of the hierarchical pin connects directly or indirectly to the driver leaf pin
      set bufSrcPin [all_fanin -quiet -to $bufOutNet -level 1 -pin_level 1 -trace_arcs all ]
    }
  } else {
    # Since the driver leaf pin is connected on this net segment, it is easy to get it
    set bufSrcPin [get_pins -quiet -of $bufOutNet -leaf -filter {DIRECTION == OUT}]
  }

  # Only support nets with a single driver
  if {[llength $bufSrcPin] > 1} {
    error " error - net ($net) has [llength $bufSrcPin] drivers ($bufSrcPin). Nets with multiple driver pins are not supported"
  }

  # Get all leaf cells connected to this segment of the net
  set allConnectedLeafCells [get_cells -quiet -of [get_pins -quiet -leaf -of $bufOutNet] -filter {IS_PRIMITIVE && PRIMITIVE_LEVEL!="INTERNAL"}]

  # Force unplacing all the leaf cells
  unplace_cell [get_cells -quiet $allConnectedLeafCells -filter {((IS_PRIMITIVE==true && PRIMITIVE_LEVEL!="INTERNAL")  && (LOC!=""))}]

  set props [lsort -unique [get_property -quiet LOC $allConnectedLeafCells ]]
  if { ($props != [list {}]) && ($props != {})} {
    error " error - some cells connected to net $net are placed. All cells must be unplaced prior inserting a buffer"
  }

  # Create the buffer
  set bufCellName [insert_buffer::genUniqueCellName ${bufOutNet}_${bufferType}]
  create_cell -reference $bufCellRef $bufCellName
  set bufCell [get_cells -quiet $bufCellName]
  set bufInPin [get_pins -quiet -of $bufCell -filter {DIRECTION == IN}]
  set bufOutPin [get_pins -quiet -of $bufCell -filter {DIRECTION == OUT}]

  # Create the new net
  set bufInNetName [insert_buffer::genUniqueNetName ${bufCellName}_net]
  create_net $bufInNetName
  set bufInNet [get_nets -quiet $bufInNetName]

  # Disconnect the driver pin
  disconnect_net -net $bufOutNet -obj $bufSrcPin

  # Reconnect the driver pin to the new net
  connect_net -hier -net $bufInNet -obj [list $bufSrcPin $bufInPin]

  # Connect buffer output pin
  connect_net -hier -net $bufOutNet -obj $bufOutPin

  # Is a LUT being inserted?
  if {[get_property -quiet PRIMITIVE_GROUP $bufCellRef] == {LUT}} {
    set_property INIT "10" $bufCell
#     set_property BEL "A6LUT" $bufCell
#     set_property MARK_DEBUG TRUE $bufInNet
  }

  puts " Inserted $bufferType to drive net $net"
  return 0
}

proc ::tclapp::xilinx::designutils::insert_buffer_chain {net args} {
  # Summary : insert a list of buffers or any 2-pins cells on a net

  # Argument Usage:
  # net : net to insert buffer on
  # args : list of 2-pins cells to insert

  # Return Value:
  # none

  set buffers [list]
  # Check that all the buffers are correct
  foreach bufferType $args {
    set bufferType [string toupper $bufferType]
    set bufCellRef [get_lib_cells -quiet [get_libs]/$bufferType]
    if {$bufCellRef == {}} {
      error " error - cannot find cell type $bufferType"
    }
    set numPins [get_property -quiet NUM_PINS $bufCellRef]
    if {$numPins != 2} {
      error " error - only 2-pins cells can be inserted. Cell type $bufferType has $numPins pins"
    }
    lappend buffers $bufferType
  }
  # Insert the chain for buffers
  foreach buffer $buffers {
    insert_buffer $net $buffer
  }
  return 0
}

proc ::tclapp::xilinx::designutils::insert_buffer::genUniqueCellName {name} {
  # Summary : return an unique and non-existing cell name

  # Argument Usage:
  # name : base name for the cell

  # Return Value:
  # cell name

  if {[get_cells -quiet $name] == {}} { return $name }
  set index 0
  while {[get_cells -quiet ${name}_${index}] != {}} { incr index }
  return ${name}_${index}
}

proc ::tclapp::xilinx::designutils::insert_buffer::genUniqueNetName {name} {
  # Summary : return an unique and non-existing net name

  # Argument Usage:
  # name : base name for the net

  # Return Value:
  # net name

  if {[get_nets -quiet $name] == {}} { return $name }
  set index 0
  while {[get_nets -quiet ${name}_${index}] != {}} { incr index }
  return ${name}_${index}
}
