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
  # [-force]: Force buffer insertion when cells are placed

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
  # [-force]: Force probe insertion when cells are placed

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  return [uplevel [concat ::tclapp::xilinx::designutils::insert_buffer::insert_buffer $args]]
}

proc ::tclapp::xilinx::designutils::remove_buffer {args} {
  # Summary : Remove a buffer or any 2-pins cell

  # Argument Usage:
  # -cell <arg>: Buffer to be removed
  # [-force]: Force buffer removal when the connected cells are placed

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
  # [-force]: Force probe insertion when cells are placed

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
  variable maxNumberOfPlacedCells 250
  variable debug 0
#   variable debug 1
#   variable debug 2
  variable LOC
  variable PLACED
  variable PLACED_LOC_FIXED
  variable PLACED_BEL_FIXED
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
  set force 0
  set error 0
  set help 0
  if {[llength $args] == 0} {
    set help 1
  }
  while {[llength $args]} {
    set name [lshift args]
    switch -exact -- $name {
      -name -
      -net -
      -pin {
           set netOrPinName [lflatten [lshift args]]
      }
      -buffers -
      -buffers {
           set buffers [lshift args]
      }
      -force -
      -force {
           set force 1
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
              [-name <pinName|netName>]   - Pin or net name (equivalent to -pin/-net)
              [-buffers <cell(s)>]        - List of buffer Types
              [-force]                    - Force buffer(s) insertion when the connected cells are placed
              [-usage|-u]                 - This help message

  Description: Insert a chain of buffers or any 2-pins cells on a net or a pin

  It is recommended to use the command on an unplaced design.

  Example:
     insert_buffer_chain -pin bufg/O -buffers BUFG
     insert_buffer_chain -net bufg_O_net -buffers {BUFG BUGH} -force
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
    if {$force} {
      insert_buffer -net $netOrPinName -buffer $buffer -force
    } else {
      insert_buffer -net $netOrPinName -buffer $buffer
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
  set bufferType BUFG
  set force 0
  set error 0
  set help 0
  if {[llength $args] == 0} {
    set help 1
  }
  while {[llength $args]} {
    set name [lshift args]
    switch -exact -- $name {
      -name -
      -net -
      -pin {
           set netOrPinName [lflatten [lshift args]]
      }
      -buffer -
      -buffer {
           set bufferType [lshift args]
      }
      -force -
      -force {
           set force 1
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
              [-name <pinName|netName>]   - Pin or net name (equivalent to -pin/-net)
              [-buffer <cell>]            - Buffer Type
                                            Default: BUFG
              [-force]                    - Force buffer insertion when the connected cells are placed
              [-usage|-u]                 - This help message

  Description: Add buffer or any 2-pins cell on a net or a pin

  It is recommended to use the command on an unplaced design.

  Example:
     insert_buffer -pin bufg/O -buffer BUFG
     insert_buffer -net bufg_O_net
     insert_buffer -net bufg_O_net -force
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

  set nets [get_nets -quiet $netOrPinName]
  if {$nets != {}} {
    if {[llength $nets]>1} {
      # More than 1 net
#       error " error - more than 1 ([llength $nets]) net match $netOrPinName"
      puts " WARN - [llength $nets] nets matching $netOrPinName"
    }
    foreach net $nets {
      insertBufferOnNet $net $bufferType $force
    }
    return 0
  }

  set pins [get_pins -quiet $netOrPinName -filter {IS_LEAF}]
  if {$pins != {}} {
    if {[llength $pins]>1} {
      # More than 1 net
#       error " error - more than 1 ([llength $pins]) leaf pin match $netOrPinName"
      puts " WARN - [llength $pins] pins matching $netOrPinName"
    }
    foreach pin $pins {
      insertBufferOnPin $pin $bufferType $force
    }
    return 0
  }

  error " error - no net or leaf pin matches $netOrPinName"
}

proc ::tclapp::xilinx::designutils::insert_buffer::remove_buffer {args} {
  # Summary : Remove a buffer or any 2-pins cell

  # Argument Usage:
  # cell : Buffer to be removed

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug

  set cell {}
  set force 0
  set error 0
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
      -force -
      -force {
           set force 1
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
              [-force]                    - Force buffer removal when the connected cells are placed
              [-usage|-u]                 - This help message

  Description: Remove a buffer or any 2-pins cell

  It is recommended to use the command on an unplaced design.

  Example:
     remove_buffer -cell bufg
     remove_buffer -cell [get_selected_objects]
     remove_buffer -cell bufg -force
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
    if {$debug} { puts " DEBUG: unplacing cell $buffer ([get_property -quiet REF_NAME $buffer])" }
    # Need to unplace the buffer that needs to be deleted first. That will prevent
    # the buffer location from being saved inside unplaceConnectedCells since it
    # is going to be deleted
    unplace_cell $buffer

    # We first need to check that all the cells connected to the buffer are NOT placed.
    # Otherwise the connect_net command cannot work
    collectConnectedCells $buffer
    unplaceConnectedCells -force $force

    # Disconnect the to-be-deleted buffer control pins (if any)
    foreach pin $bufCEPin {
      if {$debug} { puts " DEBUG: disconnectPin $pin" }
      disconnectPin $pin
    }

#     if {$debug} { puts " DEBUG: disconnect_net -verbose -prune -net $bufInNet -obj $bufInPin" }
#     # Disconnect the to-be-deleted buffer input pin
#     disconnect_net -verbose -prune -net $bufInNet -obj $bufInPin

    if {$debug} { puts " DEBUG: disconnect_net -verbose -prune -net $bufOutNet -obj $bufOutPin" }
    # Disconnect the to-be-deleted buffer output pin
    disconnect_net -verbose -prune -net $bufOutNet -obj $bufOutPin
#     disconnect_net -verbose -net $bufOutNet -obj $bufOutPin

    # Reconnect all the loads of the to-be-deleted buffer to the driver pin
    if {$loadPins != {}} {
      if {$debug} { puts " DEBUG: disconnecting load pins: $loadPins" }
      foreach pin $loadPins { disconnectPin $pin }
      if {$debug} { puts " DEBUG: connect_net -verbose -hier -net $bufInNet -obj $loadPins" }
      connect_net -verbose -hier -net $bufInNet -obj $loadPins
    }
    if {$loadPorts != {}} {
      if {$debug} { puts " DEBUG: disconnecting load ports: $loadPorts" }
      foreach pin $loadPorts { disconnectPin $pin }
      if {$debug} { puts " DEBUG: connect_net -verbose -hier -net $bufInNet -obj $loadPorts" }
      connect_net -verbose -hier -net $bufInNet -obj $loadPorts
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

  if {$debug} { puts " DEBUG: restoreCellLoc" }
  # Restore cells LOC
  restoreCellLoc

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
  # port : Output port name to be created
  # diff_port : Output diff port name to be created
  # [-iostandard] : IOSTANDARD for created port(s)
  # [-schematic] : Display schematic of inserted probe
  # [-force]: Force probe insertion when cells are placed

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
  set force 0
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
      -force -
      -force {
           set force 1
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

  It is recommended to use the command on an unplaced design.

  Example:
     insert_clock_probe -pin bufg/O -port probe -iostandard HSTL
     insert_clock_probe -pin bufg/O -diff_port probe -iostandard LVDS
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

  # Make sure that the cell placement array is empty
  clearCellLoc

  # Unplace all the cells connected to the probed pin, otherwise the net connection cannot be done
  # This stage is done early in the process so that if it fails then no port/net/cell gets created
  collectConnectedCells [get_pins $pinName]
  unplaceConnectedCells -save 1 -force $force

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
  pinTieHigh [get_pins $oddrCellObj/D1]
  pinTieLow [get_pins $oddrCellObj/D2]
  pinTieHigh [get_pins $oddrCellObj/CE]

#   # Unplace all the cells connected to the probed pin, otherwise the net connection cannot be done
#   collectConnectedCells [get_pins $pinName]
#   unplaceConnectedCells -save 1 -force 1
  # Connect PROBED PIN -> NET -> ODDR
  connect_net -verbose -hier -net [get_nets -of [get_pins $pinName]] -obj [get_pins  $oddrCellObj/C]
  # Restore the cells placement
  restoreCellLoc

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
  connect_net -verbose -hier -net $oddrNetObj -obj [list [get_pins  $oddrCellObj/Q] [get_pins $obufCellObj/I] ]

  # Connect OBUF/OBUFDS -> PORT
  # ---------------------------
  if {$diffPort} {
    # Creates nets
    set obufNetName_N [genUniqueName ${obufCellName}_n_net]
    set obufNetName_P [genUniqueName ${obufCellName}_p_net]
    set obufNetObj_N [createNet $obufNetName_N]
    set obufNetObj_P [createNet $obufNetName_P]
    # Connect OBUF -> NET -> PORTS
    connect_net -verbose -hier -net $obufNetObj_P -obj [list [get_pins  $obufCellObj/O] [get_ports ${portName}_p] ]
    connect_net -verbose -hier -net $obufNetObj_N -obj [list [get_pins  $obufCellObj/OB] [get_ports ${portName}_n] ]
    # Set IOSTANDARD
    if {$iostandard == {}} { set iostandard LVDS }
    set_property -quiet IOSTANDARD $iostandard [get_ports ${portName}_p]
    set_property -quiet IOSTANDARD $iostandard [get_ports ${portName}_n]
  } else {
    # Creates net
    set obufNetName [genUniqueName ${obufCellName}_net]
    set obufNetObj [createNet $obufNetName]
    # Connect OBUF -> NET -> PORT
    connect_net -verbose -hier -net $obufNetObj -obj [list [get_pins  $obufCellObj/O] [get_ports $portName] ]
    # Set IOSTANDARD
    if {$iostandard == {}} { set iostandard HSTL }
    set_property -quiet IOSTANDARD $iostandard [get_ports $portName]
  }

  puts " The following cells/ports have been created:"
  puts "       ODDR   : $oddrCellObj"
  if {$diffPort} {
    puts "       OBUFDS : $obufCellObj"
    puts "       PORTs  : ${portName}_p (IOSTANDARD = [get_property -quiet IOSTANDARD [get_ports ${portName}_p] ])"
    puts "              : ${portName}_n (IOSTANDARD = [get_property -quiet IOSTANDARD [get_ports ${portName}_n] ])"
  } else {
    puts "       OBUF   : $obufCellObj"
    puts "       PORT   : $portName (IOSTANDARD = [get_property -quiet IOSTANDARD [get_ports $portName] ])"
  }

  if {$showSchematic} {
    if {$diffPort} {
      set objToShow [list \
                      [get_pins $pinName] \
                      [get_nets -of [get_pins $pinName]] \
                      $oddrCellObj \
                      $oddrNetObj \
                      $obufCellObj \
                      $obufNetObj_N \
                      $obufNetObj_P \
                      [get_ports ${portName}_p] \
                      [get_ports ${portName}_n] \
                  ]
      set objToRemove [filter [get_cells -of [all_fanout [get_pins $pinName] -flat -endpoints_only]] "NAME !~ $oddrCellObj"]
      show_schematic -name $pinName -regenerate $objToShow
      show_schematic -name $pinName -regenerate -remove $objToRemove
      highlight_objects $objToShow -color blue
    } else {
      set objToShow [list \
                      [get_pins $pinName] \
                      [get_nets -of [get_pins $pinName]] \
                      $oddrCellObj \
                      $oddrNetObj \
                      $obufCellObj \
                      $obufNetObj \
                      [get_ports $portName] \
                  ]
      set objToRemove [filter [get_cells -of [all_fanout [get_pins $pinName] -flat -endpoints_only]] "NAME !~ $oddrCellObj"]
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
  # [-force]: Force net renaming when cells are placed

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug

  set netName {}
  set localName {}
  set force 0
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
      -force -
      -force {
           set force 1
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
              [-force]                    - Force net renaming when the connected cells are placed
              [-usage|-u]                 - This help message

  Description: Rename a local net name

  It is recommended to use the command on an unplaced design.

  Example:
     rename_net -net bufg_O_net -name newlocalname
     rename_net -net bufg_O_net -name bufg_clk -force
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

  # Make sure that the cell placement array is empty
  clearCellLoc

  # Unplace all the cells connected to the probed pin, otherwise the net connection cannot be done
  # This stage is done early in the process so that if it fails then no new net gets created
  collectConnectedCells $net
  unplaceConnectedCells -save 1 -force $force

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
  
  # Restore the cells placement
  restoreCellLoc

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

proc ::tclapp::xilinx::designutils::insert_buffer::collectConnectedCells {name {save 1}} {
  # Summary : collect/gather all connected cells that are placed. All the connected cells
  # can be afterward forced to be unplaced

  # Argument Usage:
  # name : cell name or net name
  # save : if 1 then the cellplacement is internally saved so that it can be restored afterward

  # Return Value:
  # 0 if all the connected cells are unplaced. 1 otherwise
  # TCL_ERROR if failed

  # Categories: xilinxtclstore, designutils

  variable debug
  variable PLACED
  variable PLACED_LOC_FIXED
  variable PLACED_BEL_FIXED
  set cell [get_cells -quiet $name]
  set net [get_nets -quiet $name]
  set pin [get_pins -quiet $name -filter {IS_LEAF}]
  if {($cell == {}) && ($net == {}) && ($pin == {})} {
    error " error - cannot find a cell, a net or a leaf pin matching $name"
  }
  if {$cell != {}} {
    # This is a cell
    # Does the filter need to include PRIMITIVE_LEVEL!="INTERNAL" ?
    set placedLeafCells [get_cells -quiet -of \
                                 [get_pins -quiet -leaf -of [get_nets -quiet -of $cell]] -filter {IS_PRIMITIVE && (LOC!= "")} ]
  } elseif {$net != {}} {
    # This is a net
    # Does the filter need to include PRIMITIVE_LEVEL!="INTERNAL" ?
    set placedLeafCells [get_cells -quiet -of [get_pins -quiet -leaf -of $net] \
                     -filter {IS_PRIMITIVE && (LOC!= "")} ]
  } else {
    # This is a pin
    # Does the filter need to include PRIMITIVE_LEVEL!="INTERNAL" ?
    set placedLeafCells [get_cells -quiet -of [get_pins -quiet -leaf -of [get_nets -quiet -of $pin]] \
                     -filter {IS_PRIMITIVE && (LOC!= "")} ]
  }
  if {$save} {
    set PLACED $placedLeafCells
    set PLACED_LOC_FIXED [filter $placedLeafCells {IS_LOC_FIXED}]
    set PLACED_BEL_FIXED [filter $placedLeafCells {IS_BEL_FIXED}]
  }
  return [llength $placedLeafCells]
}

proc ::tclapp::xilinx::designutils::insert_buffer::unplaceConnectedCells {args} {
  # Summary : check that all attached cells are unplaced. All the connected cells
  # can be forced to be unplaced

  # Argument Usage:
  # [-force 0|1] : force cells with FIXED placement to be unplaced
  # [-save 0|1] : if 1 then the cellplacement is internally saved so that it can be restored afterward

  # Return Value:
  # 0 if all the connected cells are unplaced. 1 otherwise
  # TCL_ERROR if failed

  # Categories: xilinxtclstore, designutils

  variable debug
  variable LOC
  variable PLACED
  variable PLACED_LOC_FIXED
  variable PLACED_BEL_FIXED
  variable maxNumberOfPlacedCells

  # First assign default values...
  array set options {-save 1 -force 0}
  # ...then possibly override them with user choices
  array set options $args

  if {$PLACED == {}} {
    # OK, all connected cells already unplaced
    return 0
  }

  puts " WARN - [llength $PLACED] cell(s) are placed"

  if {[llength $PLACED] > $maxNumberOfPlacedCells} {
    # We have reached a hard limit. This limit is just to avoid runtime issue
    # when thousands are cells have to be unplaced/replaced
    error " ERROR - too many cells ([llength $PLACED]) are placed. To prevent runtime issues, the command should be run on an unplaced database"
  }

  if {$debug} {
    puts " DEBUG: [llength $PLACED] cell(s) are placed"
    puts " DEBUG: [llength $PLACED_LOC_FIXED] cell(s) have fixed LOC"
    puts " DEBUG: [llength $PLACED_BEL_FIXED] cell(s) have fixed BEL"
    foreach cell $PLACED_LOC_FIXED {
      puts " DEBUG: cell with fixed LOC: $cell"
    }
  }

  if {[llength $PLACED] && !$options(-force)} {
    error " ERROR - [llength $PLACED] cell(s) are placed. The command should be run on an unplaced database"
  }

  if {$options(-save)} {
    if {![info exists LOC]} { unset -nocomplain LOC }
    foreach cell $PLACED loc [get_property -quiet LOC $PLACED] bel [get_property -quiet BEL $PLACED] {
      # LOC: SLICE_X23Y125
      # BEL: SLICEL.B5LUT
      set LOC($cell) [list $loc $bel]
      if {$debug>1} {
        puts " DEBUG: cell $cell ([get_property -quiet REF_NAME $cell]) is placed (LOC: $loc / BEL:$bel)"
      }
    }
  }

  # Reset the IS_LOC_FIXED/IS_BEL_FIXED properties so that the cells can be unplaced
  set_property -quiet IS_BEL_FIXED 0 $PLACED_BEL_FIXED
  set_property -quiet IS_LOC_FIXED 0 $PLACED_LOC_FIXED
  if {$debug} {
    puts " DEBUG: unplacing [llength $PLACED] cells"
  }
  unplace_cell $PLACED

  return 0
}

proc ::tclapp::xilinx::designutils::insert_buffer::clearCellLoc {} {
  # Summary : clear the internal database that save the cells location

  # Argument Usage:

  # Return Value:
  # 0 or TCL_ERROR if failed

  # Categories: xilinxtclstore, designutils

  variable LOC
  variable PLACED
  variable PLACED_LOC_FIXED
  variable PLACED_BEL_FIXED
  catch {unset LOC}
  set PLACED [list]
  set PLACED_LOC_FIXED [list]
  set PLACED_BEL_FIXED [list]
  return 0
}

proc ::tclapp::xilinx::designutils::insert_buffer::restoreCellLoc {args} {
  # Summary : check that all attached cells are unplaced. All the connected cells
  # can be forced to be unplaced

  # Argument Usage:
  # clear : if 1 then the array keeping the cell location is deleted after the cells placement has been restored

  # Return Value:
  # 0 if all the connected cells are unplaced. 1 otherwise
  # TCL_ERROR if failed

  # Categories: xilinxtclstore, designutils

  variable debug
  variable LOC
  variable PLACED
  variable PLACED_LOC_FIXED
  variable PLACED_BEL_FIXED

  # First assign default values...
  array set options {-clear 1}
  # ...then possibly override them with user choices
  array set options $args

  if {[info exists LOC]} {
    if {$debug} {
      puts " DEBUG: restoring LOC property for [llength [array names LOC]] cells"
    }
    set cellsToPlace [list]
    set cellsToReset [list]
    foreach cell [array names LOC] {
      foreach {loc bel} $LOC($cell) { break }
      # LOC: SLICE_X23Y125
      # BEL: SLICEL.B5LUT
      # Need to generate the placement info in the following format: SLICE_X23Y125/B5LUT
      set placement "$loc/[lindex [split $bel .] end]"
      lappend cellsToReset $cell
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
    # Reset the IS_LOC_FIXED/IS_BEL_FIXED properties that are automatically set the place_cell
    set_property -quiet IS_BEL_FIXED 1 $PLACED_BEL_FIXED
    set_property -quiet IS_LOC_FIXED 1 $PLACED_LOC_FIXED
  }
  # Reset list of cells placement?
  if {$options(-clear)} {
    set PLACED [list]
    set PLACED_LOC_FIXED [list]
    set PLACED_BEL_FIXED [list]
    catch {unset LOC}
  }
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

proc ::tclapp::xilinx::designutils::insert_buffer::insertBufferOnPin {pin {bufferType BUFG} {force 0}} {
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

  set pinClass [string toupper [get_property -quiet CLASS $insertionPin]]
  set pinDir [string toupper [get_property -quiet DIRECTION $insertionPin]]
  set net [get_nets -quiet -of $insertionPin]
  # We first need to check that all the cells connected to the register are NOT placed.
  # Otherwise the connect_net command cannot work
  collectConnectedCells $net
  unplaceConnectedCells -force $force

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

proc ::tclapp::xilinx::designutils::insert_buffer::insertBufferOnNet {net {bufferType BUFG} {force 0}} {
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
  collectConnectedCells $bufOutNet
  unplaceConnectedCells -force $force

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

  if {$debug} { puts " DEBUG: restoreCellLoc" }
  # Restore cells LOC
  restoreCellLoc

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

  set leafPins [get_pins -quiet [all_fanout -quiet -from $net -level 1 -pin_levels 1 -trace_arcs all] -filter {IS_LEAF && DIRECTION==IN}]
  set leafPorts [get_ports -quiet [all_fanout -quiet -from $net -level 1 -pin_levels 1 -trace_arcs all] -filter {DIRECTION==OUT}]
  set hierPins [get_pins -quiet [all_fanout -quiet -from $net -level 1 -pin_levels 1 -trace_arcs all] -filter {!IS_LEAF}]

  set allPins [concat $leafPins $leafPorts $hierPins]
  if {$debug>1} { puts " DEBUG: allPins ([llength $allPins]): $allPins" }
  return $allPins
}

proc ::tclapp::xilinx::designutils::insert_buffer::disconnectPin {pinName} {
  # Summary : disconnect a pin or port from the net connected to it

  # Argument Usage:
  # pinName : Pin or port name

  # Return Value:
  # 0 if succeeded
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug
  if {$pinName == {}} {
    error " error - no pin or port specified"
  }

  set hierSep [get_hierarchy_separator]
  set pin [getPinOrPort $pinName]
  switch [llength $pin] {
    0 {
      error " error - cannot find pin or port $pinName"
    }
    1 {
      # Ok
    }
    default {
      # More than 1 pin
      error " error - more than 1 ([llength $pin]) pin or port match $pinName"
    }
  }
  set net [get_nets -quiet -of $pin]
  if {$net == {}} { return 0 }

  if {$debug>1} { puts " DEBUG: disconnecting pin $pin from net $net" }
  disconnect_net -verbose -prune -net $net -obj $pin
#   disconnect_net -verbose -net $net -obj $pin
  return 0
}

proc ::tclapp::xilinx::designutils::insert_buffer::pinTieHigh {pinName} {
  # Summary : tie pin to VCC

  # Argument Usage:
  # pinName : Pin name

  # Return Value:
  # 0 if succeeded
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug
  if {$pinName == {}} {
    error " error - no pin specified"
  }

  set hierSep [get_hierarchy_separator]
  set pin [get_pins -quiet $pinName]
  switch [llength $pin] {
    0 {
      error " error - cannot find pin $pinName"
    }
    1 {
      # Ok
    }
    default {
      # More than 1 pin
      error " error - more than 1 ([llength $pin]) pin match $pinName"
    }
  }
  # First, disconnect pin
  if {$debug>1} { puts " DEBUG: disconnectPin $pin" }
  disconnectPin $pin
  # Then tie the pin to VCC
  # Instead of connecting the pin to an existing VCC net, create a new net.
  # Doing this prevent issue when other pins of placed instanced would be connected
  # to an existing power net.
  set parentName [get_property -quiet PARENT [get_property -quiet PARENT_CELL $pin]]
  if {$parentName != {}} {
    set vccname [genUniqueName $parentName/VCC]
    set vcc [createCell $vccname VCC $parentName]
    set netname [genUniqueName ${vccname}_net]
    set net [createNet $netname $parentName]
    connect_net -hier -net $net -obj [get_pins -quiet $vcc/P]
  } else {
    set vccname [genUniqueName VCC]
    set vcc [createCell $vccname VCC]
    set netname [genUniqueName ${vccname}_net]
    set net [createNet $netname]
    connect_net -hier -net $net -obj [get_pins -quiet $vcc/P]
  }
  if {$debug>1} { puts " DEBUG: connect_net -hier -net $net -obj $pin" }
  connect_net -hier -net $net -obj $pin
  return 0
}

proc ::tclapp::xilinx::designutils::insert_buffer::pinTieLow {pinName} {
  # Summary : tie pin to GND

  # Argument Usage:
  # pinName : pin name

  # Return Value:
  # 0 if succeeded
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  variable debug
  if {$pinName == {}} {
    error " error - no pin specified"
  }

  set hierSep [get_hierarchy_separator]
  set pin [get_pins -quiet $pinName]
  switch [llength $pin] {
    0 {
      error " error - cannot find pin $pinName"
    }
    1 {
      # Ok
    }
    default {
      # More than 1 pin
      error " error - more than 1 ([llength $pin]) pin match $pinName"
    }
  }
  # First, disconnect pin
  if {$debug>1} { puts " DEBUG: disconnectPin $pin" }
  disconnectPin $pin
  # Then tie the pin to GND
  # Instead of connecting the pin to an existing VCC net, create a new net.
  # Doing this prevent issue when other pins of placed instanced would be connected
  # to an existing power net.
  set parentName [get_property -quiet PARENT [get_property -quiet PARENT_CELL $pin]]
  if {$parentName != {}} {
    set gndname [genUniqueName $parentName/GND]
    set gnd [createCell $gndname GND $parentName]
    set netname [genUniqueName ${gndname}_net]
    set net [createNet $netname $parentName]
    connect_net -hier -net $net -obj [get_pins -quiet $gnd/G]
  } else {
    set gndname [genUniqueName GND]
    set gnd [createCell $gndname GND]
    set netname [genUniqueName ${gndname}_net]
    set net [createNet $netname]
    connect_net -hier -net $net -obj [get_pins -quiet $gnd/G]
  }
  if {$debug>1} { puts " DEBUG: connect_net -hier -net $net -obj $pin" }
  connect_net -hier -net $net -obj $pin
  return 0
}

#####################################
################ EOF ################
#####################################
