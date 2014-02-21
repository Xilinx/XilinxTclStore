package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export get_sll_nets
}

proc ::tclapp::xilinx::designutils::get_sll_nets { {nets {*}} } {
  # Summary : get routed inter-SLR nets that have a VLONG12 cost and over 100 wire shapes on at least one of its nodes

  # Argument Usage:
  # [nets = *] : List of SLR nets to filter. A value of "*" means that all the inter-SLR nets are considered

  # Return Value:
  # returns all SLL-crossing nets
  
  # Categories: xilinxtclstore, designutils

  # Get all the inter-SLR nets if no list of nets has been provided
  if {$nets == {*}} {
    set nets [::tclapp::xilinx::designutils::get_inter_slr_nets]
  }
  set vlongNets [list]
  foreach net $nets {
    set nodeList [get_nodes -quiet -of $net -filter "COST_CODE_NAME == VLONG12"]
    if {[llength $nodeList] > 0} {
      # Found a net with VLONG (very long line) routing on it - now check to see if it is a SLL:
      foreach node $nodeList {
        if {[llength [get_wires -quiet -of $node]] > 100} {
          # SLLs are VLONG12s with more than 100 wire shapes so capture this net in a list
          lappend vlongNets $net
          # Skip other nodes, go to next net
          break
        }
      }
    }
  }
  return $vlongNets
}

