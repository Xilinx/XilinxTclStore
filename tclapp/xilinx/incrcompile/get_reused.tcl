package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::incrcompile {
    namespace export get_reused
}

proc ::tclapp::xilinx::incrcompile::get_reused { object {reuse_category ""}} {
  # Summary : get reused objects

  # Argument Usage:
  #  object : The object type. The valid values are : cells nets pins ports sites
  #  reuse_category : The valid values are : fully partially. This argument is allowed only with object type of nets or sites

  # Return Value:
  # list of reused objects

  # Categories: xilinxtclstore, incrcompile

  set ret_values {}
  if { $object ne "cells" && $object ne "nets" && $object ne "pins" && $object ne "ports" && $object ne "sites" } {
    puts "Error: Illegal value for argument object, valid values are : cells nets pins ports sites"
    return $ret_values
  }
  if { $reuse_category ne "" && ($object ne "nets" && $object ne "sites") } {
    puts "Error: Illegal use of argument reuse_category, reuse_category is allowed only with either sites or nets"
    return $ret_values
  }
  if { $reuse_category ne "" && $reuse_category ne "fully" && $reuse_category ne "partially"} {
    puts "Error: Illegal value for argument reuse_category, valid values are : fully partially"
    return $ret_values
  }
  if { $object eq "cells" } {
    set ret_values [get_cells -filter { REUSE_STATUS=="Reused" } -hierarchical ]
  }

  if { $object eq "nets" } {
    if { $reuse_category eq "" } {
      set ret_values [get_nets -filter { REUSE_STATUS=="Reused" || REUSE_STATUS=="PARTIALLY_REUSED" } -hierarchical ]
    } elseif { $reuse_category eq "fully" } {
      set ret_values [get_nets -filter { REUSE_STATUS=="Reused" } -hierarchical ]
    } else {
      set ret_values [get_nets -filter { REUSE_STATUS=="PARTIALLY_REUSED" } -hierarchical ]
    }
  }

  if { $object eq "pins" } {
    set ret_values [get_pins -filter { is_reused==1 } -hierarchical ]
  }

  if { $object eq "ports" } {
    set ret_values [get_ports -filter { is_reused==1 }]
  }
  if { $object eq "sites" } {
    set fully_reused_sites "";
    set partially_reused_sites "";
    set non_reused_sites "";
    foreach site [get_sites -filter {IS_USED==1} ] {
      set total [llength [get_cells -of_objects [get_sites $site]]];
      set reused [llength [get_cells -of_objects [get_sites $site] -filter {is_reused==1}]];
      if { $reused == 0 } {
        lappend non_reused_sites $site;
      } elseif { $reused == $total } {
        lappend fully_reused_sites $site;
        lappend reused_sites $site;
      } else {
        lappend partially_reused_sites $site;
        lappend reused_sites $site;
      }
    }
    if { $reuse_category eq "" } {
      set ret_values $reused_sites
    } elseif { $reuse_category eq "fully" } {
      set ret_values $fully_reused_sites
    } else {
      set ret_values $partially_reused_sites
    }
  }

  return $ret_values
}
