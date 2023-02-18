package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export get_device_sll_nodes
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils::get_device_sll_nodes {
#     namespace export get_device_sll_nodes
 } ]

proc ::tclapp::xilinx::designutils::get_device_sll_nodes {args} {
  # Summary : Get all device SLL nodes

  # Argument Usage:

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  set nodes [uplevel [concat ::tclapp::xilinx::designutils::get_device_sll_nodes::get_device_sll_nodes $args]]
  return $nodes
}


proc ::tclapp::xilinx::designutils::get_device_sll_nodes::get_device_sll_nodes {} {
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
    spartan7 -
    zynq {
      set res [::tclapp::xilinx::designutils::get_device_sll_nodes::get_device_sll_nodes_7serie]
      return $res
    }
    kintexu -
    kintexum -
    virtexu -
    virtexum {
      set res [::tclapp::xilinx::designutils::get_device_sll_nodes::get_device_sll_nodes_ultrascale]
      return $res
    }
    zynquplus -
    kintexuplus -
    virtexuplus -
    virtexuplus58g -
    virtexuplusHBM -
    zynquplusRFSOC {
      set res [::tclapp::xilinx::designutils::get_device_sll_nodes::get_device_sll_nodes_ultrascale_plus]
      return $res
    }
    versal -
    versalHBM {
      set res [::tclapp::xilinx::designutils::get_device_sll_nodes::get_device_sll_nodes_versal]
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

proc ::tclapp::xilinx::designutils::get_device_sll_nodes::get_device_sll_nodes_versal {} {
  # Summary :
  # Argument Usage:
  # Return Value:

   set sll_nodes [get_nodes -quiet -of_objects [get_tiles -quiet -of_objects [get_slrs -quiet ] SLL*] SLL*/UBUMP* -filter {IS_CROSSING_SLRS}]
   return $sll_nodes
}

proc ::tclapp::xilinx::designutils::get_device_sll_nodes::get_device_sll_nodes_ultrascale_plus {} {
  # Summary :
  # Argument Usage:
  # Return Value:
          
  set sll_nodes [get_nodes -quiet -of_objects [get_tiles -quiet -of_objects [get_slrs -quiet ] LAG_LAG*] LAG* -filter {IS_CROSSING_SLRS}]
  return $sll_nodes
}

proc ::tclapp::xilinx::designutils::get_device_sll_nodes::get_device_sll_nodes_ultrascale {} {
  # Summary :
  # Argument Usage:
  # Return Value:
         
  set sll_nodes [get_nodes -quiet -of_objects [get_tiles -quiet -of_objects [get_slrs -quiet ] LAG*] -filter {IS_CROSSING_SLRS && NAME!~*_EXTRA}]
  return $sll_nodes
}

proc ::tclapp::xilinx::designutils::get_device_sll_nodes::get_device_sll_nodes_7serie {} {
  # Summary :
  # Argument Usage:
  # Return Value:

#  set sllList [get_nodes -quiet -of_objects [get_tiles -quiet -of_objects [get_slrs -quiet ]] -filter {IS_CROSSING_SLRS}]
#  return $sllList
   set sll_nodes [concat [get_nodes -quiet -of_objects [get_tiles -quiet T_TERM_INT_SLV*] -filter {COST_CODE_NAME == VLONG12 && NUM_WIRES>100 && IS_CROSSING_SLRS}] \
[get_nodes -quiet -of_objects [get_tiles -quiet CLK_TERM_*] -filter {IS_CROSSING_SLRS}] ] 
   return $sll_nodes
}
