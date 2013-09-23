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

  # Categories: xilinctclstore, designutils

  uplevel ::tclapp::xilinx::designutils::insert_buffer::insert_buffer_chain $net $args
  return 0
}

proc ::tclapp::xilinx::designutils::insert_buffer {net {bufferType BUFH}} {
  # Summary : insert a buffer or any 2-pins cell on a net

  # Argument Usage:
  # net : Net to insert buffer on. After insertion, the driver of the net is connected to the input of the inserted cell
  # [bufferType=BUFH] : Type of 2-pins cell to insert

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinctclstore, designutils

  return [uplevel ::tclapp::xilinx::designutils::insert_buffer::insert_buffer $net $bufferType]
}

proc ::tclapp::xilinx::designutils::remove_buffer {cell} {
  # Summary : insert a buffer or any 2-pins cell on a net

  # Argument Usage:
  # cell : Cell to be removed

  # Return Value:
  # 0 if succeeded
  # TCL_ERROR if an error happened

  # Categories: xilinctclstore, designutils

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
  # args : List of 2-pins cell types to insert

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinctclstore, designutils

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

proc ::tclapp::xilinx::designutils::insert_buffer::insert_buffer {net {bufferType BUFH}} {
  # Summary : insert a buffer or any 2-pins cell on a net

  # Argument Usage:
  # net : Net to insert buffer on. After insertion, the driver of the net is connected to the input of the inserted cell
  # [bufferType=BUFH] : Type of 2-pins cell to insert

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinctclstore, designutils

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
      # It can happen that this segment of the net connect to 2 or more hierarchical pins of
      # direction OUT even when there is only one physical driver of the net. In this case, 
      # search for the hierarchical pin directly connected to this net segment
      if {$bufSrcPin > 1} {
        foreach hierPin $bufSrcPin {
          foreach boundaryNet [get_nets -quiet -boundary_type both -of $hierPin] {
            if {$boundaryNet == $bufOutNet} {
              # Ok, we found the net segment we want to insert the buffer on. This means
              # that we found the correct hierarchical pin and we can stop searching here
              set bufSrcPin $hierPin
              break
            }
          }
        }
      }
    }
  } else {
    # Since the driver leaf pin is connected on this net segment, it is easy to get it
    set bufSrcPin [get_pins -quiet -leaf -of $bufOutNet -filter {DIRECTION == OUT}]
  }

  # Only support nets with a single driver
  if {[llength $bufSrcPin] > 1} {
    error " error - net ($bufOutNet) has [llength $bufSrcPin] drivers ($bufSrcPin). Nets with multiple driver pins are not supported"
  }

  # We first need to check that all the cells connected to the register are NOT placed. 
  # Otherwise the connect_net command cannot work
  unplaceConnectedCells $bufOutNet
#   if {[checkAllConnectedCellsUnplaced $bufOutNet 1] == 1} {
#     error "  error - net $bufOutNet is connected to some unplaced instances. All cells must be unplaced prior inserting a buffer"
#   }

  # Generate the buffer name
  set bufCellName [genUniqueCellName ${bufOutNet}_${bufferType}]
# puts "<bufCellName:$bufCellName>"
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
  set parentName [get_property -quiet PARENT_CELL $bufOutNet]
# puts "<parentName:$parentName>"
  # remove parent prefix from the cloned cell name to extract the local name
  regsub "^${parentName}${hierSep}" $bufCellName {} localName
# puts "<localName:$localName>"
  # escape all the hierarchy separator characters in the local name
  regsub -all $hierSep $localName [format {\%s} $hierSep] localName
# puts "<localName:$localName>"
  # create the full cell name by appending the escaped local name to the parent name
  if {$parentName != {}} {
    create_cell -reference $bufCellRef ${parentName}${hierSep}${localName}
    if {$debug} { puts " DEBUG: cell ${parentName}${hierSep}${localName} created (1)" }
  } else {
    create_cell -reference $bufCellRef ${localName}
    if {$debug} { puts " DEBUG: cell ${localName} created (2)" }
  }
#   create_cell -reference $bufCellRef $bufCellName
  set bufCell [get_cells -quiet $bufCellName]
  set bufInPin [get_pins -quiet -of $bufCell -filter {DIRECTION == IN}]
  set bufOutPin [get_pins -quiet -of $bufCell -filter {DIRECTION == OUT}]

  # Generate the new net name
  set bufInNetName [genUniqueNetName ${bufCellName}_net]
# puts "<bufInNetName:$bufInNetName>"
  # NOTE: the name passed to create_net needs to be pre-processed for the same reason as for create_cell
  set parentName [get_property -quiet PARENT_CELL $bufOutNet]
  # remove parent cell prefix from the cloned cell name to extract the local name
  regsub "^${parentName}${hierSep}" $bufInNetName {} localName
  # escape all the hierarchy separator characters in the local name
  regsub -all $hierSep $localName [format {\%s} $hierSep] localName
  # create the net by appending the escaped local name to the parent name
#   create_net $bufInNetName
  if {$parentName != {}} {
    create_net -verbose ${parentName}${hierSep}${localName}
    if {$debug} { puts " DEBUG: net ${parentName}${hierSep}${localName} created (1)" }
  } else {
    create_net -verbose ${localName}
    if {$debug} { puts " DEBUG: net ${localName} created (2)" }
  }
  set bufInNet [get_nets -quiet $bufInNetName]

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
  return 0
}

proc ::tclapp::xilinx::designutils::insert_buffer::remove_buffer {cell} {
  # Summary : insert a buffer or any 2-pins cell on a net

  # Argument Usage:
  # net : Net to insert buffer on. After insertion, the driver of the net is connected to the input of the inserted cell
  # [bufferType=BUFH] : Type of 2-pins cell to insert

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinctclstore, designutils

  variable debug
  if {$cell == {}} {
    error " error - no cell specified"
  }
  
#   set hierSep [get_hierarchy_separator]
  set buffer [get_cells -quiet $cell]
  switch [llength $buffer] {
    0 {
      error " error - cannot find cell $cell"
    }
    1 {
      # Ok
    }
    default {
      # More than 1 net
      error " error - more than 1 cell match $cell"
    }
  }
  set bufCellRef [get_lib_cells -quiet [get_libs]/[get_property -quiet REF_NAME $buffer]]
  if {[get_property -quiet NUM_PINS $bufCellRef] != 2} {
    error " error - only 2-pins cells can be removed"
  }
  set bufOutPin [get_pins -quiet -of $buffer -filter {DIRECTION == OUT}]
  set bufOutNet [get_nets -quiet -of $bufOutPin]
  set bufInNet [get_nets -quiet -of [get_pins -quiet -of $buffer -filter {DIRECTION == IN}]]
  set loadPins [get_pins -quiet -leaf -of $bufOutNet -filter {DIRECTION != OUT}]
  set driverPin [get_pins -quiet -leaf -of $bufInNet -filter {DIRECTION == OUT}]
  set driverPinNet [get_nets -quiet -of $driverPin]

  # We first need to check that all the cells connected to the buffer are NOT placed. 
  # Otherwise the connect_net command cannot work
  unplaceConnectedCells $buffer
#   if {[checkAllConnectedCellsUnplaced $buffer 1] == 1} {
#     error "  error - net $buffer is connected to some unplaced instances. All cells must be unplaced prior removing a buffer"
#   }

  if {$debug} { puts " DEBUG: disconnect_net -verbose -prune -net $driverPinNet -obj $driverPin" }
  # Disconnect the driver pin
  disconnect_net -verbose -prune -net $driverPinNet -obj $driverPin

  if {$debug} { puts " DEBUG: connect_net -verbose -hier -net $bufOutNet -obj $driverPin" }
  # Reconnect the driver pin to the to-be-deleted buffer output net
  connect_net -verbose -hier -net $bufOutNet -obj $driverPin

  if {$debug} { puts " DEBUG: disconnect_net -verbose -prune -net $bufOutNet -obj $bufOutPin" }
  # Disconnect the to-be-deleted buffer output pin
  disconnect_net -verbose -prune -net $bufOutNet -obj $bufOutPin
  
  if {$debug} { puts " DEBUG: remove_cell $buffer" }
  # Remove buffer
  remove_cell -verbose $buffer

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

  # Return Value:
  # 0 if all the connected cells are unplaced. 1 otherwise
  # TCL_ERROR if failed

  # Categories: xilinctclstore, designutils

  variable debug
  variable LOC
  set cell [get_cells -quiet $name]
  set net [get_nets -quiet $name]
  if {($cell == {}) && ($net == {})} {
    error " error - cannot find a cell or a net matching $name"
  }
  if {$cell != {}} {
    # This is a cell
#     set placedLeafCells [get_cells -quiet -of \
#                                  [get_nets -of $cell] -filter {IS_PRIMITIVE && PRIMITIVE_LEVEL!="INTERNAL"} ]
    set placedLeafCells [get_cells -quiet -of \
                                 [get_pins -quiet -leaf -of [get_nets -quiet -of $cell]] -filter {IS_PRIMITIVE && (LOC!= "")} ]
  } else {
    # This is a net
#     set placedLeafCells [get_cells -quiet -of $net \
#                      -filter {IS_PRIMITIVE && PRIMITIVE_LEVEL!="INTERNAL"} ]
    set placedLeafCells [get_cells -quiet -of [get_pins -quiet -leaf -of $net] \
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
        puts " DEBUG: cell $cell is placed (LOC: $loc / BEL:$bel)"
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
  # name : cell name or net name

  # Return Value:
  # 0 if all the connected cells are unplaced. 1 otherwise
  # TCL_ERROR if failed

  # Categories: xilinctclstore, designutils

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
      puts " DEBUG: restoring placement for $cell at $placement (LOC: $loc / BEL: $bel)"
    }
  }
  # Restore the cell placement
  if {[catch {place_cell $cellsToPlace} errorstring]} {
    puts " -E- $errorstring"
  }
  if {$clear} { catch {unset LOC} }
  return 0
}

proc ::tclapp::xilinx::designutils::insert_buffer::checkAllConnectedCellsUnplaced {name {force 0}} {
  # Summary : check that all attached cells are unplaced. All the connected cells
  # can be forced to be unplaced

  # Argument Usage:
  # name : cell name or net name

  # Return Value:
  # 0 if all the connected cells are unplaced. 1 otherwise
  # TCL_ERROR if failed

  # Categories: xilinctclstore, designutils

  variable debug
  set cell [get_cells -quiet $name]
  set net [get_nets -quiet $name]
  if {($cell == {}) && ($net == {})} {
    error " error - cannot find a cell or a net matching $name"
  }
  if {$cell != {}} {
    # This is a cell
#     set allConnectedLeafCells [get_cells -quiet -of \
#                                  [get_nets -of $cell] -filter {IS_PRIMITIVE && PRIMITIVE_LEVEL!="INTERNAL"} ]
    set allConnectedLeafCells [get_cells -quiet -of \
                                 [get_nets -quiet -of $cell] -filter {IS_PRIMITIVE} ]
  } else {
    # This is a net
#     set allConnectedLeafCells [get_cells -quiet -of $net \
#                      -filter {IS_PRIMITIVE && PRIMITIVE_LEVEL!="INTERNAL"} ]
    set allConnectedLeafCells [get_cells -quiet -of $net \
                     -filter {IS_PRIMITIVE} ]
  }
  set props [lsort -unique [get_property -quiet LOC $allConnectedLeafCells ]]
  if { ($props == [list {}]) || ($props == {})} {
    # OK, all connected cells unplaced
    return 0
  }
  if {$force} {
    if {$debug} {
      puts " WARN - some cells are placed and will be unplaced"
    }
    # Force unplacing all the leaf cells
    unplace_cell [get_cells -quiet $allConnectedLeafCells -filter {((IS_PRIMITIVE==true && PRIMITIVE_LEVEL!="INTERNAL")  && (LOC!=""))}]
    # Double-check that all the cells have been unplaced
    set props [lsort -unique [get_property -quiet LOC $allConnectedLeafCells ]]
    if { ($props != [list {}]) && ($props != {})} {
      error " error - some cells could not be unplaced"
    }
    return 0
  } else {
    if {$debug} {
      puts " WARN - some cells are placed"
    }
    if {$debug>1} {
      foreach cell [get_cells -quiet $allConnectedLeafCells -filter {LOC!=""}] {
        puts " DEBUG -    $cell => PLACED"
      }
    }
    return 1
  }
}

proc ::tclapp::xilinx::designutils::insert_buffer::genUniqueCellName {name} {
  # Summary : return an unique and non-existing cell name

  # Argument Usage:
  # name : base name for the cell

  # Return Value:
  # cell name

  # Categories: xilinctclstore, designutils

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

  # Categories: xilinctclstore, designutils

  if {[get_nets -quiet $name] == {}} { return $name }
  set index 0
  while {[get_nets -quiet ${name}_${index}] != {}} { incr index }
  return ${name}_${index}
}
