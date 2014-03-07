package require Vivado 1.2014.1
package require struct::list 1.7


namespace eval ::tclapp::xilinx::designutils {
    namespace export get_connected_ref_pins
}


proc ::tclapp::xilinx::designutils::get_connected_ref_pins {analyze_pin} {
  # Summary : Return a list of reference pins connected to the pin

  # Argument Usage:
  # analyze_pin : Pin to analyze

  # Return Value:
  # List of reference pins.  This is the REF_PIN_NAME property of the pins connected.

  # Categories: xilinxtclstore, designutils



  if { [get_property DIRECTION $analyze_pin]=="IN" } {
    set drv_ref_cel [get_property REF_NAME [get_pins -leaf -filter DIRECTION==OUT -of [get_nets -top -seg -of [get_pins $analyze_pin]]]]
    set drv_ref_pin [get_property REF_PIN_NAME [get_pins -leaf -filter DIRECTION==OUT -of [get_nets -top -seg -of [get_pins $analyze_pin]]]]
    set conn_ref_pins "${drv_ref_cel}/${drv_ref_pin}"
  } else {
    foreach rec [get_pins -leaf -filter DIRECTION==IN -of [get_nets -top -seg -of [get_pins $analyze_pin]]] {
      set rec_ref_cel [get_property REF_NAME $rec]
      set rec_ref_pin [get_property REF_PIN_NAME $rec]
      lappend conn_ref_pins "${rec_ref_cel}/${rec_ref_pin}"
   }
   set conn_ref_pins [lsort -unique $conn_ref_pins]
  }

  set conn_ref_pins [struct::list::Lflatten -full $conn_ref_pins]
  return $conn_ref_pins
}
