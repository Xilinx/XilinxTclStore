package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export highlight_enable_signal_sites
}

proc ::tclapp::xilinx::designutils::highlight_enable_signal_sites {} {
  # Summary : Highlight the destination sites of the enable signals reported by report_control_set command

  # Argument Usage:

  # Return Value:
  # 0

  # Categories: xilinxtclstore, designutils

  # Generate the report
  set report [report_control_set -verbose -return_string]

  # Use a state machine to parse the content of the report
  set SM {header}
  # List of all the Enable Signal nets found in the report
  set allEnableSignalsNets [list]
  foreach line [split $report \n] {
    switch $SM {
      header {
        # Search for the header of the table 'Detailed Control Set Information'
        if {[regexp -nocase {Clock Signal.+Enable Signal} $line]} {
          set SM {skip1}
        }
      }
      skip1 {
        # This allows us to skip 1 line after the header, i.e '+-----+-------+--- ...' 
        set SM {table}
      }
      table {
        # End of the table?
        if {[regexp {^\s*\+\-+} $line]} {
          set SM {footer}
          continue
        }
        # The body of the table is processed here
        set enableSignalName [string trim [lindex [split $line {|}] 2]]
        if {$enableSignalName == {}} {
          # No Enable Signal name, skip
          continue
        }
        set enableSignalNet [get_nets -quiet $enableSignalName]
        if {$enableSignalNet == {}} {
          puts " -E- no such net found in design : $enableSignalName"
          continue
        }
        lappend allEnableSignalsNets $enableSignalNet
      }
      footer {
        # nothing to be done, the table has already been processed
      }
    }
  }
  
  # Remove duplicate entries
  set allEnableSignalsNets [lsort -unique $allEnableSignalsNets]
  
  set usedSites [list]
  foreach net $allEnableSignalsNets {
    set cellList [get_cells -quiet -of [get_pins -quiet -leaf -of $net -filter {DIRECTION == IN}]]
    if {$cellList == {}} {
      puts " -E- no input pin connected to net $net"
      continue
    }
    foreach cell $cellList site [get_property -quiet SITE $cellList] {
      if {$site == {}} {
        puts " -W- unplaced cell: $cell"
      } else {
        lappend usedSites $site
      }
    }
  }
  # Uniquify the list of sites
  set usedSites [lsort -unique $usedSites]
  puts " Number of sites to highlight: [llength $usedSites]"
  highlight_objects -color yellow $usedSites
  return 0
}
