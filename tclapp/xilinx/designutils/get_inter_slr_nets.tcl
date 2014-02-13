package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export get_inter_slr_nets
}

proc ::tclapp::xilinx::designutils::get_inter_slr_nets {} {
  # Summary : get all the inter-SLR nets

  # Argument Usage:

  # Return Value:
  # list of SLR-crossing net objects
  
  # Categories: xilinxtclstore, designutils

  # returns all 
  set nets [get_nets -hier]
  set netCrossing [list]
  foreach net $nets {
    # Query all the sites of all the placed calls attached to this net
    set siteList [get_sites -quiet -of [get_cells -quiet -of [get_pins -leaf -quiet -of $net] -filter {IS_PRIMITIVE && LOC != ""}]]
    if {$siteList == {}} { continue }
    set slrList [get_slr -of $siteList]
    if {[llength $slrList] > 1} {
      # Multiple SLRs are involved
      lappend netCrossing $net
    }
  }
  return $netCrossing
}
