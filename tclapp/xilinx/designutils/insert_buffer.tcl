####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export insert_buffer insert_buffer_chain remove_buffer
}

proc ::tclapp::xilinx::designutils::insert_buffer_chain {net args} {
  # Summary : insert a list of buffers or any 2-pins cells on a net

  # Argument Usage:
  # net : Net to insert buffer on. After insertion, the driver of the net is connected to the input of the inserted cell
  # args : List of 2-pins cell types to insert

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  uplevel ::tclapp::xilinx::designutils::insert_buffer::insert_buffer_chain $net $args
  return 0
}

proc ::tclapp::xilinx::designutils::insert_buffer {net {bufferType BUFH}} {
  # Summary : insert a buffer or any 2-pins cell on a net

  # Argument Usage:
  # net : Net to insert buffer on. After insertion, the driver of the net is connected to the input of the inserted cell
  # [bufferType = BUFH]: Type of 2-pins cell to insert

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  return [uplevel ::tclapp::xilinx::designutils::insert_buffer::insert_buffer $net $bufferType]
}

proc ::tclapp::xilinx::designutils::remove_buffer {cell} {
  # Summary : insert a buffer or any 2-pins cell on a net

  # Argument Usage:
  # cell : Cell to be removed

  # Return Value:
  # 0 if succeeded
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  return [uplevel ::tclapp::xilinx::designutils::insert_buffer::remove_buffer $cell]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils::insert_buffer {
  variable debug 0
  variable LOC
} ]

proc ::tclapp::xilinx::designutils::insert_buffer::insert_buffer_chain {net args} {
  # Summary : insert a list of buffers or any 2-pins cells on a net

  # Argument Usage:
  # net : Net to insert buffer on. After insertion, the driver of the net is connected to the input of the inserted cell
  # args : Ordered list of 2-pins cell types to be inserted

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

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

proc ::tclapp::xilinx::designutils::insert_buffer::insert_buffer {name {bufferType BUFH}} {
  # Summary : insert a buffer or any 2-pins cell on a net or a pin

  # Argument Usage:
  # name : Net or pin to insert buffer on
  # [bufferType = BUFH] : Type of 2-pins cell to insert

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug
  if {$name == {}} {
    error " error - no net or pin specified"
  }

  set hierSep [get_hierarchy_separator]
  set bufferType [string toupper $bufferType]
  set bufCellRef [get_lib_cells -quiet [get_libs]/$bufferType]
  if {$bufCellRef == {}} {
    error " error - cannot find cell type $bufferType"
  }
  if {[get_property -quiet NUM_PINS $bufCellRef] != 2} {
    error " error - only 2-pins cells can be inserted"
  }

  set nets [get_nets -quiet $name]
  if {$nets != {}} {
    if {[llength $nets]>1} {
      # More than 1 net
#       error " error - more than 1 ([llength $nets]) net match $name"
      puts " WARN - [llength $nets] nets matching $name"
    }
    foreach net $nets {
      insertBufferOnNet $net $bufferType
    }
    return 0
  }

  set pins [get_pins -quiet $name -filter {IS_LEAF}]
  if {$pins != {}} {
    if {[llength $pins]>1} {
      # More than 1 net
#       error " error - more than 1 ([llength $pins]) leaf pin match $name"
      puts " WARN - [llength $pins] pins matching $name"
    }
    foreach pin $pins {
      insertBufferOnPin $pin $bufferType
    }
    return 0
  }

  error " error - no net or leaf pin matches $name"
}

proc ::tclapp::xilinx::designutils::insert_buffer::remove_buffer {cell} {
  # Summary : remove a buffer or any 2-pins cell on a net

  # Argument Usage:
  # cell : Buffer to be removed

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug
  if {$cell == {}} {
    error " error - no cell specified"
  }

#   set hierSep [get_hierarchy_separator]
  set buffers [get_cells -quiet $cell]
  switch [llength $buffers] {
    0 {
      error " error - cannot find cell $cell"
    }
    1 {
      # Ok
    }
    default {
      # More than 1 net
#       error " error - more than 1 ([llength $buffers]) cell match $cell"
      puts " WARN - [llength $buffers] cells matching $cell"
    }
  }

  foreach buffer $buffers {
    set bufCellRef [get_lib_cells -quiet [get_libs]/[get_property -quiet REF_NAME $buffer]]
    if {[get_property -quiet NUM_PINS $bufCellRef] != 2} {
#       error " error - only 2-pins cells can be removed"
      puts " WARN - only 2-pins cells can be removed. Skipping cell $buffer"
      continue
    }
    set bufOutPin [get_pins -quiet -of $buffer -filter {DIRECTION == OUT}]
    set bufOutNet [get_nets -quiet -of $bufOutPin]
    set bufInPin [get_pins -quiet -of $buffer -filter {DIRECTION == IN}]
    set bufInNet [get_nets -quiet -of [get_pins -quiet -of $buffer -filter {DIRECTION == IN}]]
    set loadPins [get_pins -quiet -leaf -of $bufOutNet -filter {DIRECTION != OUT}]
    set loadPorts [get_ports -quiet -of $bufOutNet -filter {DIRECTION != IN}]
    set driverPin [get_pins -quiet -leaf -of $bufInNet -filter {DIRECTION == OUT}]
    if {$driverPin == {}} {
      # If no driver leaf pin was found, maybe a port?
      set driverPin [get_ports -quiet -of $bufInNet -filter {DIRECTION == IN}]
    }
#     set driverPinClass [string toupper [get_property -quiet CLASS $driverPin]]
#     set driverPinDir [string toupper [get_property -quiet DIRECTION $driverPin]]

    if {$debug>1} { puts " DEBUG: driverPin: $driverPin" }
    if {$debug} { puts " DEBUG: unplacing cell $buffer ([get_property -quiet REF_NAME $buffer])" }
    # Need to unplace the buffer that neds to be deleted first. That will prevent
    # the buffer location from being saved inside unplaceConnectedCells since it
    # is going to be deleted
    unplace_cell $buffer

    # We first need to check that all the cells connected to the buffer are NOT placed.
    # Otherwise the connect_net command cannot work
    unplaceConnectedCells $buffer

    if {$debug} { puts " DEBUG: disconnect_net -verbose -prune -net $bufInNet -obj $bufInPin" }
    # Disconnect the to-be-deleted buffer input pin
    disconnect_net -verbose -prune -net $bufInNet -obj $bufInPin

    if {$debug} { puts " DEBUG: disconnect_net -verbose -prune -net $bufOutNet -obj $bufOutPin" }
    # Disconnect the to-be-deleted buffer output pin
    disconnect_net -verbose -prune -net $bufOutNet -obj $bufOutPin

    # Reconnect all the loads of the to-be-deleted buffer to the driver pin
    if {$loadPins != {}} {
      if {$debug} { puts " DEBUG: connect_net -verbose -hier -net $bufInNet -obj $loadPins" }
      connect_net -verbose -hier -net $bufInNet -obj $loadPins
    }
    if {$loadPorts != {}} {
      if {$debug} { puts " DEBUG: connect_net -verbose -hier -net $bufInNet -obj $loadPorts" }
      connect_net -verbose -hier -net $bufInNet -obj $loadPorts
    }

    if {$debug} { puts " DEBUG: remove_cell $buffer" }
    # Remove buffer
    # The linter complains on the following line
#     remove_cell -verbose $buffer
    # The workaround is to replace previous command with the one below
    eval [list remove_cell -verbose $buffer]
#     # Remove net: ** problem with busses, so commenting out **
#     remove_net -verbose $bufOutNet
  }

  if {$debug} { puts " DEBUG: restoreCellLoc" }
  # Restore cells LOC
  restoreCellLoc

 return 0
}

proc ::tclapp::xilinx::designutils::insert_buffer::unplaceConnectedCells {name {save 1}} {
  # Summary : check that all attached cells are unplaced. All the connected cells
  # can be forced to be unplaced

  # Argument Usage:
  # name : cell name or net name
  # save : 

  # Return Value:
  # 0 if all the connected cells are unplaced. 1 otherwise
  # TCL_ERROR if failed

  # Categories: xilinxtclstore, designutils

  variable debug
  variable LOC
  set cell [get_cells -quiet $name]
  set net [get_nets -quiet $name]
  set pin [get_pins -quiet $name -filter {IS_LEAF}]
  if {($cell == {}) && ($net == {}) && ($pin == {})} {
    error " error - cannot find a cell, a net or a leaf pin matching $name"
  }
  if {$cell != {}} {
    # This is a cell
#     set placedLeafCells [get_cells -quiet -of \
#                                  [get_nets -of $cell] -filter {IS_PRIMITIVE && PRIMITIVE_LEVEL!="INTERNAL"} ]
    set placedLeafCells [get_cells -quiet -of \
                                 [get_pins -quiet -leaf -of [get_nets -quiet -of $cell]] -filter {IS_PRIMITIVE && (LOC!= "")} ]
  } elseif {$net != {}} {
    # This is a net
#     set placedLeafCells [get_cells -quiet -of $net \
#                      -filter {IS_PRIMITIVE && PRIMITIVE_LEVEL!="INTERNAL"} ]
    set placedLeafCells [get_cells -quiet -of [get_pins -quiet -leaf -of $net] \
                     -filter {IS_PRIMITIVE && (LOC!= "")} ]
  } else {
    # This is a pin
#     set placedLeafCells [get_cells -quiet -of [get_pins -quiet -leaf -of [get_nets -quiet -of $pin]] \
#                      -filter {IS_PRIMITIVE && PRIMITIVE_LEVEL!="INTERNAL && (LOC!= "")} ]
    set placedLeafCells [get_cells -quiet -of [get_pins -quiet -leaf -of [get_nets -quiet -of $pin]] \
                     -filter {IS_PRIMITIVE && (LOC!= "")} ]
  }
  if {$placedLeafCells == {}} {
    # OK, all connected cells already unplaced
    return 0
  }

  puts " WARN - [llength $placedLeafCells] cell(s) are placed"

  if {$save} {
    if {![info exists LOC]} { unset -nocomplain LOC }
    foreach cell $placedLeafCells loc [get_property -quiet LOC $placedLeafCells] bel [get_property -quiet BEL $placedLeafCells] {
      # LOC: SLICE_X23Y125
      # BEL: SLICEL.B5LUT
      set LOC($cell) [list $loc $bel]
      if {$debug>1} {
        puts " DEBUG: cell $cell ([get_property -quiet REF_NAME $cell]) is placed (LOC: $loc / BEL:$bel)"
      }
    }
    if {$debug} {
      puts " DEBUG: unplacing [llength $placedLeafCells] cells"
    }
    unplace_cell $placedLeafCells
  } else {
    return 1
  }

  return 0
}

proc ::tclapp::xilinx::designutils::insert_buffer::restoreCellLoc {{clear 1}} {
  # Summary : check that all attached cells are unplaced. All the connected cells
  # can be forced to be unplaced

  # Argument Usage:
  # clear : 

  # Return Value:
  # 0 if all the connected cells are unplaced. 1 otherwise
  # TCL_ERROR if failed

  # Categories: xilinxtclstore, designutils

  variable debug
  variable LOC
  if {![info exists LOC]} {
    return 0
  }
  if {$debug} {
    puts " DEBUG: restoring LOC property for [llength [array names LOC]] cells"
  }
  set cellsToPlace [list]
  foreach cell [array names LOC] {
    foreach {loc bel} $LOC($cell) { break }
    # LOC: SLICE_X23Y125
    # BEL: SLICEL.B5LUT
    # Need to generate the placement info in the following format: SLICE_X23Y125/B5LUT
    set placement "$loc/[lindex [split $bel .] end]"
    lappend cellsToPlace $cell
    lappend cellsToPlace $placement
    if {$debug>1} {
      puts " DEBUG: restoring placement for $cell ([get_property -quiet REF_NAME $cell]) at $placement (LOC: $loc / BEL: $bel)"
    }
  }
  # Restore the cell placement in a single call to place_cell
  if {[catch {place_cell $cellsToPlace} errorstring]} {
    puts " -E- $errorstring"
  }
  if {$clear} { catch {unset LOC} }
  return 0
}

proc ::tclapp::xilinx::designutils::insert_buffer::genUniqueName {name} {
  # Summary : return an unique and non-existing cell or net name

  # Argument Usage:
  # name : base name for the cell or net

  # Return Value:
  # unique cell or net name

  # Categories: xilinxtclstore, designutils

  # Names must be unique among the net and cell names
  if {([get_cells -quiet $name] == {}) && ([get_nets -quiet $name] == {})} { return $name }
  set index 0
  while {([get_cells -quiet ${name}_${index}] != {}) || ([get_nets -quiet ${name}_${index}] != {})} { incr index }
  return ${name}_${index}
}

proc ::tclapp::xilinx::designutils::insert_buffer::createCell {cellName refName {parentName {}}} {
  # Summary : create a new cell under the parent hierarchical level

  # Argument Usage:
  # cellName : cell name (always form the top-level)
  # refName : cell ref name
  # parentName : parent hierarchical level

  # Return Value:
  # cell object

  # Categories: xilinxtclstore, designutils

  variable debug
  if {[get_cells -quiet $cellName] != {}} {
    error " error - cell $cellName already exists"
  }
  set refName [string toupper $refName]
  set cellRef [get_lib_cells -quiet [get_libs]/$refName]
  if {$cellRef == {}} {
    error " error - cannot find cell type $refName"
  }

  # NOTE: the name passed to create_cell needs to be pre-processed
  # when the design has been partially flattened.
  # For example, if original cell is :
  #   ila_dac_baseband_ADC/U0/ila_core_inst/u_ila_regs/reg_15/I_EN_CTL_EQ1.U_CTL/xsdb_reg_reg[2]
  # but that the parent of that cell is (partially flattened):
  #   ila_dac_baseband_ADC/U0
  # then create_cell cannot be called as below:
  #   create_cell -libref FDRE ila_dac_baseband_ADC/U0/ila_core_inst/u_ila_regs/reg_15/I_EN_CTL_EQ1.U_CTL/xsdb_reg_reg[2]_clone
  # otherwise create_cell tries to create cell xsdb_reg_reg[2]_clone under ila_dac_baseband_ADC/U0/ila_core_inst/u_ila_regs/reg_15/I_EN_CTL_EQ1.U_CTL
  # which does not exist. Instead, create_cell must be called with:
  #   create_cell -libref FDRE {ila_dac_baseband_ADC/U0/ila_core_inst\/u_ila_regs\/reg_15\/I_EN_CTL_EQ1.U_CTL\/xsdb_reg_reg[2]_clone}
  # The code below figures out the parent of the original driver cell and build the command
  # line for create_cell accordingly

  set hierSep [get_hierarchy_separator]
  # remove parent prefix from the cloned cell name to extract the local name
  regsub "^${parentName}${hierSep}" $cellName {} localName
  # escape all the hierarchy separator characters in the local name
  regsub -all $hierSep $localName [format {\%s} $hierSep] localName
  # create the full cell name by appending the escaped local name to the parent name
  if {$parentName != {}} {
    set cellName ${parentName}${hierSep}${localName}
    if {$debug} { puts " DEBUG: cell $cellName ($cellRef) created (parent=$parentName)" }
  } else {
    set cellName ${localName}
    if {$debug} { puts " DEBUG: cell $cellName ($cellRef) created" }
  }
  create_cell -reference $cellRef $cellName
  set cellObj [get_cells -quiet $cellName]
  return $cellObj
}

proc ::tclapp::xilinx::designutils::insert_buffer::createNet {netName {parentName {}}} {
  # Summary : create a new net under the parent hierarchical level

  # Argument Usage:
  # netName : net name (always form the top-level)
  # parentName : parent hierarchical level

  # Return Value:
  # net object

  # Categories: xilinxtclstore, designutils

  variable debug
  if {[get_nets -quiet $netName] != {}} {
    error " error - net $netName already exists"
  }

  # NOTE: the name passed to create_net needs to be pre-processed for the same reason as for createCell

  set hierSep [get_hierarchy_separator]
  # remove parent cell prefix from the cloned cell name to extract the local name
  regsub "^${parentName}${hierSep}" $netName {} localName
  # escape all the hierarchy separator characters in the local name
  regsub -all $hierSep $localName [format {\%s} $hierSep] localName
  # create the net by appending the escaped local name to the parent name
  if {$parentName != {}} {
    set netName ${parentName}${hierSep}${localName}
    if {$debug} { puts " DEBUG: net ${parentName}${hierSep}${localName} created (parent=$parentName)" }
  } else {
    set netName ${localName}
    if {$debug} { puts " DEBUG: net ${localName} created" }
  }
  create_net -verbose $netName
  set netObj [get_nets -quiet $netName]
  return $netObj
}

proc ::tclapp::xilinx::designutils::insert_buffer::insertBufferOnPin {pin {bufferType BUFH}} {
  # Summary : insert a buffer or any 2-pins cell on a pin

  # Argument Usage:
  # pin : Pin to insert buffer on. After insertion, the driver of the net is connected to the input of the inserted cell
  # [bufferType = BUFH] : Type of 2-pins cell to insert

  # Return Value:
  # the inserted cell object if succeeded
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug
  if {$pin == {}} {
    error " error - no pin specified"
  }

  set hierSep [get_hierarchy_separator]
  set bufferType [string toupper $bufferType]
  set bufCellRef [get_lib_cells -quiet [get_libs]/$bufferType]
  if {$bufCellRef == {}} {
    error " error - cannot find cell type $bufferType"
  }
  if {[get_property -quiet NUM_PINS $bufCellRef] != 2} {
    error " error - only 2-pins cells can be inserted"
  }

  set insertionPin [get_pins -quiet $pin -filter {IS_LEAF}]
  if {$insertionPin == {}} {
    set insertionPin [get_ports -quiet $pin]
  }
  switch [llength $insertionPin] {
    0 {
      error " error - cannot find a leaf pin or port matching $pin"
    }
    1 {
      # Ok
    }
    default {
      # More than 1 net
      error " error - more than 1 ([llength $insertionPin]) leaf pin or port match $pin"
    }
  }

  set pinClass [string toupper [get_property -quiet CLASS $insertionPin]]
  set pinDir [string toupper [get_property -quiet DIRECTION $insertionPin]]
  set net [get_nets -quiet -of $insertionPin]
  # We first need to check that all the cells connected to the register are NOT placed.
  # Otherwise the connect_net command cannot work
  unplaceConnectedCells $net

  # Generate the buffer name based on the net name connected to the pin
  set bufCellName [genUniqueName ${net}_${bufferType}]
  set parentName [get_property -quiet PARENT_CELL $net]
  set bufCell [createCell $bufCellName $bufferType $parentName]
  set bufInPin [get_pins -quiet -of $bufCell -filter {DIRECTION == IN}]
  set bufOutPin [get_pins -quiet -of $bufCell -filter {DIRECTION == OUT}]

  # Generate the new net name
  set bufNetName [genUniqueName ${bufCellName}_net]
  set parentName [get_property -quiet PARENT_CELL $net]
  set bufNet [createNet $bufNetName $parentName]

  if {$debug} { puts " DEBUG: pin direction: [get_property DIRECTION $insertionPin]" }
  if {(($pinClass == {PIN}) && ($pinDir == {OUT}))
    || (($pinClass == {PORT}) && ($pinDir == {IN}))} {
    # OUT leaf pin or IN port
    if {$debug} { puts " DEBUG: connect_net -hier -net $net -obj $bufOutPin" }
    # Connect buffer output pin to existing net
    connect_net -verbose -hier -net $net -obj $bufOutPin

    if {$debug} { puts " DEBUG: disconnect_net -prune -net $net -obj $insertionPin" }
    # Disconnect the driver pin
    disconnect_net -verbose -prune -net $net -obj $insertionPin

    if {$debug} { puts " DEBUG: connect_net -hier -net $bufNet -obj [list $insertionPin $bufInPin]" }
    # Reconnect the driver pin to the new net
    connect_net -verbose -hier -net $bufNet -obj [list $insertionPin $bufInPin]
  } else {
    # IN leaf pin or OUT port
    if {$debug} { puts " DEBUG: connect_net -hier -net $net -obj $bufInPin" }
    # Connect buffer input pin to existing net
    connect_net -verbose -hier -net $net -obj $bufInPin

    if {$debug} { puts " DEBUG: disconnect_net -prune -net $net -obj $insertionPin" }
    # Disconnect the driver pin
    disconnect_net -verbose -prune -net $net -obj $insertionPin

    if {$debug} { puts " DEBUG: connect_net -hier -net $bufNet -obj [list $insertionPin $bufOutPin]" }
    # Reconnect the driver pin to the new net
    connect_net -verbose -hier -net $bufNet -obj [list $insertionPin $bufOutPin]
  }

  # Is a LUT being inserted?
  if {[get_property -quiet PRIMITIVE_GROUP $bufCellRef] == {LUT}} {
    set_property INIT "10" $bufCell
#     set_property BEL "A6LUT" $bufCell
#     set_property MARK_DEBUG TRUE $bufNet
  }

  if {$debug} { puts " DEBUG: restoreCellLoc" }
  # Restore cells LOC
  restoreCellLoc

  puts " Inserted $bufferType to pin $pin"
  return $bufCell
}

proc ::tclapp::xilinx::designutils::insert_buffer::insertBufferOnNet {net {bufferType BUFH}} {
  # Summary : insert a buffer or any 2-pins cell on a net

  # Argument Usage:
  # net : Net to insert buffer on. After insertion, the driver of the net is connected to the input of the inserted cell
  # [bufferType = BUFH] : Type of 2-pins cell to insert

  # Return Value:
  # the inserted cell object if succeeded
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug
  if {$net == {}} {
    error " error - no net specified"
  }

  set hierSep [get_hierarchy_separator]
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
      error " error - more than 1 ([llength $bufOutNet]) net match $net"
    }
  }

  # Is the driver leaf pin or port connected to this net segment?
  # Note: a port can only be connected to this net segment if it is at the top level, i.e
  # it does not have any PARENT_CELL property
#   if {([get_pins -quiet -of $bufOutNet -filter {IS_LEAF && DIRECTION==OUT}] == {})
#         && !(([get_property -quiet PARENT_CELL $bufOutNet] == {}) && ([get_ports -quiet -of $bufOutNet -filter {DIRECTION==IN}] == {})) } {
#   }
  if {([get_pins -quiet -of $bufOutNet -filter {IS_LEAF && DIRECTION==OUT}] != {})
        || (([get_property -quiet PARENT_CELL $bufOutNet] == {}) && ([get_ports -quiet -of $bufOutNet -filter {DIRECTION==IN}] != {})) } {
    # Since the driver leaf pin or port is connected on this net segment, it is easy to get it
    set bufSrcPin [get_pins -quiet -leaf -of $bufOutNet -filter {DIRECTION == OUT}]
    if {$bufSrcPin == {}} {
      set bufSrcPin [get_ports -quiet -of $bufOutNet -filter {DIRECTION == IN}]
    }
  } else {
    # No, then search for the driver pin connected to any of the net segments
    set driverPin [get_pins -quiet -leaf -of $bufOutNet -filter {IS_LEAF && DIRECTION==OUT}]
    if {$driverPin == {}} {
      # A port maybe?
      set driverPin [get_pins -quiet -of $bufOutNet -filter {DIRECTION==IN}]
    }
    if {$debug>1} { puts " DEBUG: driverPin: $driverPin" }
    # Found one?
    if {$driverPin == {}} {
      # No
      error " error - no driver pin or port is connected to the net ($net)"
    } else {
      # Yes
      # Since there is one driver leaf pin connected somewhere on the net, we need to find which
      # of the hierarchical pin connects directly or indirectly to the driver leaf pin
      set bufSrcPin [all_fanin -quiet -to $bufOutNet -level 1 -pin_level 1 -trace_arcs all ]
      # It can happen that this segment of the net connects to 2 or more hierarchical pins of
      # direction OUT even when there is only one physical driver of the net located in a different
      # hierarchical level. In this case, search for the hierarchical pin directly connected to this
      # segment of the net
      if {$bufSrcPin > 1} {
        foreach hierPin $bufSrcPin {
          foreach boundaryNet [get_nets -quiet -boundary_type both -of $hierPin] {
            if {$boundaryNet == $bufOutNet} {
              # Ok, we have found the net segment we want to insert the buffer on. This means
              # that we found the correct hierarchical pin and we can stop searching here
              set bufSrcPin $hierPin
              break
            }
          }
        }
      }
    }
  }
  if {$debug>1} { puts " DEBUG: bufSrcPin: $bufSrcPin" }

  # Only support nets with a single driver
  if {[llength $bufSrcPin] > 1} {
    error " error - net ($bufOutNet) has [llength $bufSrcPin] drivers ($bufSrcPin). Nets with multiple driver pins are not supported"
  }

  # We first need to check that all the cells connected to the register are NOT placed.
  # Otherwise the connect_net command cannot work
  unplaceConnectedCells $bufOutNet

  # Generate the buffer name
  set bufCellName [genUniqueName ${bufOutNet}_${bufferType}]
  set parentName [get_property -quiet PARENT_CELL $bufOutNet]
  set bufCell [createCell $bufCellName $bufferType $parentName]
  set bufInPin [get_pins -quiet -of $bufCell -filter {DIRECTION == IN}]
  set bufOutPin [get_pins -quiet -of $bufCell -filter {DIRECTION == OUT}]

  # Generate the new net name
  set bufInNetName [genUniqueName ${bufCellName}_net]
  set parentName [get_property -quiet PARENT_CELL $bufOutNet]
  set bufInNet [createNet $bufInNetName $parentName]

  if {$debug} { puts " DEBUG: connect_net -hier -net $bufOutNet -obj $bufOutPin" }
  # Connect buffer output pin
  connect_net -verbose -hier -net $bufOutNet -obj $bufOutPin

  if {$debug} { puts " DEBUG: disconnect_net -prune -net $bufOutNet -obj $bufSrcPin" }
  # Disconnect the driver pin
  disconnect_net -verbose -prune -net $bufOutNet -obj $bufSrcPin

  if {$debug} { puts " DEBUG: connect_net -hier -net $bufInNet -obj [list $bufSrcPin $bufInPin]" }
  # Reconnect the driver pin to the new net
  connect_net -verbose -hier -net $bufInNet -obj [list $bufSrcPin $bufInPin]

  # Is a LUT being inserted?
  if {[get_property -quiet PRIMITIVE_GROUP $bufCellRef] == {LUT}} {
    set_property INIT "10" $bufCell
#     set_property BEL "A6LUT" $bufCell
#     set_property MARK_DEBUG TRUE $bufInNet
  }

  if {$debug} { puts " DEBUG: restoreCellLoc" }
  # Restore cells LOC
  restoreCellLoc

  puts " Inserted $bufferType to drive net $net"
  return $bufCell
}

proc ::tclapp::xilinx::designutils::insert_buffer::getPinOrPort {name} {
  # Summary : insert a buffer or any 2-pins cell on a net

  # Argument Usage:
  # name :

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  set pin [get_pins -quiet $name]
  if {$pin != {}} { return $pin }
  return [get_ports -quiet $name]
}

proc ::tclapp::xilinx::designutils::insert_buffer::getOrCreateNet {netName {parentName {}}} {
  # Summary : create a new net under the parent hierarchical level if it does not already exist

  # Argument Usage:
  # netName : net name (always form the top-level)
  # parentName : parent hierarchical level

  # Return Value:
  # net object

  # Categories: xilinxtclstore, designutils

  variable debug
  set net [get_nets -quiet $netName]
  if {$net != {}} {
    if {$debug>1} { puts " DEBUG: found net $net" }
    return $net
  }
  set net [get_nets -quiet [createNet $netName $parentName]]
  if {$net == {}} {
    error " error - could not find or create net $netName"
  }
  if {$debug>1} { puts " DEBUG: did not find net $netName. The net $net has been created" }
  return $net
}

proc ::tclapp::xilinx::designutils::insert_buffer::getOrCreateCell {cellName refName {parentName {}}} {
  # Summary : create a new cell under the parent hierarchical level if it does not already exist

  # Argument Usage:
  # cellName : cell name (always form the top-level)
  # refName : cell ref name (always form the top-level)
  # parentName : parent hierarchical level

  # Return Value:
  # cell object

  # Categories: xilinxtclstore, designutils

  variable debug
  set cell [get_cells -quiet $cellName]
  if {$cell != {}} {
    if {$debug>1} { puts " DEBUG: found cell $cell" }
    return $cell
  }
  set cell [get_cells -quiet [createCell $cellName $refName $parentName]]
  if {$cell == {}} {
    error " error - could not find or create cell $cellName"
  }
  if {$debug>1} { puts " DEBUG: did not find cell $cellName. The cell $cell has been created" }
  return $cell
}

proc ::tclapp::xilinx::designutils::insert_buffer::getNetSegmentDriverPins {netName} {
  # Summary : return all the hierarchical and leaf pins connected to this net segment

  # Argument Usage:
  # netName : Net segment name

  # Return Value:
  # 0 if succeeded
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug
  if {$netName == {}} {
    error " error - no net specified"
  }

  set hierSep [get_hierarchy_separator]
  set net [get_nets -quiet $netName]
  switch [llength $net] {
    0 {
      error " error - cannot find net $netName"
    }
    1 {
      # Ok
    }
    default {
      # More than 1 net
      error " error - more than 1 ([llength $net]) net match $netName"
    }
  }

  # Is the driver leaf pin or port connected to this net segment?
  # Note: a port can only be connected to this net segment if it is at the top level, i.e
  # it does not have any PARENT_CELL property
#   if {([get_pins -quiet -of $net -filter {IS_LEAF && DIRECTION==OUT}] == {})
#         && (!([get_property -quiet PARENT_CELL $net] == {}) && ([get_ports -quiet -of $net -filter {DIRECTION==IN}] == {})) } {
#   }
  if {([get_pins -quiet -of $net -filter {IS_LEAF && DIRECTION==OUT}] != {})
        || (([get_property -quiet PARENT_CELL $net] == {}) && ([get_ports -quiet -of $net -filter {DIRECTION==IN}] != {})) } {
# puts "<HERE1>"
    # Since the driver leaf pin or port is connected on this net segment, it is easy to get it
    set bufSrcPin [get_pins -quiet -leaf -of $net -filter {DIRECTION == OUT}]
    if {$bufSrcPin == {}} {
      set bufSrcPin [get_ports -quiet -of $net -filter {DIRECTION == IN}]
    }
  } else {
# puts "<HERE2><[get_pins -quiet -of $net -filter {IS_LEAF && DIRECTION==OUT}]><[get_property -quiet PARENT_CELL $net]><[get_ports -quiet -of $net -filter {DIRECTION==IN}]>"
    # No, then search for the driver pin connected to any of the net segments
    set driverPin [get_pins -quiet -leaf -of $net -filter {IS_LEAF && DIRECTION==OUT}]
    if {$driverPin == {}} {
      # A port maybe?
      set driverPin [get_pins -quiet -of $net -filter {DIRECTION==IN}]
    }
    if {$debug>1} { puts " DEBUG: driverPin: $driverPin" }
    # Found one?
    if {$driverPin == {}} {
      # No
      error " error - no driver pin or port is connected to the net ($net)"
    } else {
      # Yes
      # Since there is one driver leaf pin connected somewhere on the net, we need to find which
      # of the hierarchical pin connects directly or indirectly to the driver leaf pin
      set bufSrcPin [all_fanin -quiet -to $net -level 1 -pin_level 1 -trace_arcs all ]
      # It can happen that this segment of the net connects to 2 or more hierarchical pins of
      # direction OUT even when there is only one physical driver of the net located in a different
      # hierarchical level. In this case, search for the hierarchical pin directly connected to this
      # segment of the net
      if {$bufSrcPin > 1} {
        foreach hierPin $bufSrcPin {
          foreach boundaryNet [get_nets -quiet -boundary_type both -of $hierPin] {
            if {$boundaryNet == $net} {
              # Ok, we have found the net segment we want to insert the buffer on. This means
              # that we found the correct hierarchical pin and we can stop searching here
              set bufSrcPin $hierPin
              break
            }
          }
        }
      }
    }
  }
  if {$debug>1} { puts " DEBUG: bufSrcPin: $bufSrcPin" }

  puts " Driver pins: $bufSrcPin"
  return $bufSrcPin
}

proc ::tclapp::xilinx::designutils::insert_buffer::getNetSegmentLoadPins {netName} {
  # Summary : return all the hierarchical and leaf pins connected to this net segment

  # Argument Usage:
  # netName : Net segment name

  # Return Value:
  # 0 if succeeded
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug
  if {$netName == {}} {
    error " error - no net specified"
  }

  set hierSep [get_hierarchy_separator]
  set net [get_nets -quiet $netName]
  switch [llength $net] {
    0 {
      error " error - cannot find net $netName"
    }
    1 {
      # Ok
    }
    default {
      # More than 1 net
      error " error - more than 1 ([llength $net]) net match $netName"
    }
  }

  set leafPins [get_pins [all_fanout -from $net -level 1 -pin_levels 1 -trace_arcs all] -filter {IS_LEAF && DIRECTION==IN}]
  set leafPorts [get_ports [all_fanout -from $net -level 1 -pin_levels 1 -trace_arcs all] -filter {DIRECTION==OUT}]
  set hierPins [get_pins [all_fanout -from $net -level 1 -pin_levels 1 -trace_arcs all] -filter {!IS_LEAF}]
  
  set allPins [concat $leafPins $leafPorts $hierPins]
  if {$debug>1} { puts " DEBUG: allPins: $allPins" }
  return $allPins
}

#####################################
################ EOF ################
#####################################
