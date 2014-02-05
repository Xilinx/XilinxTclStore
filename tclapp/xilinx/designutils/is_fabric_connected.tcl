####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export is_fabric_connected
}


proc ::tclapp::xilinx::designutils::is_fabric_connected {analyze_pin} {
  # Summary : determine if the given pin is connected to a SLICE
  #           for input pins, check just the driver
  #           for output pins, check all loads

  # Argument Usage:
  # analyze_pin : the desired pin to check if it is connected to a SLICE

  # Return Value:
  #               1 if true
  #               0 if false

  # Categories: xilinxtclstore, designutils



  # First check the IS_CONNECTED property
  
  set test [get_property IS_CONNECTED [get_pins $analyze_pin]]

  if { $test=="" || $test==0 } {
    set value 0
  } else {
    # INPUT is easy, just get the type of LIB_CELL driving the net of the PIN.  If it's a FABRIC LIB_CEL then proceed
    # OUTPUT is more difficult, the loads could be different types

    set pin_direction [get_property DIRECTION [get_pins $analyze_pin]]
    set analyze_net [get_nets -top -seg -of [get_pins $analyze_pin]]
    set analyze_net_type [get_property TYPE $analyze_net]
    set analyze_net_pin_count [get_property FLAT_PIN_COUNT $analyze_net]
  
    set st ""
    if { $analyze_net_type=="SIGNAL" && $pin_direction=="IN" && $analyze_net_pin_count > 1} {
      set st [get_property SITE_TYPE [get_sites -of [get_cells -of [get_pins -leaf -filter DIRECTION==OUT -of [get_nets -top -seg -of [get_pins $analyze_pin]]]]]]
    } elseif { $analyze_net_type=="SIGNAL" && $pin_direction=="OUT" && $analyze_net_pin_count > 1} {
      set st_l [get_property SITE_TYPE [get_sites -of [get_cells -of [get_pins -leaf -filter DIRECTION==IN -of [get_nets -top -seg -of [get_pins $analyze_pin]]]]]]
      foreach st_l_i $st_l {
      if {$st_l_i=="SLICEL" || $st_l_i=="SLICEM"} { set st $st_l_i }
      }
    }
     
    if {$st=="SLICEL" || $st=="SLICEM"} {
      set value 1
    } else {
      set value 0
    }
     
  } 
  
  return $value
}
