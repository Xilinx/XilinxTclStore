####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export get_sll_nodes
}

proc ::tclapp::xilinx::designutils::get_sll_nodes { {slr *} } {
  # Summary : returns all the sll node objects in the device for matching SLRs

  # Argument Usage:
  # [slr=*] : Default is across all SLRs - valid values for slr are * or an integer for the specifc SLR ID
  
  # Return Value:
  # returns all the sll node objects in the device
  
  # Categories: xilinctclstore, designutils

  set sllList [list]
  if {$slr == "*"} {
    set slvTiles [get_tiles -quiet T_TERM_INT_SLV*]
  } else {
    set slvTiles [get_tiles -quiet T_TERM_INT_SLV* -filter "SLR_REGION_ID == $slr"]
  }
  foreach tile $slvTiles {
    foreach node [get_nodes -quiet -filter "COST_CODE_NAME == VLONG12" -of $tile] {
      set wireList [get_wires -quiet -of $node]
      # SLLs have a large number of wires - normal vlongs have < 20
      if {[llength $wireList] > 100} {
        #	    puts "DEBUG:  SLL - $node"
        lappend sllList $node
      }
    }
  }
  return $sllList
}
