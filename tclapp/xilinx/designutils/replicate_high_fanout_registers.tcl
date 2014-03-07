package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export replicate_high_fanout_registers clone_net_driver clone_cell
}

proc ::tclapp::xilinx::designutils::replicate_high_fanout_registers { {maxFan 100} {inst *} {reportOnly 0} } {
  # Summary :
  # Replicate registers to limit register fanout to maxFan.  Run after synthesis
  
  # Argument Usage:
  # maxFan : Max fanout limit (default: 100)
  # inst : Hierarchical scope (default: *)
  # reportOnly : If non-zero only report otherwise replicate logic (default: 0)

  # Return Value:
  # 0
  
  # Categories: xilinxtclstore, designutils

  uplevel ::tclapp::xilinx::designutils::replicate_high_fanout_registers::replicate_high_fanout_registers $maxFan $inst $reportOnly
  return 0
}

proc ::tclapp::xilinx::designutils::clone_net_driver {net {suffix {}}} {
  # Summary :
  # Clone the driver cell of a net. Run after synthesis
  
  # Argument Usage:
  # net: Net
  # [suffix = ] : Optional suffix to be appended to the name of the cloned driver

  # Return Value:
  # created net on the cloned driver
  # TCL_ERROR if fails

  # Categories: xilinxtclstore, designutils

  return [uplevel ::tclapp::xilinx::designutils::replicate_high_fanout_registers::clone_net_driver $net $suffix]
}

proc ::tclapp::xilinx::designutils::clone_cell {cell {suffix {}}} {
  # Summary :
  # Clone a cell and connects all the clone input pins to the master input pins. Run after synthesis
  
  # Argument Usage:
  # cell: Cell
  # [suffix = ] : Optional suffix to be appended to the name of the cloned cell

  # Return Value:
  # cloned cell
  # TCL_ERROR if fails

  # Categories: xilinxtclstore, designutils

  return [uplevel ::tclapp::xilinx::designutils::replicate_high_fanout_registers::clone_cell $cell $suffix]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils::replicate_high_fanout_registers { 
  variable debug 0
} ]

proc ::tclapp::xilinx::designutils::replicate_high_fanout_registers::replicate_high_fanout_registers { {maxFan 100} {inst *} {reportOnly 0} } {
  # Summary :
  # Replicate registers to limit register fanout to maxFan.  Run after synthesis
  
  # Argument Usage:
  # maxFan : Max fanout limit (default: 100)
  # inst : Hierarchical scope (default: *)
  # reportOnly : If non-zero only report otherwise replicate logic (default: 0)

  # Return Value:
  # 0
  
  # Categories: xilinxtclstore, designutils

  set hiFanRegs {} ; # list of reg insts that have fanout above maxFan
  set hiFanNets [dict create]  ; # nets driven by each high-fanout reg
  set hiFanLoads [dict create] ; # load pins driven by each high-fanout reg
  set pass 1
  
  getHighFanoutRegs $maxFan $inst hiFanRegs hiFanNets hiFanLoads
  
  # As each pass is run, replication may increase fanouts above maxFan
  # Keep iterating while there are high-fanout regs
  while {[llength $hiFanRegs] > 0 && $reportOnly == 0} {
    replicateAllRegs $maxFan $hiFanNets $hiFanLoads
    set hiFanRegs {}
    set hiFanNets [dict create]
    set hiFanLoads [dict create]
    puts "Finished pass $pass\n"
    incr pass
    getHighFanoutRegs $maxFan $inst hiFanRegs hiFanNets hiFanLoads
  }
  return 0
}

proc ::tclapp::xilinx::designutils::replicate_high_fanout_registers::clone_net_driver {net {suffix {}}} {
  # Summary :
  # Clone the driver cell of a net. Run after synthesis
  
  # Argument Usage:
  # net: Net
  # [suffix = ] : Optional suffix to be appended to the name of the cloned driver

  # Return Value:
  # created net on the cloned driver
  # TCL_ERROR if fails
  
  # Categories: xilinxtclstore, designutils

  set netObj [get_nets -quiet $net]
  if {$netObj == {}} {
    error "  error - net $net not found"
  }
  
  set driverPin [get_pins -quiet -leaf -of_objects $netObj -filter {DIRECTION == "OUT"}]
  switch [llength $driverPin] {
    0 {
      error "  error - no driver found for net $net"
    }
    1 {
      # Check whether any of the cell connected to the net is unplaced (this is not allowed)
      if {[checkAllConnectedCellsUnplaced $net] == 1} {
        error "  error - net $net is connected to some unplaced instances"
      }
    }
    default {
      error "  error - net $net has multiple driver pins: $driverPin"
    }
  }
  # Clone the driver and return the cloned net
  return [cloneReg [get_cells -quiet -of $driverPin] $netObj $suffix]
}

proc ::tclapp::xilinx::designutils::replicate_high_fanout_registers::clone_cell {cell {suffix {}}} {
  # Summary :
  # Clone a cell and connects all the clone input pins to the master input pins. Run after synthesis
  
  # Argument Usage:
  # cell: Cell
  # [suffix = ] : Optional suffix to be appended to the name of the cloned cell

  # Return Value:
  # cloned cell
  # TCL_ERROR if fails
  
  # Categories: xilinxtclstore, designutils

  set cellObj [get_cells -quiet $cell]
  switch [llength $cellObj] {
    0 {
      error "  error - cell $cell not found"
    }
    1 {
      if {[get_property -quiet IS_PRIMITIVE $cellObj] == 0} {
        error "  error - cell $cell is hierarchical"
      }
      # Check whether any of the cell connected to the cell is unplaced (this is not allowed)
      if {[checkAllConnectedCellsUnplaced $cell] == 1} {
        error "  error - cell $cell is connected to some unplaced instances"
      }
    }
    default {
      error "  error - cell $cell matches [llength $cellObj] cells: $cellObj"
    }
  }
  
  # Clone the cell and return the cloned cell
  return [cloneReg $cellObj {} $suffix]
}

proc ::tclapp::xilinx::designutils::replicate_high_fanout_registers::getHighFanoutRegs {maxFan inst hiFanRegs hiFanNets hiFanLoads} {
  # Summary : build the data structure of high fanout registers
  
  # Argument Usage:
  # maxFan : Desired fanout limit
  # hiFanRegs: List of reg insts that have fanout above maxFan
  # hiFanNets: Dictionary of nets driven by each high-fanout reg
  # hiFanLoads: Dictionary of load pins driven by each high-fanout reg
  
  # Return Value:
  # 0, results returned in the input variables
  
  # Categories: xilinxtclstore, designutils

  upvar $hiFanRegs regs
  upvar $hiFanNets nets
  upvar $hiFanLoads loads
  set regs {}
  set maxMaxFan 0
  set regMaxFan {}
  puts "Searching for high-fanout registers in $inst ..."
  set filterPattern "lib_cell =~ FD* && name =~ $inst"

  foreach reg [get_cells -quiet -hier * -filter $filterPattern] {
    # get the network driven by the reg
    set output [get_pins -quiet -leaf -of_objects $reg -filter {direction == OUT}]
    set net [get_nets -quiet -of_objects $output]
    set cond {direction != "OUT"}    ; # exclude the high-fanout driver
    set cond "$cond && !is_clock"    ; # add clock pins to exclusion
    set cond "$cond && !is_clear"    ; # add async clear pins to exclusion
    set cond "$cond && !is_preset"   ; # add async set pins to exclusion
    set cond "$cond && !is_reset"    ; # add async reset pins to exclusion
    set cond "$cond && !is_enable"   ; # add async enable pins to exclusion
#     set cond "$cond && name !~ */R"  ; # add sync clear pins to exclusion
#     set cond "$cond && name !~ */S"  ; # add sync set pins to exclusion
#     set cond "$cond && name !~ */CE" ; # add clock enable pins to exclusion
    set loadPins [get_pins -leaf -quiet -of_objects $net -filter $cond]
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
  return 0
}

proc ::tclapp::xilinx::designutils::replicate_high_fanout_registers::cloneReg {regOrig netOrig {copyIndex {}}} {
  # Summary : creates a clone of the register/cell and connects all its input pins to the original register pins
  
  # Argument Usage:
  # regOrig : Register to copy
  # netOrig : Net driven by register
  # [copyIndex = ] : Optional ID string
  
  # Return Value:
  # creates and returns a new net driven by the cloned register output
  # if no net is provided, the cloned instance is returned
  # TCL_ERROR if any of the cells connected to the net is placed
  
  # Categories: xilinxtclstore, designutils

  variable debug
  # change the hierarchy separator here, if not a '/'
#   set hierSep {/}
  set hierSep [get_hierarchy_separator]
  # casting the register and net names into an object. This prevent the
  # potential problem when the names are surrounded by curly brackets
  set regOrig [get_cells -quiet $regOrig]
  set netOrig [get_nets -quiet $netOrig]

  # We first need to check that all the cells connected to the register are NOT placed. 
  # Otherwise the connect_net command cannot work
  checkAllConnectedCellsUnplaced $regOrig 1
  
  set libcell [get_property -quiet REF_NAME $regOrig]
  set inst [genUniqueCellName "${regOrig}${copyIndex}"]
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
  set parentName [get_property -quiet PARENT $regOrig]
  # remove parent cell prefix from the cloned cell name to extract the local name
  regsub "^${parentName}${hierSep}" $inst {} localName
  # escape all the hierarchy separator characters in the local name
  regsub -all $hierSep $localName [format {\%s} $hierSep] localName
  # create the full cell name by appending the escaped local name to the parent name
  if {$parentName != {}} {
    create_cell -reference $libcell ${parentName}${hierSep}${localName}
    if {$debug} { puts " DEBUG: cell ${parentName}${hierSep}${localName} created" }
  } else {
    create_cell -reference $libcell ${localName}
    if {$debug} { puts " DEBUG: cell ${localName} created" }
  }
#   create_cell -reference $libcell $inst
  # get the list of input pins to connect
  set inputPins [get_pins -quiet -of_objects $regOrig -filter \
                     {IS_CONNECTED && DIRECTION != "OUT"}]
  foreach input $inputPins {
    set pinName [get_property -quiet REF_PIN_NAME $input]
    set pinCopy ${inst}${hierSep}${pinName}
    if {$debug} { puts " DEBUG: connecting pin '$pinCopy' to net '[get_nets -quiet -of_objects $input]' (driven by pin '$input')" }
    connect_net -hier -net [get_nets -quiet -of_objects $input] \
        -objects $pinCopy
  }
  
  # If no net to clone was provided, return the cloned instance instead
  if {$netOrig == {}} {
    return [get_cells -quiet $inst]
  }
  
  set netCopy [genUniqueNetName "${netOrig}${copyIndex}"]
  # NOTE: the name passed to create_net needs to be pre-processed for the same reason as for create_cell
  set parentName [get_property -quiet PARENT_CELL $netOrig]
  # remove parent cell prefix from the cloned cell name to extract the local name
  regsub "^${parentName}${hierSep}" $netCopy {} localName
  # escape all the hierarchy separator characters in the local name
  regsub -all $hierSep $localName [format {\%s} $hierSep] localName
  # create the net by appending the escaped local name to the parent name
#   create_net $netCopy
  if {$parentName != {}} {
    create_net ${parentName}${hierSep}${localName}
    if {$debug} { puts " DEBUG: net ${parentName}${hierSep}${localName} created" }
  } else {
    create_net ${localName}
    if {$debug} { puts " DEBUG: net ${localName} created" }
  }
  # get the original register output pin name connected to the net
  set pinName [get_property -quiet REF_PIN_NAME [get_pins \
                   -leaf -quiet -of_objects $netOrig -filter {DIRECTION == OUT}]]
  # connect the relevant output pin of the cloned register to the new net
  connect_net -hier -net $netCopy -objects "$inst/${pinName}"
  return [get_nets -quiet $netCopy]
}

proc ::tclapp::xilinx::designutils::replicate_high_fanout_registers::replicateAllRegs {maxFan hiFanNets hiFanLoads} {
  # Summary : 
  # takes the max fanout limit and the nets and load pins of all
  # high-fanout regs
  # divides the loads into different groups according to max fanout
  # disconnects loads from orig reg and connects to new reg copy

  # Argument Usage:
  # maxFan : Max fanout limit
  # hiFanNets : High fanout nets
  # hiFanLoads : High fanout loads

  # Return Value:
  # 0
  
  # Categories: xilinxtclstore, designutils

  variable debug
  dict for {reg net} $hiFanNets {
    set regOrig [get_cells -quiet $reg]
    # figure out how many groups of load pins
    set loads [dict get $hiFanLoads $reg]

    # Check whether any of the cell connected to the net is unplaced (this is not allowed)
    if {[checkAllConnectedCellsUnplaced $net 1] == 1} {
      # If so, skip the net
      if {$debug} { puts " DEBUG: register $reg / net $net is skipped due to some unplaced cell(s)" }
      continue
    }

    set fanout [llength $loads]
    set groups [expr $fanout / $maxFan]
    set rem [expr $fanout % $maxFan]
    if {$rem > 0} {
        incr groups
    }
    if {$debug} {
      puts "\n DEBUG: Replicating reg $regOrig"
      puts " DEBUG: Original net: $net will be split into $groups groups"
    }
    # divide each group according to number of loads divided by max fanout
    # create a new reg copy to drive each subset of loads
    for {set idxGrp 1} {$idxGrp < $groups} {incr idxGrp} {
      if {$debug>1} { puts " DEBUG: processing group $idxGrp / $groups" }
      # call proc cloneReg to replicate reg and return the copy's net
      set netCopy [cloneReg $regOrig $net "_cpy[expr $idxGrp - 1]"]
      if {$debug>1} { puts " DEBUG: net $netCopy has been created" }
      set idxStart [expr $idxGrp * $maxFan]
      set idxEnd [expr $idxStart + $maxFan - 1]
      if {$idxEnd > $fanout} {
          set idxEnd [expr $idxStart + $rem - 1]
      }
      set loadGroup [lrange $loads $idxStart $idxEnd]
      if {$debug>1} { 
        puts " DEBUG: there are [llength $loadGroup] loads to connect to net $netCopy" 
        foreach load $loadGroup {
          puts " DEBUG:       $load"
        }
      }
      if {$debug>1} { puts " DEBUG: disconnecting all the loads from net $net" }
      # NOTE: the loads should be disconnected from their local net segment and
      # not from $net. The local net segment and $net are different when the
      # net driver and the loads are in different hierarchical level
#       disconnect_net -prune -net $net -objects $loadGroup
      foreach load $loadGroup {
        if {$debug>1} { puts " DEBUG: processing load $load" }
        set localNetSegment [get_nets -quiet -of [get_pins $load]]
        if {$localNetSegment != {}} {
          if {$debug>1} { puts " DEBUG: disconnection load $load from net $localNetSegment" }
          disconnect_net -prune -net $localNetSegment -objects $load
        }
      }
      if {$debug>1} { puts " DEBUG: reconnecting all the loads to net $netCopy" }
      connect_net -hier -net $netCopy -objects $loadGroup
      if {$debug} {
        puts " DEBUG: Group [expr $idxGrp + 1]: driven by new net: $netCopy"
        puts -nonewline " DEBUG: Connecting loads [expr $idxStart + 1] to "
      }
      puts "[expr $idxEnd + 1] of $fanout total loads to net: $netCopy\n"
    }
  }
  return 0
}

proc ::tclapp::xilinx::designutils::replicate_high_fanout_registers::checkAllConnectedCellsUnplaced {name {force 0}} {
  # Summary : check that all attached cells are unplaced. All the connected cells can be forced to be unplaced.
  # It also check that there is no DONT_TOUCH attribute on hierarchical cells, otherwise the boundary cannot
  # be modified

  # Argument Usage:
  # name : cell name or net name
  # [force = 0]: force mode

  # Return Value:
  # 0 if all the connected cells are unplaced. 1 otherwise
  # TCL_ERROR if failed

  # Categories: xilinxtclstore, designutils

  variable debug
  set error 0
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
    # Get all the net segments
    set allConnectedNetSegments [get_nets -segments -of $cell]
  } else {
    # This is a net
#     set allConnectedLeafCells [get_cells -quiet -of $net \
#                      -filter {IS_PRIMITIVE && PRIMITIVE_LEVEL!="INTERNAL"} ]
    set allConnectedLeafCells [get_cells -quiet -of $net \
                     -filter {IS_PRIMITIVE} ]
    # Get all the net segments
    set allConnectedNetSegments [get_nets -quiet -segments $net]
  }
  set props [lsort -unique [get_property -quiet LOC $allConnectedLeafCells ]]
  if { ($props == [list {}]) || ($props == {})} {
    # OK, all connected cells unplaced
#     return 0
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
#     return 0
  } else {
    if {$debug} {
      puts " WARN - some cells are placed"
    }
    if {$debug>1} {
      foreach cell [get_cells -quiet $allConnectedLeafCells -filter {LOC!=""}] {
        puts " DEBUG -    $cell => PLACED"
      }
    }
    incr error
#     return 1
  }
  # Check now for the DONT_TOUCH attribute
  set props [lsort -unique [get_property -quiet DONT_TOUCH [get_cells -quiet -of $allConnectedNetSegments -filter {!IS_PRIMITIVE && DONT_TOUCH}]]]
  if {[lsearch $props 1] == -1} {
    # None of the hierarchical cells crossed by the net segments have a DONT_TOUCH attribute
    if {$error} {
      return 1
    } else {
      return 0
    }
  }
  if {$force} {
    if {$debug} {
      puts " WARN - some hierarchical cells have a DONT_TOUCH property"
    }
    if {$debug>1} {
      foreach cell [get_cells -quiet -of $allConnectedNetSegments -filter {!IS_PRIMITIVE && DONT_TOUCH}] {
        puts " DEBUG -    $cell => DONT_TOUCH"
      }
    }
    # Force removing the DONT_TOUCH attributes
    set_property -quiet DONT_TOUCH 0 [get_cells -quiet -of $allConnectedNetSegments -filter {!IS_PRIMITIVE && DONT_TOUCH}]
    # Double-check that all the DONT_TOUCH attributes have been removed
    set props [lsort -unique [get_property -quiet DONT_TOUCH [get_cells -quiet -of $allConnectedNetSegments -filter {!IS_PRIMITIVE && DONT_TOUCH}]]]
    if {[lsearch $props 1] == -1} {
      # None of the hierarchical cells crossed by the net segments have a DONT_TOUCH attribute
      if {$error} {
        return 1
      } else {
        return 0
      }
    }
#     error " error - some hierarchical cells could not have their DONT_TOUCH property removed"
    puts " WARN - some hierarchical cells could not have their DONT_TOUCH property removed"
    return 1
  } else {
    if {$debug} {
      puts " WARN - some hierarchical cells have a DONT_TOUCH property"
    }
    if {$debug>1} {
      foreach cell [get_cells -quiet -of $allConnectedNetSegments -filter {!IS_PRIMITIVE && DONT_TOUCH}] {
        puts " DEBUG -    $cell => DONT_TOUCH"
      }
    }
    return 1
  }
}

proc ::tclapp::xilinx::designutils::replicate_high_fanout_registers::genUniqueCellName {name} {
  # Summary : return an unique and non-existing cell name

  # Argument Usage:
  # name : base name for the cell

  # Return Value:
  # cell name

  # Categories: xilinxtclstore, designutils

  if {[get_cells -quiet $name] == {}} { return $name }
  set index 0
  while {[get_cells -quiet ${name}_${index}] != {}} { incr index }
  return ${name}_${index}
}

proc ::tclapp::xilinx::designutils::replicate_high_fanout_registers::genUniqueNetName {name} {
  # Summary : return an unique and non-existing net name

  # Argument Usage:
  # name : base name for the net

  # Return Value:
  # net name

  # Categories: xilinxtclstore, designutils

  if {[get_nets -quiet $name] == {}} { return $name }
  set index 0
  while {[get_nets -quiet ${name}_${index}] != {}} { incr index }
  return ${name}_${index}
}
