########################################################################################
## 01/09/2015 - Replace comma by semi-colon inside cell value inside CSV to prevent
##              confusion with CSV delimiter
## 07/16/2014 - Fixed wrong message being reported when a synchronizer is missing
##            - Added support for -all_issues to report all issues found for each
##              CDC path
##            - Changed ports direction to upper case
## 02/04/2014 - Renamed file and various additional updates for Tcl App Store
## 02/03/2014 - Updated the namespace and definition of the command line arguments
##              for the Tcl App Store
## 09/16/2013 - Added meta-comment 'Categories' to all procs
## 09/13/2013 - Fixed typo in processing -report_unconstrained
## 09/11/2013 - Re-added generation of CSV files
## 09/10/2013 - Better support for virtual clocks
##            - Rename -report_false_path to -report_unconstrained
##            - Minor updates
## 09/09/2013 - Added support for -file/-append/-return_string
##            - Moved code in a private namespace
##            - Removed errors from linter (lint_files)
## 09/06/2013 - Initial release based on create_cdc_reports.tcl version 1.7 
##              (John Bieker, Sergei Storojev)
##            - Removed dependency to CdcUtil.tcl
##            - Reformated output and removed CSV files
########################################################################################

namespace eval ::tclapp::xilinx::ultrafast {
  namespace export create_cdc_reports

}

proc ::tclapp::xilinx::ultrafast::create_cdc_reports { args } {
  # Summary: Create CDC report for each clock-pair in the design

  # Argument Usage:
  # [-max_paths <arg> = 1]: Maximum number of paths to output
  # [-nworst <arg> = 1]: List up to N worst paths to endpoint
  # [-delay_type <arg> = max]: Type of path delay: Values max, min, min_max
  # [-report_unconstrained]: Report timing on unconstrained paths
  # [-all_issues]: Report all issues found for each CDC path
  # [-file <arg>]: Report file name
  # [-append]: Append to file
  # [-return_string]: Return report as string
  # [-usage]: Usage information

  # Return Value:
  # return report if -return_string is used, otherwise 0. If any error occur TCL_ERROR is returned

  # Categories: xilinxtclstore, ultrafast

  uplevel [concat ::tclapp::xilinx::ultrafast::create_cdc_reports::create_cdc_reports $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::ultrafast::create_cdc_reports { 
  variable version {01/09/2015}
} ]

# -------------------------------------------------------------------------
# Target device : Any family
#
# Description : 
#   Create CDC report for each clock-pair in the design
# 
# Assumptions :
#   - Vivado 2012.4
#
# -------------------------------------------------------------------------
#
# Calling syntax:
#   source <your_Tcl_script_location>/create_cdc_reports.tcl
#
# -------------------------------------------------------------------------
# Author  : John Bieker, Xilinx 
# Revison : 1.0 - initial release
# Revison : 1.1 - added -nworst switch
#    - added logic levels, path requirement, clock skew cols to report
#         : 1.2 - added clock interaction report parser proc (Sergei Storojev)
#    - consolidated output to 2 csv files (CommonPrimaryClock.csv, NotCommonPrimaryClock.csv)
#    : 1.3 - moved helper procs to cdcUtil.tcl
#    - added cdc rules checking from cdcUtil.tcl
#    : 1.4 - table parsing bug fixes
#    : 1.5 - new table parser (Sergei)
#    : 1.6 - added synchronizer checker for basic synchronizer
#    : 1.7 - added status & comment fields to CDC report
################################################################################
# PROC CREATE_CDC_REPORTS
################################################################################

# ========================================================================================================
#
# This procedure checks the connectivity of a flop to determine if the clock enable is tied to VCC
# and the reset signal (set/reset/preset/clear) is tied to GND.  This procedure is looking for a very
# specific configuration of a synchronizer flip flop:  two back-to-back FD flops with enable/reset tied off.
# A more robust detection requires significantly longer runtime due to frequent calls of get_timing
# ========================================================================================================

proc ::tclapp::xilinx::ultrafast::create_cdc_reports::check_synchronizer_connectivity {cell} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, ultrafast

  set enable_vcc ""
  set set_or_reset_gnd ""
  set celltype [get_property -quiet REF_NAME [get_cells -quiet $cell]]
  foreach pin [get_pins -quiet -filter {DIRECTION==IN} -of [get_cells -quiet $cell]] {
    if {[get_property -quiet IS_ENABLE $pin] == 1} {set enable_vcc [get_property -quiet LOGIC_VALUE $pin]};
    if {$celltype == "FDPE" || $celltype == "FDSE"} {
      if {[get_property -quiet IS_SETRESET $pin] == 1} {set set_or_reset_gnd [get_property -quiet LOGIC_VALUE $pin]}
    }
    if {$celltype == "FDCE" || $celltype == "FDRE"} {
      if {[get_property -quiet IS_RESET $pin] == 1} {set set_or_reset_gnd [get_property -quiet LOGIC_VALUE $pin]}
    }
  }
  if {$enable_vcc == "one" && $set_or_reset_gnd == "zero"} {
    return 1
  } else {
    return 0
  }

}

#**********************************************************************************#
# #******************************************************************************# #
# #                                                                              # #
# #                         M A I N   P R O G A M                                # #
# #                                                                              # #
# #******************************************************************************# #
#**********************************************************************************#

proc ::tclapp::xilinx::ultrafast::create_cdc_reports::create_cdc_reports {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, ultrafast

  #-------------------------------------------------------
  # Process command line arguments
  #-------------------------------------------------------
  set error 0
  set options(-nworst) 1
  set options(-max_paths) 10
  set options(-delay_type) max
  set options(-report_unconstrained) {No}
  set options(-all_issues) 0
  set verbose 0
  set filename {}
  set mode {w}
  set returnString 0
  set help 0
  while {[llength $args]} {
    set name [[namespace parent]::lshift args]
    switch -regexp -- $name {
      -max_paths -
      {^-m(a(x(_(p(a(t(hs?)?)?)?)?)?)?)?$} {
           set options(-max_paths) [[namespace parent]::lshift args]
      }
      -nworst -
      {^-n(w(o(r(st?)?)?)?)?$} {
           set options(-nworst) [[namespace parent]::lshift args]
      }
      -delay_type -
      {^-d(e(l(a(y(_(t(y(pe?)?)?)?)?)?)?)?)?$} {
           set options(-delay_type) [[namespace parent]::lshift args]
      }
      -report_unconstrained -
      {^-rep((o(r(t(_(u(n(c(o(n(s(t(r(a(i(n(ed?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?$} {
           set options(-report_unconstrained) {Yes}
      }
      -all_issues -
      {^-al(l(_(i(s(s(u(es?)?)?)?)?)?)?)?$} {
           set options(-all_issues) 1
      }
      -file -
      {^-f(i(le?)?)?$} {
           set filename [[namespace parent]::lshift args]
           if {$filename == {}} {
             puts " -E- no filename specified."
             incr error
           }
      }
      -append -
      {^-ap(p(e(nd?)?)?)?$} {
           set mode {a}
      }
      -return_string -
      {^-ret(u(r(n(_(s(t(r(i(ng?)?)?)?)?)?)?)?)?)?$} {
           set returnString 1
      }
      -verbose -
      {^-v(e(r(b(o(se?)?)?)?)?)?$} {
           set verbose 1
      }
      -usage -
      {^-u(s(a(ge?)?)?)?$} -
      -help -
      {^-h(e(lp?)?)?$} {
           set help 1
      }
      ^--version$ {
           variable version
           return $version
      }
      default {
            if {[string match "-*" $name]} {
              puts " -E- option '$name' is not a valid option."
              incr error
            } else {
              puts " -E- option '$name' is not a valid option."
              incr error
            }
      }
    }
  }

  if {$help} {
    puts [format {
  Usage: create_cdc_reports
              [-max_paths <arg>]          - Maximum number of paths to output
                                            Default: 1
              [-nworst <arg>]             - List up to N worst paths to endpoint
                                            Default: 1
              [-delay_type <arg>]         - Type of path delay: Values max, min, min_max
                                            Default: max
              [-all_issues]               - Report all issues found for each CDC path
                                            Default: report only the first issue
              [-report_unconstrained]     - Report timing on unconstrained paths
              [-file]                     - Report file name
              [-append]                   - Append to file
              [-verbose]                  - Verbose mode
              [-return_string]            - Return report as string
              [-usage|-u]                 - This help message

  Description: Create CDC report for each clock-pair in the design

     This command must be run on a synthesized or implemented design.

  Example:
     create_cdc_reports
     create_cdc_reports -report_unconstrained -delay_type min_max -file myreport.rpt
} ]
    # HELP -->
    return {}
  }
  
  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }
  
  set tableReport [[namespace parent]::Table::Create {CDC Report}]
  set tableSummary [[namespace parent]::Table::Create {CDC Summary}]
  $tableReport header [list {Status} {Comment} {Source Clock} {Dest Clock} {Delay Type} {Common Primary Clock} {Simple Synchronizer Detected} {Timing Exception} {Logic Levels} {Path Req} {Clock Skew} {Slack Value} {Startpoint Cell Type} {Endpoint Cell Type} {Startpoint Pin} {Endpoint Pin}]
  $tableSummary header [list {Source Clock} {Dest Clock} {Reported Endpoints}]

  set startTime [clock seconds]
  set Version [version -short]
  set output [list]

  set clock_interaction_report [report_clock_interaction -quiet -setup -return_string]
  set clock_interaction_table [[namespace parent]::Parse::report_clock_interaction $clock_interaction_report]
  set tableClockInteraction [[namespace parent]::Table::Create]
  $tableClockInteraction title "Clock Interaction Summary"
  $tableClockInteraction header [list "From clock" "To Clock" "Common Primary Clock" "Inter-Clock Constraints"]
  set colFromClock 0
  set colToClock 0
  set colCommonPrimaryClock 0
  set colInterClockConstraints 0
  if {$clock_interaction_table != {}} {
    set header [lindex $clock_interaction_table 0]
    for {set i 0} {$i < [llength $header]} {incr i} {
#       puts "<$i:[lindex $header $i]>"
      switch -nocase [lindex $header $i] {
        "From Clock" {
          set colFromClock $i
        }
        "To Clock" {
          set colToClock $i
        }
        "Common Primary Clock" {
          set colCommonPrimaryClock $i
        }
        "Inter-Clock Constraints" {
          set colInterClockConstraints $i
        }
        default {
        }
      }
    }
#     puts "<colFromClock:$colFromClock><colToClock:$colToClock><colCommonPrimaryClock:$colCommonPrimaryClock><colInterClockConstraints:$colInterClockConstraints>"
    foreach row [lrange $clock_interaction_table 1 end] {
      set fromClock [lindex $row $colFromClock]
      set toClock [lindex $row $colToClock]
      set commonPrimaryClock [lindex $row $colCommonPrimaryClock]
      set interClockConstraints [lindex $row $colInterClockConstraints]
      set clockInteraction(${fromClock}:${toClock}) $interClockConstraints
      $tableClockInteraction addrow [list $fromClock $toClock $commonPrimaryClock $interClockConstraints]
#       puts "<fromClock:$fromClock><toClock:$toClock><commonPrimaryClock:$commonPrimaryClock><interClockConstraints:$interClockConstraints>"
    }
  }
  
  # Creation of CSV files
  set CSV_SUMMARY_FILENAME "cdc_summary_[clock format $startTime -format %m_%d_%y_%I_%M_%S].csv"
  set CSVTotFile [open $CSV_SUMMARY_FILENAME a]
  puts $CSVTotFile "Source Clock,Dest Clock,Reported Endpoints"
  set CSV_REPORT_FILENAME "cdc_report_[clock format $startTime -format %m_%d_%y_%I_%M_%S].csv"
  set CSVRptFile [open $CSV_REPORT_FILENAME a]
  puts $CSVRptFile "Status,Comment,Source Clock,Dest Clock,Delay Type,Common Primary Clock,Simple Synchronizer Detected,Timing Exception,Logic Levels,Path Req,Clock Skew,Slack Value,Startpoint Cell Type,Endpoint Cell Type,Startpoint Pin,Endpoint Pin"

  # Iterate through each row of the clock interaction table (not including the header)
  foreach row [lrange $clock_interaction_table 1 end] {
    set fromClock [lindex $row $colFromClock]
    set toClock [lindex $row $colToClock]
    set interClockConstraints [lindex $row $colInterClockConstraints]
    set commonPrimaryClock [lindex $row $colCommonPrimaryClock]

    if {$fromClock == $toClock} {
      # Only look at inter-clock paths
      lappend output " Skipping from $fromClock to $toClock$toClock (intra clock domain)"
      continue
    }
    if {[regexp -nocase {Asynchronous Groups} $interClockConstraints]} {
      # Skip asynchronous groups
      lappend output " Skipping from $fromClock to $toClock$toClock (asynchronous groups)"
      continue
    }
    if {!$verbose} {
      # Virtual clocks are only skipped in non-verbose mode
      if {[get_property -quiet IS_VIRTUAL [get_clocks $fromClock]]} {
        # Skip virtual clocks
        lappend output " Skipping virtual clock $fromClock (use -verbose to keep virtual clocks)"
        continue
      }
      if {[get_property -quiet IS_VIRTUAL [get_clocks $toClock]]} {
        # Skip virtual clocks
        lappend output " Skipping virtual clock $toClock (use -verbose to keep virtual clocks)"
        continue
      }
    }
    
    if {[regexp -nocase "Yes" $options(-report_unconstrained)]} {
      set timing_path_list [get_timing_paths -quiet -from $fromClock -to $toClock -delay_type $options(-delay_type) -max_paths $options(-max_paths) -nworst $options(-nworst)]
    } else {
      set timing_path_list [get_timing_paths -quiet -from $fromClock -to $toClock -no_report_unconstrained -delay_type $options(-delay_type) -max_paths $options(-max_paths) -nworst $options(-nworst)]
    }
    set total_endpoints [llength $timing_path_list]
    if {$verbose} {
#       lappend output "**********************************************************************************************"
#       lappend output "CDC From ${fromClock} To ${toClock}"
#       lappend output "Endpoints Reported = ${total_endpoints}"
#       lappend output "Delay Type = ${options(-delay_type)}"
#       lappend output "**********************************************************************************************"
    }
    # Saving information inside CSV and Table object
    puts $CSVTotFile "$fromClock,$toClock,$total_endpoints"
    $tableSummary addrow [list $fromClock $toClock $total_endpoints]
    if {$total_endpoints != 0} {
      report_timing -from $fromClock -to $toClock -quiet -delay_type $options(-delay_type) -max_paths 1 -name "${fromClock}_to_${toClock}"
    }
    foreach timing_path $timing_path_list {
      set cdcRpt [list]
#       set commonPrimaryClock $common_primary(${fromClock},${toClock})
      ### Xilinx:jjb - note that the "EXCEPTION" property is not defined until 2013.1 timeframe
      if {[regexp "2012" $Version]} {
        set exception "NA"
      } else {
        set exception [get_property -quiet EXCEPTION $timing_path]
      }
      set logiclevels [get_property -quiet LOGIC_LEVELS $timing_path]
      set pathreq [get_property -quiet REQUIREMENT $timing_path]
      set skew [get_property -quiet SKEW $timing_path]
      set slack [get_property -quiet SLACK $timing_path]
      set startpointpin [get_property -quiet STARTPOINT_PIN $timing_path]
      set endpointpin [get_property -quiet ENDPOINT_PIN $timing_path]
      set startpointcell [get_cells -quiet -of $startpointpin]
      set endpointcell [get_cells -quiet -of $endpointpin]
      set startpointcelltype [get_property -quiet REF_NAME [get_cells -quiet -of $startpointpin]]
      set endpointcelltype [get_property -quiet REF_NAME [get_cells -quiet -of $endpointpin]]
      set simple_synchronizer_detected "No"
      if {[regexp "FD" $endpointcelltype]} {
        set meta_ff_check [check_synchronizer_connectivity $endpointcell]
        #set meta_ff_check [check_synchronizer_connectivity2 $endpointcell $toClock 2]
        set output_net [get_nets -quiet -of [get_pins -quiet -filter {DIRECTION==OUT} -of [get_cells -quiet -of $endpointpin]]]
        set output_net_fanout [get_property -quiet FLAT_PIN_COUNT $output_net]
        if {$output_net_fanout == 2} {
          set next_input_pin [get_pins -quiet -leaf -filter {DIRECTION==IN} -of [get_nets -quiet $output_net]]
          set next_input_pin_is_set [get_property -quiet IS_SETRESET $next_input_pin]
          set next_input_pin_is_reset [get_property -quiet IS_RESET $next_input_pin]
          set next_input_pin_is_enable [get_property -quiet IS_ENABLE $next_input_pin]
          set next_input_pin_is_clock [get_property -quiet IS_CLOCK $next_input_pin]
          set next_cell [get_cells -quiet -of [get_pins -quiet -leaf -filter {DIRECTION==IN} -of [get_nets -quiet $output_net]]]
          set synch_ff_check [check_synchronizer_connectivity $next_cell]
          #set synch_ff_check [check_synchronizer_connectivity2 $next_cell $toClock 2]
          set next_input_celltype [get_property -quiet REF_NAME [get_cells -quiet -of [get_pins -quiet $next_input_pin]]]
          set next_input_clock [get_clocks -quiet -of [get_pins -quiet -filter {IS_CLOCK == 1} -of [get_cells -quiet -of [get_pins -quiet $next_input_pin]]]]
          if {[regexp "FD" $next_input_celltype] \
               && $output_net_fanout ==2 \
               && $next_input_clock==$toClock \
               && $next_input_pin_is_clock == 0 \
               && $next_input_pin_is_enable == 0 \
               && $next_input_pin_is_set == 0 \
               && $next_input_pin_is_reset == 0 \
               && $meta_ff_check == 1 \
               && $synch_ff_check == 1} {
              set simple_synchronizer_detected "Yes"
          }
        }
      }
      set status ""
      set comment ""
      if {($startpointcelltype == "") || ($endpointcelltype == "")} {
        set status "Ok"
        set comment "I/O Timing Path"
        lappend cdcRpt [list {Ok} {I/O Timing Path}]
      } else {
        if {$commonPrimaryClock == "Yes"} {
          if {$pathreq < 1.000} {
            lappend cdcRpt [list {Check} {Common Primary Clock; Tight Path Requirement}]
            set status "Check"
                  set comment "Common Primary Clock; Tight Path Requirement"
          } else {
            lappend cdcRpt [list {Ok} {Common Primary Clock}]
            set status "Ok"
                  set comment "Common Primary Clock"
          }
        } else {
          if {[regexp "SRL" $endpointcelltype]} {
            lappend cdcRpt [list {Check} {Endpoint Cell is SRL}]
            set status "Check"
            set comment "Endpoint Cell is SRL"
          } else {
            if {$simple_synchronizer_detected == "Yes"} {
             if {$logiclevels != 0} {
               lappend cdcRpt [list {Check} {Why are there > 0 levels of logic on CDC path?}]
               set status "Check"
               set comment "Why are there > 0 levels of logic on CDC path?" 
             } else {
               lappend cdcRpt [list {Ok} {Simple Synchronizer Detected}]
               set status "Ok"
               set comment "Simple Synchronizer Detected"
             }
           } else {
             lappend cdcRpt [list {Check} {Missing synchronizer}]
             set status "Check"
             set comment "Missing synchronizer" 
             if {$logiclevels != 0} {
               lappend cdcRpt [list {Check} {Why are there > 0 levels of logic on CDC path?}]
               set status "Check"
               set comment "Why are there > 0 levels of logic on CDC path?" 
             } 
             if {$meta_ff_check == 0} {
               lappend cdcRpt [list {Check} {Why aren't the control signals (CE/RST) tied off on synchronizer?}]
               set status "Check"
               set comment "Why aren't the control signals (CE/RST) tied off on synchronizer?" 
             } 
           }
          }
        }
      }

      # Saving information inside CSV and Table object
      if {$options(-all_issues)} {
        foreach elm $cdcRpt {
          foreach {status comment} $elm { break }
          puts $CSVRptFile "$status,$comment,$fromClock,$toClock,${options(-delay_type)},$commonPrimaryClock,$simple_synchronizer_detected,$exception,$logiclevels,$pathreq,$skew,$slack,$startpointcelltype,$endpointcelltype,$startpointpin,$endpointpin"
          $tableReport addrow [list $status $comment $fromClock $toClock ${options(-delay_type)} $commonPrimaryClock $simple_synchronizer_detected $exception $logiclevels $pathreq $skew $slack $startpointcelltype $endpointcelltype $startpointpin $endpointpin]
        }
      } else {
        foreach {status comment} [lindex $cdcRpt 0] { break }
        puts $CSVRptFile "$status,$comment,$fromClock,$toClock,${options(-delay_type)},$commonPrimaryClock,$simple_synchronizer_detected,$exception,$logiclevels,$pathreq,$skew,$slack,$startpointcelltype,$endpointcelltype,$startpointpin,$endpointpin"
        $tableReport addrow [list $status $comment $fromClock $toClock ${options(-delay_type)} $commonPrimaryClock $simple_synchronizer_detected $exception $logiclevels $pathreq $skew $slack $startpointcelltype $endpointcelltype $startpointpin $endpointpin]
      }
    }
  }

  lappend output {}
  set output [concat $output [split [$tableClockInteraction print] \n] ]
  set output [concat $output [split [$tableSummary print] \n] ]
  set output [concat $output [split [$tableReport print] \n] ]

  set endTime [clock seconds]
  set runtime [::tclapp::xilinx::ultrafast::duration [expr $endTime - $startTime]]
  puts "\n Total runtime: $runtime"

  # Closing of CSV files
  close $CSVTotFile
  close $CSVRptFile

  if {$filename !={}} {
    set FH [open $filename $mode]
    puts $FH [::tclapp::xilinx::ultrafast::generate_file_header {create_cdc_reports}]
    puts $FH [join $output \n]
    puts $FH "\n Total runtime: $runtime"
    close $FH
    puts "\n Report file [file normalize $filename] has been generated\n"
  } else {
    puts [join $output \n]
  }

  # Destroy the object
  catch {$tableClockInteraction destroy}
  catch {$tableReport destroy}
  catch {$tableSummary destroy}

  # Return result as string?
  if {$returnString} {
    return [join $output \n]
  }

  return 0
}
