package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::incrcompile {
    namespace export highlight_non_reused
}

proc ::tclapp::xilinx::incrcompile::highlight_non_reused { object } {
  # Summary : highlight non reused objects

  # Argument Usage:
  #  object : The object type. The valid values are : -cells -nets -pins -ports -sites

  # Return Value:
  # none, objects are highlighted with different colors on GUI

  # Categories: xilinxtclstore, incrcompile

  if { $object ne "-cells" && $object ne "-nets" && $object ne "-pins" && $object ne "-ports" && $object ne "-sites" } {
    puts "Error: Illegal value for argument object, valid values are : -cells -nets -pins -ports -sites"
    return
  }
  highlight_objects -color red [get_non_reused $object]
}
