package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export insert_buffer insert_buffer_chain
    namespace export remove_buffer
    namespace export insert_clock_probe
    namespace export rename_net
}

proc ::tclapp::xilinx::designutils::insert_buffer_chain {args} {
  # Summary : Insert a chain of buffers or any 2-pins cells on a net or a pin

  # Argument Usage:
  # -net <arg>: Net name to insert the chain of buffer(s) on. After insertion, the driver of the net is connected to the input of the inserted cell
  # -pin <arg>: Pin name to insert the chain of buffer(s) on
  # -name <arg>: Net or pin name to insert the chain of buffer(s) on
  # [-buffers <arg> = BUFG]: List of 2-pins cell types to insert

  # net : Net to insert buffer on. After insertion, the driver of the net is connected to the input of the inserted cell
  # args : List of 2-pins cell types to insert

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  uplevel [concat ::tclapp::xilinx::designutils::insert_buffer::insert_buffer_chain $args]
  return 0
}

proc ::tclapp::xilinx::designutils::insert_buffer {args} {
  # Summary : Insert a buffer or any 2-pins cell on a net or a pin

  # Argument Usage:
  # -net <arg>: Net name to insert the buffer on. After insertion, the driver of the net is connected to the input of the inserted cell
  # -pin <arg>: Pin name to insert the buffer on
  # -name <arg>: Net or pin name to insert the buffer on
  # [-buffer <arg> = BUFG]: Type of 2-pins cell to insert

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  return [uplevel [concat ::tclapp::xilinx::designutils::insert_buffer::insert_buffer $args]]
}

proc ::tclapp::xilinx::designutils::remove_buffer {args} {
  # Summary : Remove a buffer or any 2-pins cell

  # Argument Usage:
  # -cell <arg>: Buffer to be removed

  # Return Value:
  # 0 if succeeded
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  return [uplevel [concat ::tclapp::xilinx::designutils::insert_buffer::remove_buffer $args]]
}

proc ::tclapp::xilinx::designutils::insert_clock_probe {args} {
  # Summary : Insert a clock probe to the design and connect the probe to an output port. The output should not exist and is created by the command

  # Argument Usage:
  # -pin <arg>: Output leaf clock pin
  # -port <arg> : Output port name to be created
  # -diff_port <arg> : Output diff port name to be created
  # [-iostandard <arg>] : IOSTANDARD for created port(s)
  # [-schematic] : Display schematic of inserted probe

  # Return Value:
  # 0 if succeeded
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  return [uplevel [concat ::tclapp::xilinx::designutils::insert_buffer::insert_clock_probe $args]]
}

proc ::tclapp::xilinx::designutils::rename_net {args} {
  # Summary : Rename a local net name

  # Argument Usage:
  # -net <arg>: Net name to rename (full hierarchical name)
  # -name <arg>: New local net name

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  uplevel [concat ::tclapp::xilinx::designutils::insert_buffer::rename_net $args]
  return 0
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils::insert_buffer {
  variable debug 0
#   variable debug 1
#   variable debug 2
 } ]

proc ::tclapp::xilinx::designutils::insert_buffer::insert_buffer_chain {args} {
  # Summary : Insert a list of buffers or any 2-pins cells on a net

  # Argument Usage:
  # net : Net to insert buffer on. After insertion, the driver of the net is connected to the input of the inserted cell
  # args : Ordered list of 2-pins cell types to be inserted

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  set netOrPinName {}
  set buffers [list]
  set objectType {}
  set error 0
  set help 0
  if {[llength $args] == 0} {
    set help 1
  }
  while {[llength $args]} {
    set name [lshift args]
    switch -exact -- $name {
      -name {
           set netOrPinName [lflatten [lshift args]]
           set objectType {pin net}
      }
      -net {
           set netOrPinName [lflatten [lshift args]]
           set objectType {net}
      }
      -pin {
           set netOrPinName [lflatten [lshift args]]
           set objectType {pin}
      }
      -buffer -
      -buffers -
      -buffers {
           set buffers [lshift args]
      }
      -h -
      -help -
      -u -
      -usage {
           set help 1
      }
      default {
            if {[string match "-*" $name]} {
              puts " -E- option '$name' is not a valid option."
              incr error
            } else {
              puts " -E- option '$name' is not a valid option."
              incr error
            }
      }
    }
  }

  if {$help} {
    puts [format {
  Usage: insert_buffer_chain
              [-pin <pinName>]            - Pin name
              [-net <netName>]            - Net name
              [-name <pinName|netName>]   - Pin or net name (net first, then pin)
              [-buffers <cell(s)>]        - List of buffer Types
              [-usage|-u]                 - This help message

  Description: Insert a chain of buffers or any 2-pins cells on a net or a leaf pin

    Hierarchical pins are not supported (-pin/-name).
    
    -name: if name matches a net, then the buffer insertion is done on the net. If not,
    the buffer insertion is done on matching pin.

  Example:
     ::xilinx::designutils::insert_buffer_chain -pin bufg/O -buffers BUFG
     ::xilinx::designutils::insert_buffer_chain -net bufg_O_net -buffers {BUFG BUGH}
     ::xilinx::designutils::insert_buffer_chain -name bufg_O_net -buffers {LUT1}
} ]
    # HELP -->
    return -code ok
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  # Check that all the buffers are correct
  foreach bufferType $args {
    set bufferType [string toupper $bufferType]
    if {![isValidBuffer $bufferType]} {
      error " error - $bufferType is not a valid buffer type"
    }
    lappend buffers $bufferType
  }
  # Insert the chain for buffers
  foreach buffer $buffers {
  	switch $objectType {
  		pin {
        insert_buffer -pin $netOrPinName -buffer $buffer
  		}
  		net {
        insert_buffer -net $netOrPinName -buffer $buffer
  		}
  		default {
        insert_buffer -name $netOrPinName -buffer $buffer
  		}
  	}
  }
  return 0
}

proc ::tclapp::xilinx::designutils::insert_buffer::insert_buffer {args} {
  # Summary : Insert a buffer or any 2-pins cell on a net or a pin

  # Argument Usage:
  # name : Net or pin to insert buffer on
  # [bufferType = BUFG] : Type of 2-pins cell to insert

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug

  set netOrPinName {}
  set bufferType {BUFG}
  set objectType {}
  set error 0
  set help 0
  if {[llength $args] == 0} {
    set help 1
  }
  while {[llength $args]} {
    set name [lshift args]
    switch -exact -- $name {
      -name {
           set netOrPinName [lflatten [lshift args]]
           set objectType {pin net}
      }
      -net {
           set netOrPinName [lflatten [lshift args]]
           set objectType {net}
      }
      -pin {
           set netOrPinName [lflatten [lshift args]]
           set objectType {pin}
      }
      -buffer -
      -buffer {
           set bufferType [lshift args]
      }
      -h -
      -help -
      -u -
      -usage {
           set help 1
      }
      default {
            if {[string match "-*" $name]} {
              puts " -E- option '$name' is not a valid option."
              incr error
            } else {
              puts " -E- option '$name' is not a valid option."
              incr error
            }
      }
    }
  }

  if {$help} {
    puts [format {
  Usage: insert_buffer
              [-pin <pinName>]            - Pin name
              [-net <netName>]            - Net name
              [-name <pinName|netName>]   - Pin or net name (net first, then pin)
              [-buffer <cell>]            - Buffer Type
                                            Default: BUFG
              [-usage|-u]                 - This help message

  Description: Add buffer or any 2-pins cell on a net or a leaf pin
  
    Hierarchical pins are not supported (-pin/-name).

    -name: if name matches a net, then the buffer insertion is done on the net. If not,
    the buffer insertion is done on matching pin.

  Example:
     ::xilinx::designutils::insert_buffer -pin bufg/O -buffer BUFG
     ::xilinx::designutils::insert_buffer -net bufg_O_net
     ::xilinx::designutils::insert_buffer -name bufg_O_net -buffer BUFGCE
} ]
    # HELP -->
    return -code ok
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  if {$netOrPinName == {}} {
    error " error - no net or pin specified"
  }

  set hierSep [get_hierarchy_separator]
  set bufferType [string toupper $bufferType]
  if {![isValidBuffer $bufferType]} {
    error " error - $bufferType is not a valid buffer type"
  }

  if {[lsearch $objectType {net}] != -1} {
    set nets [get_nets -quiet $netOrPinName]
    if {$nets != {}} {
      if {[llength $nets]>1} {
        # More than 1 net
#         error " error - more than 1 ([llength $nets]) net match $netOrPinName"
        puts " WARN - [llength $nets] nets matching $netOrPinName"
      }
      foreach net $nets {
        insertBufferOnNet $net $bufferType
      }
      return 0
    }
  }

  if {[lsearch $objectType {pin}] != -1} {
    set pins [get_pins -quiet $netOrPinName -filter {IS_LEAF}]
    if {$pins != {}} {
      if {[llength $pins]>1} {
        # More than 1 net
#         error " error - more than 1 ([llength $pins]) leaf pin match $netOrPinName"
        puts " WARN - [llength $pins] leaf pins matching $netOrPinName"
      }
      foreach pin $pins {
        insertBufferOnPin $pin $bufferType
      }
      return 0
    }
  }

  error " error - no net or leaf pin matches $netOrPinName"
}

proc ::tclapp::xilinx::designutils::insert_buffer::remove_buffer {args} {
  # Summary : Remove a buffer or any 2-pins cell

  # Argument Usage:
  # -cell : Buffer to be removed

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug

  set cell {}
  set error 0
  set dryrun 0
  set safe 0
  set help 0
  if {[llength $args] == 0} {
    set help 1
  }
  while {[llength $args]} {
    set name [lshift args]
    switch -exact -- $name {
      -cell -
      -cell {
           set cell [lflatten [lshift args]]
      }
      -dryrun -
      -dryrun {
           set dryrun 1
      }
      -safe -
      -safe {
           set safe 1
      }
      -h -
      -help -
      -u -
      -usage {
           set help 1
      }
      default {
            if {[string match "-*" $name]} {
              puts " -E- option '$name' is not a valid option."
              incr error
            } else {
              puts " -E- option '$name' is not a valid option."
              incr error
            }
      }
    }
  }

  if {$help} {
    puts [format {
  Usage: remove_buffer
              [-cell <cellName>]          - Cell name
              [-safe]                     - Do not remove buffer if any of the parent
                                            modules has DONT_TOUCH attribute
              [-dryrun]                   - Check that the buffer(s) can be removed without removing
                                            the buffer(s)
              [-usage|-u]                 - This help message

  Description: Remove a buffer or any 2-pins cell

  Example:
     ::xilinx::designutils::remove_buffer -cell [get_cells bufg]
     ::xilinx::designutils::remove_buffer -cell [get_selected_objects]
} ]
    # HELP -->
    return -code ok
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

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

  set collectionResultDisplayLimit [get_param tcl.collectionResultDisplayLimit]
  set_param tcl.collectionResultDisplayLimit -1

# WARNING: [Constraints 18-1079] Register genblk2[3].digi_ohif_top_inst/digi_ohif_tx_pkt_assembler_inst/tx_fi_req_sent_fifo_oh1/U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rstbt/wr_rst_reg and genblk2[3].digi_ohif_top_inst/digi_ohif_tx_pkt_assembler_inst/tx_fi_req_sent_fifo_oh1/U0/xst_fifo_generator/gconvfifo.rf/gbiv5.bi/rstbt/wr_rst_fb_4 are from the same synchronizer and have the ASYNC_REG property set, but could not be placed into the same slice due to constraints or mismatched control signals on the registers.

  foreach buffer $buffers {
    set bufferType [get_property -quiet REF_NAME $buffer]
    if {![isValidBuffer $bufferType]} {
      puts " WARN - $bufferType is not a valid buffer type to be removed. Skipping cell $buffer"
      continue
    }
    set bufOutPin [getCellOPin $buffer]
    set bufOutNet [get_nets -quiet -of $bufOutPin]
    set bufInPin [getCellIPin $buffer]
    set bufCEPin [getCellCEPin $buffer]
    set bufInNet [get_nets -quiet -of $bufInPin]
    set loadPins [get_pins -quiet -leaf -of $bufOutNet -filter {DIRECTION != OUT}]
    set loadPorts [get_ports -quiet -of $bufOutNet -filter {DIRECTION != IN}]
    set driverPin [get_pins -quiet -leaf -of $bufInNet -filter {DIRECTION == OUT}]
    if {$driverPin == {}} {
      # If no driver leaf pin was found, maybe a port?
      set driverPin [get_ports -quiet -of $bufInNet -filter {DIRECTION == IN}]
    }

    if {$debug>1} { puts " DEBUG: driverPin: $driverPin" }
    if {$debug} { puts " DEBUG: processing $buffer ([get_property -quiet REF_NAME $buffer])" }
    set leafPins [list]
    if {[llength $loadPins]} {
      set leafPins [promoteInternalMacroPins $loadPins]
    }

    set error 0
    if {[checkDontTouchOnHierNets $driverPin]} {
    	puts " ERROR - found 1 or more net segment(s) with DONT_TOUCH attribute"
    	incr error
    }
    if {[llength $leafPins]} {
      if {[checkDontTouchOnHierNets $leafPins]} {
      	puts " ERROR - found 1 or more net segment(s) with DONT_TOUCH attribute"
      	incr error
      }
    }
    if {[llength $loadPorts]} {
      if {[checkDontTouchOnHierNets $loadPorts]} {
       	puts " ERROR - found 1 or more net segment(s) connected to port(s) with DONT_TOUCH attribute"
      	incr error
      }
    }
    if {$safe} {
      if {[llength $leafPins]} {
        if {[checkDontTouchOnHierCells $leafPins]} {
        	puts " ERROR - found 1 or more parent cell(s) with DONT_TOUCH attribute"
        	incr error
        }
      }
    }
    if {$error} {
    	puts " Some error(s) occured. Skipping cell '$buffer'"
    	continue
    }

    if {$dryrun} {
    	puts " Buffer '$buffer' can be removed. Dry run, nothing done (-dryrun)"
    	continue
    }

    set loads [list]
    foreach pin $leafPins {
    	lappend loads $pin
    }
    foreach port $loadPorts {
    	lappend loads $port
    }

    # Disconnect the to-be-deleted buffer control pins (if any)
    if {[llength $bufCEPin]} {
      if {$debug} { puts " DEBUG: disconnecting [llength $bufCEPin] CE pins" }
      disconnect_net -objects $bufCEPin
    }

#     if {$debug} { puts " DEBUG: disconnect_net -verbose -prune -net $bufInNet -obj $bufInPin" }
#     # Disconnect the to-be-deleted buffer input pin
#     disconnect_net -verbose -prune -net $bufInNet -obj $bufInPin

    if {$debug} { puts " DEBUG: disconnect_net -verbose -prune -net $bufOutNet -obj $bufOutPin" }
    # Disconnect the to-be-deleted buffer output pin
    disconnect_net -verbose -prune -net $bufOutNet -obj $bufOutPin
#     disconnect_net -verbose -net $bufOutNet -obj $bufOutPin


    # Disconnect and reconnect all the loads of the to-be-deleted buffer to the driver pin
    if {[llength $loads]} {
      if {$debug} { puts " DEBUG: disconnecting [llength $loads] load pin(s)" }
      disconnect_net -verbose -prune -obj $loads
      if {$debug} { puts " DEBUG: connecting [llength $loads] load pin(s)" }
  	  connect_net -verbose -hier -net $bufInNet -obj $loads
#   	  connect_net -verbose -hier -net_object_list [list $bufInNet $loads ]
    }

    if {$debug} { puts " DEBUG: disconnect_net -verbose -prune -net $bufInNet -obj $bufInPin" }
    # Disconnect the to-be-deleted buffer input pin
    disconnect_net -verbose -prune -net $bufInNet -obj $bufInPin
#     disconnect_net -verbose -net $bufInNet -obj $bufInPin

    if {$debug} { puts " DEBUG: remove_cell $buffer" }
    # Remove buffer
    # The linter complains on the following line
#     remove_cell -verbose $buffer
    # The workaround is to replace previous command with the one below
    eval [list remove_cell -verbose $buffer]
#     # Remove net: ** problem with busses, so commenting out **
#     remove_net -verbose $bufOutNet
  }

  set_param tcl.collectionResultDisplayLimit $collectionResultDisplayLimit

  return 0
}

#------------------------------------------------------------------------
# insert_clock_probe
#------------------------------------------------------------------------
# Usage: insert_clock_probe -pin <pinName> [-diff_port <portName> | -port <portName>]
#------------------------------------------------------------------------
# Insert a probe to the design and connect it to an output port. The output
# should not exist and is created by the command
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::insert_buffer::insert_clock_probe {args} {
  # Summary : Insert a probe to connect an output leaf clock pin to an output port. The output should not exist and is created by the command

  # Argument Usage:
  # -pin : Output leaf clock pin
  # -port : Output port name to be created
  # -diff_port : Output diff port name to be created
  # [-iostandard <arg>] : IOSTANDARD for created port(s)
  # [-schematic] : Display schematic of inserted probe

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  set error 0
  set help 0
  set pinName {}
  set portName {}
  set diffPort 0
  set iostandard {}
  set showSchematic 0
  if {[llength $args] == 0} {
    set help 1
  }
  while {[llength $args]} {
    set name [lshift args]
    switch -exact -- $name {
      -pin -
      -pin {
           set pinName [lflatten [lshift args]]
      }
      -port -
      -port {
           set portName [lshift args]
      }
      -diff_port -
      -diff_port {
           set portName [lshift args]
           set diffPort 1
      }
      -iostandard -
      -iostandard {
           set iostandard [lshift args]
      }
      -s -
      -schematic {
           set showSchematic 1
      }
      -h -
      -help -
      -u -
      -usage {
           set help 1
      }
      default {
            if {[string match "-*" $name]} {
              puts " -E- option '$name' is not a valid option."
              incr error
            } else {
              puts " -E- option '$name' is not a valid option."
              incr error
            }
      }
    }
  }

  if {$help} {
    puts [format {
  Usage: insert_clock_probe
              [-pin <pinName>]            - Output leaf clock pin
              [-port <portName>]          - Output port name to be created
              [-diff_port <portName>]     - Output diff port name to be created
              [-iostandard <iostandard>]  - IOSTANDARD for created port(s)
              [-schematic]                - Display schematic of inserted probe
              [-usage|-u]                 - This help message

  Description: Add clock probe to the design and connect the probe to an output port

    The pin to be probed should be an output clock pin, typically a BUFG output pin.
    The probed pin is connected to the output port through an ODDR->OBUF circuitry.
    The output port is created by the command and cannot exist before. The ODDR and OBUF
    are created as well and instanciated at the top-level.
    
    If -diff_port is used instead of -port then a differential port is created and
    driven through a OBUFDS.

  Example:
     ::xilinx::designutils::insert_clock_probe -pin bufg/O -port probe -iostandard HSTL
     ::xilinx::designutils::insert_clock_probe -pin bufg/O -diff_port probe -iostandard LVDS
} ]
    # HELP -->
    return -code ok
  }

  if {$pinName == {}} {
    puts " -E- use -pin to define an output leaf pin"
    incr error
  } else {
    set pin [get_pins -quiet $pinName -filter {IS_LEAF && (DIRECTION == OUT)}]
    switch [llength $pin] {
      0 {
        puts " -E- pin '$pinName' does not exists or is not an output leaf pin"
        incr error
      }
      1 {
        # OK
      }
      default {
        puts " -E- pin '$pinName' matches multiple output leaf pins"
        incr error
      }
    }
  }

  if {$portName == {}} {
    puts " -E- use -port/-diff-port to define an output port"
    incr error
  } else {
    set port [get_ports -quiet $portName]
    if {$port != {}} {
      puts " -E- port '$portName' already exists"
      incr error
    }
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  # Create port(s)
  # --------------
  if {$diffPort} {
    create_port -direction OUT ${portName}_p
    create_port -direction OUT ${portName}_n
    make_diff_pair_ports ${portName}_p ${portName}_n
  } else {
    create_port -direction OUT $portName
  }

  # Create ODDR cell under top level
  # --------------------------------
  set oddrCellName [genUniqueName oddr_probe]
  set oddrCellObj [createCell $oddrCellName ODDR]
  # Set ODDR properties
  set_property DDR_CLK_EDGE SAME_EDGE $oddrCellObj
  # Connect tied pins
  pinTieHigh [get_pins -quiet [list $oddrCellObj/D1 $oddrCellObj/CE] ]
  pinTieLow [get_pins -quiet $oddrCellObj/D2]

  # Connect PROBED PIN -> NET -> ODDR
  connect_net -verbose -hier -net [get_nets -quiet -of [get_pins -quiet $pinName]] -obj [get_pins -quiet $oddrCellObj/C]

  # Create OBUF/OBUFDS
  # ------------------
  if {$diffPort} {
    set obufCellName [genUniqueName obuf_probe]
    set obufCellObj [createCell $obufCellName OBUFDS]
  } else {
    set obufCellName [genUniqueName obuf_probe]
    set obufCellObj [createCell $obufCellName OBUF]
  }

  # Connect ODDR -> OBUF/OBUFDS
  # ---------------------------
  # Creates nets
  set oddrNetName [genUniqueName ${oddrCellName}_net]
  set oddrNetObj [createNet $oddrNetName]
  # Connect ODDR -> NET -> OBUF
  connect_net -verbose -hier -net $oddrNetObj -obj [list [get_pins -quiet $oddrCellObj/Q] [get_pins -quiet $obufCellObj/I] ]

  # Connect OBUF/OBUFDS -> PORT
  # ---------------------------
  if {$diffPort} {
    # Creates nets
    set obufNetName_N [genUniqueName ${obufCellName}_n_net]
    set obufNetName_P [genUniqueName ${obufCellName}_p_net]
    set obufNetObj_N [createNet $obufNetName_N]
    set obufNetObj_P [createNet $obufNetName_P]
    # Connect OBUF -> NET -> PORTS
    connect_net -verbose -hier -net $obufNetObj_P -obj [list [get_pins -quiet $obufCellObj/O] [get_ports -quiet ${portName}_p] ]
    connect_net -verbose -hier -net $obufNetObj_N -obj [list [get_pins -quiet $obufCellObj/OB] [get_ports -quiet ${portName}_n] ]
    # Set IOSTANDARD
    if {$iostandard == {}} { set iostandard LVDS }
    set_property -quiet IOSTANDARD $iostandard [get_ports -quiet ${portName}_p]
    set_property -quiet IOSTANDARD $iostandard [get_ports -quiet ${portName}_n]
  } else {
    # Creates net
    set obufNetName [genUniqueName ${obufCellName}_net]
    set obufNetObj [createNet $obufNetName]
    # Connect OBUF -> NET -> PORT
    connect_net -verbose -hier -net $obufNetObj -obj [list [get_pins -quiet $obufCellObj/O] [get_ports -quiet $portName] ]
    # Set IOSTANDARD
    if {$iostandard == {}} { set iostandard HSTL }
    set_property -quiet IOSTANDARD $iostandard [get_ports -quiet $portName]
  }

  puts " The following cells/ports have been created:"
  puts "       ODDR   : $oddrCellObj"
  if {$diffPort} {
    puts "       OBUFDS : $obufCellObj"
    puts "       PORTs  : ${portName}_p (IOSTANDARD = [get_property -quiet IOSTANDARD [get_ports -quiet ${portName}_p] ])"
    puts "              : ${portName}_n (IOSTANDARD = [get_property -quiet IOSTANDARD [get_ports -quiet ${portName}_n] ])"
  } else {
    puts "       OBUF   : $obufCellObj"
    puts "       PORT   : $portName (IOSTANDARD = [get_property -quiet IOSTANDARD [get_ports -quiet $portName] ])"
  }

  if {$showSchematic} {
    if {$diffPort} {
      set objToShow [list \
                      [get_pins -quiet $pinName] \
                      [get_nets -quiet -of [get_pins -quiet $pinName]] \
                      $oddrCellObj \
                      $oddrNetObj \
                      $obufCellObj \
                      $obufNetObj_N \
                      $obufNetObj_P \
                      [get_ports -quiet ${portName}_p] \
                      [get_ports -quiet ${portName}_n] \
                  ]
      set objToRemove [filter [get_cells -quiet -of [all_fanout [get_pins -quiet $pinName] -flat -endpoints_only]] "NAME !~ $oddrCellObj"]
      show_schematic -name $pinName -regenerate $objToShow
      show_schematic -name $pinName -regenerate -remove $objToRemove
      highlight_objects $objToShow -color blue
    } else {
      set objToShow [list \
                      [get_pins -quiet $pinName] \
                      [get_nets -quiet -of [get_pins -quiet $pinName]] \
                      $oddrCellObj \
                      $oddrNetObj \
                      $obufCellObj \
                      $obufNetObj \
                      [get_ports -quiet $portName] \
                  ]
      set objToRemove [filter [get_cells -quiet -of [all_fanout [get_pins -quiet $pinName] -flat -endpoints_only]] "NAME !~ $oddrCellObj"]
      show_schematic -name $pinName -regenerate -add $objToShow
      show_schematic -name $pinName -regenerate -remove $objToRemove
      highlight_objects $objToShow -color blue
    }
  }

  return -code ok
}

proc ::tclapp::xilinx::designutils::insert_buffer::rename_net {args} {
  # Summary : rename a net

  # Argument Usage:
  # -net <arg>: Net name to rename (full hierarchical name)
  # -name <arg>: New local net name

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug

  set netName {}
  set localName {}
  set error 0
  set help 0
  if {[llength $args] == 0} {
    set help 1
  }
  while {[llength $args]} {
    set name [lshift args]
    switch -exact -- $name {
      -net {
           set netName [lflatten [lshift args]]
      }
      -name {
           set localName [lflatten [lshift args]]
      }
      -h -
      -help -
      -u -
      -usage {
           set help 1
      }
      default {
            if {[string match "-*" $name]} {
              puts " -E- option '$name' is not a valid option."
              incr error
            } else {
              puts " -E- option '$name' is not a valid option."
              incr error
            }
      }
    }
  }

  if {$help} {
    puts [format {
  Usage: rename_net
              [-net <netName>]            - Net name
              [-name <localNetName>]      - New local net name
              [-usage|-u]                 - This help message

  Description: Rename a local net name

  Example:
     ::xilinx::designutils::rename_net -net bufg_O_net -name newlocalname
     ::xilinx::designutils::rename_net -net bufg_O_net -name bufg_clk
} ]
    # HELP -->
    return -code ok
  }

  if {$netName == {}} {
    puts " -E- no net specified"
    incr error
  } else {
    set net [get_nets -quiet $netName]
    switch [llength $net] {
      0 {
        puts " -E- net '$netName' does not exists"
        incr error
      }
      1 {
        # OK
      }
      default {
        puts " -E- net '$netName' matches multiple nets"
        incr error
      }
    }
  }

  if {$localName == {}} {
    puts " -E- no new local net name specified"
    incr error
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  if {[checkInternalMacro $net]} {
  	puts " -E- net '$netName' is internal to a macro"
   	incr error
  }
  if {$error} {
  	puts " Some error(s) occured. Cannot continue"
  	return [list]
  }

  set hierSep [get_hierarchy_separator]
  set parentName [get_property -quiet PARENT_CELL $net]
  # Uniquify the local net name
  if {$parentName != {}} {
    set localName [genUniqueName ${parentName}${hierSep}${localName}]
  } else {
    set localName [genUniqueName ${localName}]
  }
  set newNet [createNet $localName $parentName]
  # Get the leaf or hierarchical pins connected to the segment of the net
  set driverPin [getNetSegmentDriverPins $net]
  set loadPins [getNetSegmentLoadPins $net]

  # Disconnect current net from driver and load pins
  disconnect_net -verbose -prune -net $net -obj [concat $driverPin $loadPins]

  # Connect new net to driver and load pins
  connect_net -verbose -hier -net $newNet -obj [concat $driverPin $loadPins]

  return $newNet
}

###########################################################################
###########################################################################
###########################################################################
###########################################################################
##
## HELPER PROCS
##
###########################################################################
###########################################################################
###########################################################################
###########################################################################

proc ::tclapp::xilinx::designutils::insert_buffer::lflatten {data} {
  # Summary :
  # Argument Usage:
  # Return Value:

  while { $data != [set data [join $data]] } { }
  return $data
}

proc ::tclapp::xilinx::designutils::insert_buffer::lshift {inputlist} {
  # Summary :
  # Argument Usage:
  # Return Value:

  upvar $inputlist argv
  set arg  [lindex $argv 0]
  set argv [lrange $argv 1 end]
  return $arg
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
  # cellName : cell name (always from the top-level)
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

proc ::tclapp::xilinx::designutils::insert_buffer::insertBufferOnPin {pin {bufferType BUFG}} {
  # Summary : insert a buffer or any 2-pins cell on a leaf pin

  # Argument Usage:
  # pin : Leaf pin to insert buffer on. After insertion, the driver of the net is connected to the input of the inserted cell
  # [bufferType = BUFG] : Type of 2-pins cell to insert

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
  if {![isValidBuffer $bufferType]} {
    error " error - $bufferType is not a valid buffer type"
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

  # Abort the buffer insertion if there is a DONT_TOUCH on any of the net segments
  set error 0
  if {[checkDontTouchOnHierNets $insertionPin]} {
  	puts " ERROR - found 1 or more net segment(s) with DONT_TOUCH attribute"
   	incr error
  }
  if {[checkInternalMacro $insertionPin]} {
  	puts " ERROR - pin '$insertionPin' is internal to a macro"
   	incr error
  }
  if {$error} {
  	puts " Some error(s) occured. Buffer insertion failed on pin '$insertionPin'"
  	return [list]
  }

  set pinClass [string toupper [get_property -quiet CLASS $insertionPin]]
  set pinDir [string toupper [get_property -quiet DIRECTION $insertionPin]]
  set net [get_nets -quiet -of $insertionPin]

  # Generate the buffer name based on the net name connected to the pin
  set bufCellName [genUniqueName ${net}_${bufferType}]
  set parentName [get_property -quiet PARENT_CELL $net]
  set bufCell [createCell $bufCellName $bufferType $parentName]
  set bufInPin [getCellIPin $bufCell]
  set bufOutPin [getCellOPin $bufCell]

  # Generate the new net name
  set bufNetName [genUniqueName ${bufCellName}_net]
  set parentName [get_property -quiet PARENT_CELL $net]
  set bufNet [createNet $bufNetName $parentName]

  if {$debug} { puts " DEBUG: pin direction: [get_property -quiet DIRECTION $insertionPin]" }
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

  puts " Inserted $bufferType to pin $pin"
  return $bufCell
}

proc ::tclapp::xilinx::designutils::insert_buffer::insertBufferOnNet {net {bufferType BUFG}} {
  # Summary : insert a buffer or any 2-pins cell on a net

  # Argument Usage:
  # net : Net to insert buffer on. After insertion, the driver of the net is connected to the input of the inserted cell
  # [bufferType = BUFG] : Type of 2-pins cell to insert

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
  if {![isValidBuffer $bufferType]} {
    error " error - $bufferType is not a valid buffer type"
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

  # Abort the buffer insertion if there is a DONT_TOUCH on any of the net segments
  set error 0
  if {[checkDontTouchOnHierNets $bufOutNet]} {
  	puts " ERROR - found 1 or more net segment(s) with DONT_TOUCH attribute"
   	incr error
  }
  if {[checkInternalMacro $net]} {
  	puts " ERROR - net '$net' is internal to a macro"
   	incr error
  }
  if {$error} {
  	puts " Some error(s) occured. Buffer insertion failed on net '$bufOutNet'"
  	return [list]
  }

  # Get the closest hierarchical or leaf pin driving the net segment
  set bufSrcPin [getNetSegmentDriverPins $bufOutNet]
  if {$debug>1} { puts " DEBUG: bufSrcPin: $bufSrcPin" }

  # Only support nets with a single driver
  if {[llength $bufSrcPin] > 1} {
    error " error - net ($bufOutNet) has [llength $bufSrcPin] drivers ($bufSrcPin). Nets with multiple driver pins are not supported"
  }

  # Generate the buffer name
  set bufCellName [genUniqueName ${bufOutNet}_${bufferType}]
  set parentName [get_property -quiet PARENT_CELL $bufOutNet]
  set bufCell [createCell $bufCellName $bufferType $parentName]
  set bufInPin [getCellIPin $bufCell]
  set bufOutPin [getCellOPin $bufCell]

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

  puts " Inserted $bufferType to drive net $net"
  return $bufCell
}

proc ::tclapp::xilinx::designutils::insert_buffer::isValidBuffer {bufferType} {
  # Summary : check if bufferType is a valid buffer

  # Argument Usage:
  # name :

  # Return Value:
  # 1 if valid buffer, 0 otherwise. Return TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug
  set bufferType [string toupper $bufferType]
  set bufCellRef [get_lib_cells -quiet [get_libs]/$bufferType]
  if {$bufCellRef == {}} {
    error " error - cannot find cell type $bufferType"
  }
  if {[get_property -quiet NUM_PINS $bufCellRef] == 2} {
    return 1
  }
  # If the lib cell has more than 2 pins, there can still some cases when
  # the lib cell can be used as a buffer. This is ok when the lib cell has
  # only 1 input pin which is not a control pin.
  #   Property     Type    Read-only  Visible  Value
  #   CLASS        string  true       true     lib_pin
  #   DIRECTION    string  true       true     input
  #   FUNCTION     string  true       true
  #   IS_CLEAR     bool    true       true     0
  #   IS_CLOCK     bool    true       true     1
  #   IS_DATA      bool    true       true     0
  #   IS_ENABLE    bool    true       true     0
  #   IS_SETRESET  bool    true       true     0
  # List of input lib cell pins that are not a control pin
  set ipins [get_lib_pins -quiet -of $bufCellRef -filter {!IS_CLEAR && !IS_ENABLE && !IS_SETRESET && (DIRECTION == input)}]
  # List of input lib cell pins that are a control pin
  set cepins [get_lib_pins -quiet -of $bufCellRef -filter {(IS_CLEAR || IS_ENABLE || IS_SETRESET) && (DIRECTION == input)}]
  # List of output lib cell pins
  set opins [get_lib_pins -quiet -of $bufCellRef -filter {DIRECTION == output}]
  # If the lib cell has only 1 ipins, then it is considered being a valid buffer to insert
  if {$debug>1} {
    puts " DEBUG: isValidBuffer"
    puts " DEBUG:   bufferType: $bufferType"
    puts " DEBUG:        ipins: $ipins"
    puts " DEBUG:        opins: $opins"
    puts " DEBUG:       cepins: $cepins"
  }
  if {[llength $ipins] == 1} {
    return 1
  }
  return 0
}

proc ::tclapp::xilinx::designutils::insert_buffer::getCellOPin {cellname} {
  # Summary : return the list of output pins

  # Argument Usage:
  # cell : cell

  # Return Value:
  # list of output pins or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  set cell [get_cells -quiet $cellname]
  set opins [get_pins -quiet -of $cell -filter {DIRECTION == OUT}]
  return $opins
}

proc ::tclapp::xilinx::designutils::insert_buffer::getCellIPin {cellname} {
  # Summary : return the list of input pins that are not control pins

  # Argument Usage:
  # cell : cell

  # Return Value:
  # list of input pins that are not control pins or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  set cell [get_cells -quiet $cellname]
  set ipins [get_pins -quiet -of $cell -filter {!IS_CLEAR && !IS_ENABLE && !IS_SETRESET && !IS_PRESET && !IS_RESET && (DIRECTION == IN)}]
  return $ipins
}

proc ::tclapp::xilinx::designutils::insert_buffer::getCellCEPin {cellname} {
  # Summary : return the list of input pins that are control pins

  # Argument Usage:
  # cell : cell

  # Return Value:
  # list of input pins that are control pins or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  set cell [get_cells -quiet $cellname]
  set cepins [get_pins -quiet -of $cell -filter {(IS_CLEAR || IS_ENABLE || IS_SETRESET || IS_PRESET || IS_RESET) && (DIRECTION == IN)}]
  return $cepins
}

proc ::tclapp::xilinx::designutils::insert_buffer::getPinOrPort {name} {
  # Summary : insert a buffer or any 2-pins cell on a net

  # Argument Usage:
  # name :

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  set pins [get_pins -quiet $name]
  if {$pins != {}} { return $pins }
  set ports [get_ports -quiet $name]
  return $ports
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
  # cellName : cell name (always from the top-level)
  # refName : cell ref name (always frm the top-level)
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
  # Summary : return the driver pin/port of this net segment

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
    # Since the driver leaf pin or port is connected on this net segment, it is easy to get it
    set bufSrcPin [get_pins -quiet -leaf -of $net -filter {DIRECTION == OUT}]
    if {$bufSrcPin == {}} {
      set bufSrcPin [get_ports -quiet -of $net -filter {DIRECTION == IN}]
    }
  } else {
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

  set leafPins [get_pins -quiet [all_fanout -quiet -from $net -level 1 -pin_levels 1 -trace_arcs all] -filter {IS_LEAF && DIRECTION==IN}]
  set leafPorts [get_ports -quiet [all_fanout -quiet -from $net -level 1 -pin_levels 1 -trace_arcs all] -filter {DIRECTION==OUT}]
  set hierPins [get_pins -quiet [all_fanout -quiet -from $net -level 1 -pin_levels 1 -trace_arcs all] -filter {!IS_LEAF}]

#   set allPins [concat $leafPins $leafPorts $hierPins]
  set allPins [list]
  foreach pin $leafPins { lappend allPins $pin }
  foreach pin $hierPins { lappend allPins $pin }
  foreach pin $leafPorts { lappend allPins $pin }
  if {$debug>1} {
  	puts " DEBUG: leafPins ([llength $leafPins]): $leafPins"
  	puts " DEBUG: hierPins ([llength $hierPins]): $hierPins"
  	puts " DEBUG: leafPorts ([llength $leafPorts]): $leafPorts"
  	puts " DEBUG: allPins ([llength $allPins]): $allPins"
  }
  return $allPins
}

proc ::tclapp::xilinx::designutils::insert_buffer::disconnectPins {pins args} {
  # Summary : disconnect a pin or port from the net connected to it

  # Argument Usage:
  # pins : Pin or port name(s)

  # Return Value:
  # 0 if succeeded
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug
  set defaults [list -prune 1 -promote 0 -safe 0]
  array set options $defaults
  array set options $args
  if {$pins == {}} {
    error " error - no pin or port specified"
  }

  if {$options(-promote)} {
    set pins [promoteInternalMacroPins [getPinOrPort $pins] ]
  } else {
    set pins [getPinOrPort $pins]
  }
  if {![llength $pins]} {
    error " error - cannot find pin or port"
  }

  set error 0
  if {$options(-safe)} {
    if {[checkDontTouchOnHierCells $pins]} {
    	puts " ERROR - found 1 or more parent cell(s) with DONT_TOUCH attribute"
    	incr error
    }
  }
  if {[checkDontTouchOnHierNets $pins]} {
   	puts " ERROR - found 1 or more net segment(s) with DONT_TOUCH attribute"
  	incr error
  }
  if {$error} {
  	puts " Some error(s) occured. Cannot continue."
  	return 1
  }

  if {$options(-prune)} {
    if {$debug>1} { puts " DEBUG: disconnecting [llength $pins] pin(s) (with pruning)" }
    disconnect_net -verbose -prune -obj $pins
  } else {
    if {$debug>1} { puts " DEBUG: disconnecting [llength $pins] pin(s) (no pruning)" }
    disconnect_net -verbose -obj $pins
  }
  return 0
}

proc ::tclapp::xilinx::designutils::insert_buffer::pinTieHigh {pins args} {
  # Summary : tie pin to VCC

  # Argument Usage:
  # pins : Pin name(s)

  # Return Value:
  # 0 if succeeded
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug
  set defaults [list -prune 1 -promote 0 -safe 0]
  array set options $defaults
  array set options $args
  if {$pins == {}} {
    error " error - no pin or port specified"
  }

  if {$options(-promote)} {
    set pins [promoteInternalMacroPins [getPinOrPort $pins] ]
  } else {
    set pins [getPinOrPort $pins]
  }
  if {![llength $pins]} {
    error " error - cannot find pin or port"
  }

  set error 0
  if {$options(-safe)} {
    if {[checkDontTouchOnHierCells $pins]} {
    	puts " ERROR - found 1 or more parent cell(s) with DONT_TOUCH attribute"
    	incr error
    }
  }
  if {[checkDontTouchOnHierNets $pins]} {
   	puts " ERROR - found 1 or more net segment(s) with DONT_TOUCH attribute"
  	incr error
  }
  if {$error} {
  	puts " Some error(s) occured. Cannot continue."
  	return 1
  }

  # First, disconnect pins
  if {$debug>1} { puts " DEBUG: disconnecting [llength $pins] pin(s)/port(s)" }
  # If requested, internal pins have already been promoted
  disconnectPins $pins -prune $options(-prune) -promote 0
#   disconnectPins $pins -prune $options(-prune) -promote $options(-promote)

  catch {unset arConnect}
  foreach pin $pins {
    set parentName [get_property -quiet PARENT [get_property -quiet PARENT_CELL $pin]]
    set net [getOrCreateVCCNet $parentName]
    if {$debug>1} { puts " DEBUG: connect_net -hier -net $net -obj $pin" }
#     connect_net -hier -net $net -obj $pin
    if {[info exists arConnect($net)]} {
      lappend arConnect($net) $pin
    } else {
      set arConnect($net) $pin
    }
  }
  connect_net -hier -net_object_list [array get arConnect]
  return 0
}

proc ::tclapp::xilinx::designutils::insert_buffer::pinTieLow {pins args} {
  # Summary : tie pin to GND

  # Argument Usage:
  # pins : Pin name(s)

  # Return Value:
  # 0 if succeeded
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug
  set defaults [list -prune 1 -promote 0 -safe 0]
  array set options $defaults
  array set options $args
  if {$pins == {}} {
    error " error - no pin or port specified"
  }

  if {$options(-promote)} {
    set pins [promoteInternalMacroPins [getPinOrPort $pins] ]
  } else {
    set pins [getPinOrPort $pins]
  }
  if {![llength $pins]} {
    error " error - cannot find pin or port"
  }

  set error 0
  if {$options(-safe)} {
    if {[checkDontTouchOnHierCells $pins]} {
    	puts " ERROR - found 1 or more parent cell(s) with DONT_TOUCH attribute"
    	incr error
    }
  }
  if {[checkDontTouchOnHierNets $pins]} {
   	puts " ERROR - found 1 or more net segment(s) with DONT_TOUCH attribute"
  	incr error
  }
  if {$error} {
  	puts " Some error(s) occured. Cannot continue."
  	return 1
  }

  # First, disconnect pins
  if {$debug>1} { puts " DEBUG: disconnecting [llength $pins] pin(s)/port(s)" }
  # If requested, internal pins have already been promoted
  disconnectPins $pins -prune $options(-prune) -promote 0
#   disconnectPins $pins -prune $options(-prune) -promote $options(-promote)

  catch {unset arConnect}
  foreach pin $pins {
    set parentName [get_property -quiet PARENT [get_property -quiet PARENT_CELL $pin]]
    set net [getOrCreateGNDNet $parentName]
    if {$debug>1} { puts " DEBUG: connect_net -hier -net $net -obj $pin" }
#     connect_net -hier -net $net -obj $pin
    if {[info exists arConnect($net)]} {
      lappend arConnect($net) $pin
    } else {
      set arConnect($net) $pin
    }
  }
  connect_net -hier -net_object_list [array get arConnect]
  return 0
}

proc ::tclapp::xilinx::designutils::insert_buffer::promoteInternalMacroPins {pins} {
  # Summary : promote INTERNAL leaf pins to macro pins

  # Argument Usage:
  # pins : pin name(s)

  # Return Value:
  # 0 if succeeded
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug

  if {![llength $pins]} {
    error " error - no pin specified"
  }

  set macroPins [list]
  set leafPins [list]
  foreach pin $pins {
    set prop [get_property -quiet PRIMITIVE_LEVEL [get_cells -quiet -of $pin]]
  	if {$prop == {INTERNAL}} {
  		lappend macroPins $pin
  	} else {
  		lappend leafPins $pin
  	}
  }
  if {$debug} { puts " DEBUG: found [llength $leafPins] non-internal leaf pin(s)" }
  if {$debug} { puts " DEBUG: found [llength $macroPins] internal macro pin(s)" }
  if {$macroPins != [list]} {
    set legalPins [get_pins -quiet -filter {!IS_LEAF} -of [get_nets -quiet -of $macroPins]]
    if {$debug} { puts " DEBUG: found [llength $legalPins] legal macro pin(s)" }
    set leafPins [concat $leafPins $legalPins]
  }
  set result [list]
  foreach pin [get_pins -quiet $leafPins] {
  	lappend result $pin
  }
  foreach port [get_ports -quiet $leafPins] {
  	lappend result $port
  }
  return $result
}

proc ::tclapp::xilinx::designutils::insert_buffer::checkDontTouchOnHierNets {names} {
  # Summary : check if net segments connected to the pins have a DONT_TOUCH attribute

  # Argument Usage:
  # names : pin/port/net name(s)

  # Return Value:
  # 0 if succeeded
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug
  set error 0

  if {![llength $names]} {
    error " error - no pin/port specified"
  }

  set pins [list]
  set pins [get_pins -quiet $names]
  if {[llength $pins]} {
    set dontTouch [lsort -unique [get_property -quiet DONT_TOUCH [get_nets -quiet -segments -of $pins]]]
    if {[lsearch $dontTouch {1}] != -1} {
    	if {$debug} {
      	puts " ERROR - found nets with DONT_TOUCH attribute on 1 or multiple upstream or downstream nets(s)"
      	foreach net [filter -quiet [get_nets -quiet -segments -of $pins] {DONT_TOUCH}] {
      		puts "         $net (DONT_TOUCH)"
      	}
    	}
    	incr error
    }
  }

  set ports [list]
#   set ports [get_ports -quiet $names]
  if {[llength $ports]} {
    set dontTouch [lsort -unique [get_property -quiet DONT_TOUCH [get_nets -quiet -segments -of $ports]]]
    if {[lsearch $dontTouch {1}] != -1} {
    	if {$debug} {
      	puts " ERROR - found nets with DONT_TOUCH attribute on 1 or multiple upstream or downstream nets(s)"
      	foreach net [filter -quiet [get_nets -quiet -segments -of $ports] {DONT_TOUCH}] {
      		puts "         $net (DONT_TOUCH)"
      	}
    	}
    	incr error
    }
  }

  set nets [list]
  set nets [get_nets -quiet $names]
  if {[llength $nets]} {
    set dontTouch [lsort -unique [get_property -quiet DONT_TOUCH [get_nets -quiet -segments $nets]]]
    if {[lsearch $dontTouch {1}] != -1} {
    	if {$debug} {
      	puts " ERROR - found nets with DONT_TOUCH attribute on 1 or multiple upstream or downstream nets(s)"
      	foreach net [filter -quiet [get_nets -quiet -segments $nets] {DONT_TOUCH}] {
      		puts "         $net (DONT_TOUCH)"
      	}
    	}
    	incr error
    }
  }

  if {$error} { return 1 }
  return 0
}

proc ::tclapp::xilinx::designutils::insert_buffer::checkDontTouchOnHierCells {pins} {
  # Summary : check if hierarchical cells parent of the pins have a DONT_TOUCH attribute

  # Argument Usage:
  # pins : pin name(s)

  # Return Value:
  # 0 if succeeded
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug

  if {![llength $pins]} {
    error " error - no pin specified"
  }

#   set allParents [list]
#   set parents [get_property -quiet PARENT [get_cells -quiet -of $pins]]
#   while {1} {
#   	set allParents [concat $allParents $parents]
#   	set parents [get_cells -quiet [get_property -quiet PARENT $parents]]
#   	if {$parents == {}} {
#   		break
#   	}
#   }
#   set allParents [get_cells -quiet [lsort -unique $allParents]]

  set allParents [getHierParents $pins]
#   set dtDebugCore [filter -quiet $allParents {IS_DEBUG_CORE && DONT_TOUCH}]

  set dontTouch [lsort -unique [get_property -quiet DONT_TOUCH $allParents]]
  if {[lsearch $dontTouch {1}] != -1} {
  	if {$debug} {
    	puts " ERROR - found hierarchical cells with DONT_TOUCH attribute on 1 or multiple pin(s)"
    	foreach cell [filter -quiet $allParents {DONT_TOUCH}] {
    		puts "         $cell (DONT_TOUCH)"
    	}
    }
  	return 1
  }

  return 0
}

proc ::tclapp::xilinx::designutils::insert_buffer::checkInternalMacro {names} {
  # Summary : check if any of the pins or nets belong to a macro cell

  # Argument Usage:
  # pins : pin name(s)

  # Return Value:
  # 0 if succeeded
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug
  set result 0

  set pins [list]
  set pins [get_pins -quiet $names]
  if {[llength $pins]} {
    set props [lsort -unique [get_property -quiet PRIMITIVE_LEVEL [get_cells -quiet -of $pins]]]
    if {[lsearch $props {INTERNAL}] != -1} {
    	if {$debug} {
      	puts " ERROR - found parent MACRO for 1 or multiple pin(s)"
      	foreach cell [filter -quiet [get_cells -quiet -of $pins] {PRIMITIVE_LEVEL == INTERNAL}] {
      		puts "         $cell (Macro)"
      	}
      }
    	set result 1
    }
  }
  
  set nets [list]
  set nets [get_nets -quiet $names]
  if {[llength $nets]} {
    set props [lsort -unique [get_property -quiet PRIMITIVE_LEVEL [get_property -quiet PARENT_CELL $nets]]]
    if {[lsearch $props {MACRO}] != -1} {
    	if {$debug} {
      	puts " ERROR - found parent MACRO for 1 or multiple net(s)"
      	foreach cell [filter -quiet [get_property -quiet PARENT_CELL $nets] {PRIMITIVE_LEVEL == MACRO}] {
      		puts "         $cell (Macro)"
      	}
      }
    	set result 1
    }
  }
  
  return $result
}

proc ::tclapp::xilinx::designutils::insert_buffer::getHierParents {pins} {
  # Summary : get all hierarchical parents of a list of pins

  # Argument Usage:
  # pins : pin name(s)

  # Return Value:
  # 0 if succeeded
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug

  if {![llength $pins]} {
    error " error - no pin specified"
  }

  set allParents [list]
  set parents [get_cells -quiet [lsort -unique [get_property -quiet PARENT [get_cells -quiet -of $pins]]]]
  while {1} {
  	set allParents [concat $allParents $parents]
  	set parents [get_cells -quiet [lsort -unique [get_property -quiet PARENT $parents]]]
  	if {$parents == {}} {
  		break
  	}
  }
  set allParents [get_cells -quiet [lsort -unique $allParents]]
  return $allParents
}

proc ::tclapp::xilinx::designutils::insert_buffer::getOrCreateVCCNet {parent} {
  # Summary : get or create power net under parent level

  # Argument Usage:
  # parent : hierarchical module. Empty for top-level

  # Return Value:
  # 0 if succeeded
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug

  set hierSep [get_hierarchy_separator]
  if {$parent != {}} {
  	set cell [get_cells -quiet $parent]
  	if {$cell == {}} {
  		error " -E- Cell '$parent' is not a valid"
  	}
  	set powerCell [format {%s%sVCC} $parent $hierSep]
  } else {
  	set powerCell [format {VCC} $parent]
  }
  set powerCell [get_cells -quiet $powerCell]

  if {$powerCell == {}} {
  	# Power cell does not exist. Create it:
    if {$parent != {}} {
      if {$debug} { puts " DEBUG: Creating power net $parent/<const1>" }
    	create_cell -quiet -reference VCC $parent/VCC
      create_net -quiet $parent/<const1>
      connect_net -quiet -hier -net $parent/<const1> -obj [get_pins -quiet $parent/VCC/P]
      set powerNet [get_nets -quiet $parent/<const1>]
    } else {
      if {$debug} { puts " DEBUG: Creating power net <const1>" }
    	create_cell -quiet -reference VCC VCC
      create_net -quiet <const1>
      connect_net -quiet -hier -net <const1> -obj [get_pins -quiet VCC/P]
      set powerNet [get_nets -quiet <const1>]
    }
  } else {
    set powerNet [get_nets -quiet -of $powerCell]
  }
  return $powerNet
}

proc ::tclapp::xilinx::designutils::insert_buffer::getOrCreateGNDNet {parent} {
  # Summary : get or create ground net under parent level

  # Argument Usage:
  # parent : hierarchical module. Empty for top-level

  # Return Value:
  # 0 if succeeded
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug

  set hierSep [get_hierarchy_separator]
  if {$parent != {}} {
  	set cell [get_cells -quiet $parent]
  	if {$cell == {}} {
  		error " -E- Cell '$parent' is not a valid"
  	}
  	set groundCell [format {%s%sGND} $parent $hierSep]
  } else {
  	set groundCell [format {GND} $parent]
  }
  set groundCell [get_cells -quiet $groundCell]

  if {$groundCell == {}} {
  	# Ground cell does not exist. Create it:
    if {$parent != {}} {
      if {$debug} { puts " DEBUG: Creating ground net $parent/<const0>" }
    	create_cell -quiet -reference GND $parent/GND
      create_net -quiet $parent/<const0>
      connect_net -quiet -hier -net $parent/<const0> -obj [get_pins -quiet $parent/GND/G]
      set groundNet [get_nets -quiet $parent/<const0>]
    } else {
      if {$debug} { puts " DEBUG: Creating ground net <const0>" }
    	create_cell -quiet -reference GND GND
      create_net -quiet <const0>
      connect_net -quiet -hier -net <const0> -obj [get_pins -quiet GND/G]
      set groundNet [get_nets -quiet <const0>]
    }
  } else {
    set groundNet [get_nets -quiet -of $groundCell]
  }
  return $groundNet
}

#####################################
################ EOF ################
#####################################
