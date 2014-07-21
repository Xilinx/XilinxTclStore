####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2014.2

namespace eval ::tclapp::xilinx::incremental {
    namespace export highlight_reused_sites
}

proc ::tclapp::xilinx::incremental::highlight_reused_sites { {color1 "red"} {color2 "yellow"} {color3 "cyan"} } {
  # Summary : highlight fully reused , partially reused  and non-reused sites with different colors

  # Argument Usage:
  #  color1 : highlight color for fully reused site
  #  color2 : highlight color for partially reused site
  #  color3 : highlight color for non-reused site

  # Return Value:
  # none, sites are highlighted with different colors on GUI

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
    } else {
      lappend partially_reused_sites $site;
    }
  }
  if { [llength $fully_reused_sites] != 0 } {
    highlight_objects -color $color1 [get_sites $fully_reused_sites]
  }
  if { [llength $partially_reused_sites] != 0 } {
    highlight_objects -color $color2 [get_sites $partially_reused_sites]
  }
  if { [llength $non_reused_sites ] != 0 } {
    highlight_objects -color $color3 [get_sites $non_reused_sites]
  }
  puts "Fully reused sites: [llength $fully_reused_sites]"
  puts "Partially reused sites: [llength $partially_reused_sites]"
  puts "Non reused sites: [llength $non_reused_sites]"
}
