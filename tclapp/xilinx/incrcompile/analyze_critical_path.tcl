package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::incrcompile {
    namespace export analyze_critical_path
}

proc ::tclapp::xilinx::incrcompile::analyze_critical_path {objects window_name {color "green"}} {
  # Summary : highlight reused pins of given timing paths given by 'get_timing_paths' command

  # Argument Usage:
  #  objects : Return value of get_timing_paths command
  #  window_name : The name of the window of timing report
  #  [color = green] : Optional argument, highlight color for reused pins

  # Return Value:
  # Reused pins on the resulting timing paths as highlighted

  # Categories: xilinxtclstore, incrcompile

  highlight_objects -color $color [get_pins -filter {is_reused==1} -of_objects $objects]
  report_timing -of_objects $objects -name $window_name
}
