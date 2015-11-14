package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export report_critical_hfn
}

proc ::tclapp::xilinx::designutils::report_critical_hfn {{sortBy slack} {limitFanout 256} {limitSlack 0}} {
  # Summary : Report timing critical high fanout nets based on fanout and slack
  
  # Argument Usage:
  # sortBy : Sorting critierion. Valid values: slack (default), fanout
  # limitFanout : Fanout limit. Only report nets with this fanout or more (default: 256)
  # limitSlack : Slack limit. Only report nets with this slack or less (default: 0)

  # Return Value:
  # 0
  # TCL_ERROR if an error happened
  
  # Categories: xilinxtclstore, designutils

  if {[string tolower $sortBy] != {slack} && [string tolower $sortBy] != {fanout}} {
    error " error - unknown sortBy value"
  }

  # Initialize the table objects
  set table [::tclapp::xilinx::designutils::prettyTable create "Summary of Critical Nets\nFanout Limit: $limitFanout\nSlack Limit: $limitSlack"]
  $table header {Net Fanout Slack}

  # Build the list of net/fanout/slack
  set listNets [list]
  foreach net [get_nets -hierarchical -filter [format {(FLAT_PIN_COUNT >= %s) && (TYPE != GLOBAL_CLOCK)} $limitFanout]] {
    set driver [get_pins -leaf -of $net -filter {DIRECTION == OUT}]
    set slack [get_property SETUP_SLACK $driver]
    set fanout [get_property FLAT_PIN_COUNT $net]
    if {$slack > $limitSlack} {
      continue
    }
    lappend listNets [list $net $fanout $slack]
  }

  # Sort the list
  if {$sortBy == "slack"} {
    set listNets [lsort -increasing -real -index 2 $listNets]
  } else {
    set listNets [lsort -decreasing -integer -index 1 [lsort -increasing -real -index 2 $listNets] ]
  }

  # Build & print the table
  foreach el $listNets {
    $table addrow $el
  }
  puts [$table print]
  puts " Found [$table numrows] critical high fanout nets"

  # Destroy the table objects to free memory
  catch {$table destroy}

  return 0
}

