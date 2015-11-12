package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export report_cells_fanout
}
    
proc ::tclapp::xilinx::designutils::report_cells_fanout { {ref_name FD*} } {
  # Summary : Report the fanout of cells matching a REF_NAME pattern
  
  # Argument Usage:
  # [ref_name = FD*] : Cell pattern
  
  # Return Value:
  # 0
  
  # Categories: xilinxtclstore, designutils

  # Initialize the table object
  set table [::tclapp::xilinx::designutils::prettyTable create {Fanout Summary}]
  $table header [list {Lib Cell} {Cell} {Output Pin} {Fanout} {Net}]

  set count 0
  foreach cell [get_cells -hier -filter "REF_NAME =~ $ref_name"] {
    set ref_name [get_property -quiet REF_NAME $cell]
    set firstPin 1
    foreach pin [get_pins -quiet -of $cell -filter {DIRECTION == OUT}] {
      set net [get_nets -quiet -of $pin]
      set fanout 0
      if {$net != {}} {
        set fanout [expr [get_property -quiet FLAT_PIN_COUNT $net] -1]
      } else {
#         set fanout {-}
        # Skip unconnected pins
        continue
      }
      if {$firstPin} {
        $table addrow [list $ref_name $cell [get_property -quiet REF_PIN_NAME $pin] $fanout $net]
        set firstPin 0
      } else {
        $table addrow [list {} {} [get_property -quiet REF_PIN_NAME $pin] $fanout $net]
      }
    }
    incr count
  }
  
  $table configure -title "Fanout Summary ($count)"
  puts [$table print]
  
  puts "\n Found $count instances"

  # Destroy the table object to free memory
  catch {$table destroy}

  return 0
}
