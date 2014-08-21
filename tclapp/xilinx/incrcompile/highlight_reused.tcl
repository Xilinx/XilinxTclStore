package require Vivado 1.2014.3

namespace eval ::tclapp::xilinx::incrcompile {
    namespace export highlight_reused
}

proc ::tclapp::xilinx::incrcompile::highlight_reused { object {reuse_category ""}} {
  # Summary : highlight reused objects

  # Argument Usage:
  #  object : The object type. The valid values are : -cells -nets -pins -ports -sites
  #  reuse_category : The valid values are : -fully -partially. This argument is allowed only with object type of -nets or -sites

  # Return Value:
  # none, objects are highlighted with different colors on GUI

  # Categories: xilinxtclstore, incrcompile

  if { $object ne "-cells" && $object ne "-nets" && $object ne "-pins" && $object ne "-ports" && $object ne "-sites" } {
    puts "Error: Illegal value for argument object, valid values are : -cells -nets -pins -ports -sites"
    return
  }
  if { $reuse_category ne "" && ($object ne "-nets" && $object ne "-sites") } {
    puts "Error: Illegal use of argument reuse_category, reuse_category is allowed only with either -sites or -nets"
    return
  }
  if { $reuse_category ne "" && $reuse_category ne "-fully" && $reuse_category ne "-partially"} {
    puts "Error: Illegal value for argument reuse_category, valid values are : -fully -partially"
    return
  }
  highlight_objects -color green [get_reused $object $reuse_category]
}
