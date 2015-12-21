package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export get_sll_nodes get_sll_nets
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils::get_sll_nets {
#     namespace export get_sll_nodes get_sll_nets
 } ]

proc ::tclapp::xilinx::designutils::get_sll_nodes {args} {
  # Summary : Get the SLL nodes on a routed design

  # Argument Usage:

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  set nodes [uplevel [concat ::tclapp::xilinx::designutils::get_sll_nets::get_sll_nodes $args]]
  return $nodes
}

proc ::tclapp::xilinx::designutils::get_sll_nets {args} {
  # Summary : Get the SLL nets on a routed design

  # Argument Usage:

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  set nets [uplevel [concat ::tclapp::xilinx::designutils::get_sll_nets::get_sll_nets $args]]
  return $nets
}

proc ::tclapp::xilinx::designutils::get_sll_nets::get_sll_nets {} {
  # Summary :
  # Argument Usage:
  # Return Value:

  set error 0
  # Get the current architecture
  set architecture [::tclapp::xilinx::designutils::getArchitecture]
  switch $architecture {
    artix7 -
    kintex7 -
    virtex7 -
    zynq {
      set nodes [::tclapp::xilinx::designutils::get_sll_nets::get_sll_nodes_7serie]
      set nets [get_nets -quiet -of $nodes]
      # The list of nets need to be post-processed to only keep nets that have leaf
      # pins in multiple SLRs
      set slls [list]
      foreach net $nets {
        if {[llength [get_slrs -quiet -of [get_pins -quiet -leaf -of $net]]] < 2} { continue }
        lappend slls $net
      }
      return $slls
    }
    kintexu -
    kintexum -
    virtexu -
    virtexum {
      set nodes [::tclapp::xilinx::designutils::get_sll_nets::get_sll_nodes_ultrascale]
      set nets [get_nets -quiet -of $nodes]
      return $nets
    }
    default {
      puts " -E- architecture $architecture is not supported."
      incr error
    }
  }
  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }
  return -code ok
}

proc ::tclapp::xilinx::designutils::get_sll_nets::get_sll_nodes {} {
  # Summary :
  # Argument Usage:
  # Return Value:

  set error 0
  # Get the current architecture
  set architecture [::tclapp::xilinx::designutils::getArchitecture]
  switch $architecture {
    artix7 -
    kintex7 -
    virtex7 -
    zynq {
      set res [::tclapp::xilinx::designutils::get_sll_nets::get_sll_nodes_7serie]
      return $res
    }
    kintexu -
    kintexum -
    virtexu -
    virtexum {
      set res [::tclapp::xilinx::designutils::get_sll_nets::get_sll_nodes_ultrascale]
      return $res
    }
    default {
      puts " -E- architecture $architecture is not supported."
      incr error
    }
  }
  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }
  return -code ok
}

proc ::tclapp::xilinx::designutils::get_sll_nets::get_sll_nodes_ultrascale {} {
  # Summary :
  # Argument Usage:
  # Return Value:

  set chip_SLRs [get_slrs]
  set bot_SLR [lindex $chip_SLRs 0]
  set top_SLR [lindex $chip_SLRs end]
  array set clock_regions {}
  set sll_nodes [list]

  foreach SLR [lsort -decreasing [lrange $chip_SLRs 0 end-1]] {
    set clock_regions($SLR) [get_clock_regions -of $SLR]
#     regexp {X(\d*)Y(\d*)} [lindex [lsort $clock_regions($SLR)] 0] all clock_regions_minx($SLR) clock_regions_miny($SLR)
#     regexp {X(\d*)Y(\d*)} [lindex [lsort $clock_regions($SLR)] end] all clock_regions_maxx($SLR) clock_regions_maxy($SLR)
    regexp {X(\d*)Y(\d*)} [lindex [lsort $clock_regions($SLR)] 0] - Xmin Ymin
    regexp {X(\d*)Y(\d*)} [lindex [lsort $clock_regions($SLR)] end] - Xmax Ymax
    set clock_regions_minx($SLR) [::tclapp::xilinx::designutils::min $Xmin $Xmax]
    set clock_regions_maxx($SLR) [::tclapp::xilinx::designutils::max $Xmin $Xmax]
    set clock_regions_miny($SLR) [::tclapp::xilinx::designutils::min $Ymin $Ymax]
    set clock_regions_maxy($SLR) [::tclapp::xilinx::designutils::max $Ymin $Ymax]
    for {set x $clock_regions_minx($SLR)} {$x<=$clock_regions_maxx($SLR)} {incr x} {
      set clock_region "X${x}Y$clock_regions_maxy($SLR)"
      set all_SLLs($clock_region) [get_nodes -quiet -of [get_tiles -quiet LAGUNA_TILE_X*Y* -of [get_clock_regions -quiet $clock_region]] -regexp -filter {NAME =~ .*UBUMP\d.*}]
      set baseClockRegion [get_property -quiet BASE_CLOCK_REGION [lindex $all_SLLs($clock_region) 0]]
      set tiles [lsort [get_tiles -of $all_SLLs($clock_region)]]
#       regexp {LAGUNA_TILE_X(\d*)Y(\d*)} [lindex $tiles 0] all CLB_col_min LagunaY
#       regexp {LAGUNA_TILE_X(\d*)Y(\d*)} [lindex $tiles end] all CLB_col_max LagunaY
      regexp {LAGUNA_TILE_X(\d*)Y(\d*)} [lindex $tiles 0] - Xmin LagunaY
      regexp {LAGUNA_TILE_X(\d*)Y(\d*)} [lindex $tiles end] - Xmax LagunaY
      set CLB_col_min [::tclapp::xilinx::designutils::min $Xmin $Xmax]
      set CLB_col_max [::tclapp::xilinx::designutils::max $Xmin $Xmax]
      set used_SLLs($SLR:$clock_region:$CLB_col_min) [get_nodes -quiet -of [get_nets -quiet -of [get_nodes -of [get_tiles -quiet LAGUNA_TILE_X${CLB_col_min}Y* -of [get_clock_regions -quiet $clock_region]] -regexp -filter {NAME =~ .*UBUMP\d.*}]] -filter BASE_CLOCK_REGION=~$baseClockRegion&&NAME=~LAGUNA_TILE_X${CLB_col_min}Y*UBUMP*]
      set used_SLLs($SLR:$clock_region:$CLB_col_max) [get_nodes -quiet -of [get_nets -quiet -of [get_nodes -of [get_tiles -quiet LAGUNA_TILE_X${CLB_col_max}Y* -of [get_clock_regions -quiet $clock_region]] -regexp -filter {NAME =~ .*UBUMP\d.*}]] -filter BASE_CLOCK_REGION=~$baseClockRegion&&NAME=~LAGUNA_TILE_X${CLB_col_max}Y*UBUMP*]
      foreach el $used_SLLs($SLR:$clock_region:$CLB_col_min) { lappend sll_nodes $el }
      foreach el $used_SLLs($SLR:$clock_region:$CLB_col_max) { lappend sll_nodes $el }
    }
  }
  return $sll_nodes
}

proc ::tclapp::xilinx::designutils::get_sll_nets::get_sll_nodes_7serie {} {
  # Summary :
  # Argument Usage:
  # Return Value:

  # Categories: xilinxtclstore, designutils

  set sllList [list]
  
  # For non-clock nets
  set slvTiles [get_tiles -quiet T_TERM_INT_SLV*]
#   set slvTiles [get_tiles -quiet T_TERM_INT_SLV* -filter "SLR_REGION_ID == <REGION_ID>"]
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

  # For clock nets
  set slvTiles [get_tiles -quiet CLK_TERM_*]
  foreach node [get_nodes -quiet -of $slvTiles] {
    if {[llength [get_nets -quiet -of $node]] > 0} {
      #	    puts "DEBUG:  SLL - $node"
      lappend sllList $node
    }
  }

  return $sllList
}
