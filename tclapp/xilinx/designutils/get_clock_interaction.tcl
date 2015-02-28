package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export get_clock_interaction
}


proc ::tclapp::xilinx::designutils::get_clock_interaction { from_clock to_clock return_item} {
  # Summary : Return a specific string within the clock interaction report

  # Argument Usage:
  # from_clock : The launching clock name
  # to_clock : The capturing clock name
  # return_item: The entry in the clock interaction report desired for the from_clock and to_clock. The valid values are: from_edge to_edge wns tns tns_end tot_end wns_req common inter_clock

  # Return Value:
  # String of the return_item in the clock interaction report.  NOT_FOUND will be returned if it is not found.

  # Categories: xilinxtclstore, designutils



#
# Assume whatever we are looking for will not be found
#   - could not match clocks
#   - could not find the entry in the line
#
set from_edge "NOT_FOUND"
set to_edge "NOT_FOUND"
set wns "NOT_FOUND"
set tns "NOT_FOUND"
set tns_end "NOT_FOUND"
set tot_end "NOT_FOUND"
set wns_req "NOT_FOUND"
set com "NOT_FOUND"
set inter_clock "NOT_FOUND"
set return_value "NOT_FOUND"
  
    # Collect Info
    set clksection 0
    set rci [report_clock_interaction -quiet -delay_type max -return_string]
    foreach line [split $rci \n] {
        if {[regexp {^--} $line]} { continue }
        if {[regexp {^\s+$} $line]} { continue }
        if {[regexp {^From Clock\s+To Clock} $line]} { set clksection 1; continue }
        if {$clksection == 0} { continue }

	if {[regexp {^(\S+)\s+(\S+)\s+\S+} $line dum from to] } {
          if { ($from_clock eq $from) && ($to_clock eq $to) } {
            set found_entry $line
            #DEBUG puts "Found Matching Line:"
            #DEBUG puts "\t$found_entry"
	    set found_entry [string trimright $found_entry]
	    #DEBUG puts "\t#${found_entry}#"
	  }
	}
    }

    
    if {[info exists found_entry] && [regexp {^(.*)\s+(Yes|No)\s+(.*)} $found_entry dum firstpart com inter_clock] } {

      #DEBUG puts "Found Common Primary Clock and Inter-Clock Constraints"
      #DEBUG puts "\tDummy: $dum"
      #DEBUG puts "\tFirst Part: $firstpart" 
      #DEBUG puts "\tCommon Primary Clock: $common"
      #DEBUG puts "\tInter-Clock Constraints: $inter_clock"
       
      set found_entry [regsub -all {\s+} $found_entry ,]


      ##
      ## based on the inter_clock value, can figure out how to parse the line
      ##
      if { $inter_clock=="False Path" || $inter_clock=="Exclusive Groups" || $inter_clock=="Asynchronous Groups" } {
         set split_entry [split $found_entry ","]
         lassign $split_entry \
                 from to tns_end tot_end com inter_clock_dum_csv
      } elseif { $inter_clock=="Timed" || $inter_clock=="Timed (unsafe)" || $inter_clock=="Partial False Path" || $inter_clock=="Max Delay Datapath Only" } {
         set split_entry [split $found_entry ","]
	 lassign $split_entry \
	         from to from_edge dum to_edge wns tns tns_end tot_end wns_req com inter_clock_dum_csv
      } else {
         puts "ERROR: found entry, but get_clock_interaction does not recognize the interaction in the report"
	 puts "ERROR: script likely needs updated, NOT_FOUND will be returned"
	#DEBUG puts "inter_clock is: ${inter_clock}#"
      }


      switch $return_item {
        "from_edge" {set return_value $from_edge}
        "to_edge" {set return_value $to_edge}
        "wns" {set return_value $wns}
        "tns" {set return_value $tns}
        "tns_end" {set return_value $tns_end}
        "tot_end" {set return_value $tot_end}
        "wns_req" {set return_value $wns_req}
        "common" {set return_value $com}
        "inter_clock" {set return_value $inter_clock}
	default { puts "ERROR: return_item argument is likely invalid, NOT_FOUND will be returned" }
      }
    } else {
      puts "could not find the entry, NOT_FOUND will be returned"
    }
      
return $return_value

}
