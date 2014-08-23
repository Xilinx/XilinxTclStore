package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::incrcompile {
    namespace export get_non_reused
}

proc ::tclapp::xilinx::incrcompile::get_non_reused { object } {
  # Summary : get non reused objects

  # Argument Usage:
  #  object : The object type. The valid values are : -cells -nets -pins -ports -sites

  # Return Value:
  # list of non reused objects

  # Categories: xilinxtclstore, incrcompile

  set ret_values {}
  if { $object ne "-cells" && $object ne "-nets" && $object ne "-pins" && $object ne "-ports" && $object ne "-sites" } {
    puts "Error: Illegal value for argument object, valid values are : -cells -nets -pins -ports -sites"
    return $ret_values
  }
  if { $object eq "-cells" } {
    set ret_values [get_cells -filter { IS_REUSED ==0 && IS_PRIMITIVE==1 && REF_NAME!=GND && REF_NAME!=VCC} -hierarchical ]
  }

  if { $object eq "-nets" } {
    set ret_values [get_nets -filter { REUSE_STATUS=="NON_REUSED" && ROUTE_STATUS!=INTRASITE} -hierarchical ]
  }

  if { $object eq "-pins" } {
    set ret_values [get_pins -filter { is_reused==0 } -hierarchical ]
  }

  if { $object eq "-ports" } {
    set ret_values [get_ports -filter { is_reused==0 }]
  }
  if { $object eq "-sites" } {
    set non_reused_sites "";
    foreach site [get_sites -filter {IS_USED==1} ] {
      set reused [llength [get_cells -of_objects [get_sites $site] -filter {is_reused==1}]];
      if { $reused == 0 } {
        lappend non_reused_sites $site;
      }
    }
    set ret_values $non_reused_sites
  }
  return $ret_values
}
