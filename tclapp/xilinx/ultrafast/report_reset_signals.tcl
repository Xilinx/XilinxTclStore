
########################################################################################
## 02/02/2015 - Added support for latest property pins (IS_SET/...)
## 01/13/2015 - Fixed typo in command line option for -setreset 
##            - Fixed bug where the Common Primary Clock was not properly retreived
##              from the clock interaction report
## 02/04/2014 - Renamed file and various additional updates for Tcl App Store 
## 02/03/2014 - Updated the namespace and definition of the command line arguments 
##              for the Tcl App Store
## 09/16/2013 - Added meta-comment 'Categories' to all procs
## 09/13/2013 - Replaced property name LIB_CELL with REF_NAME
## 09/11/2013 - Changed command name from report_ctrl_signals to report_reset_signals
##            - Added support for -all
##            - Changed the way clocks are found synchronous/asynchronous
##            - Reorganized table columns
##            - Various updates
## 09/09/2013 - Added support for -file/-append/-return_string
##            - Moved code in a private namespace
##            - Removed errors from linter (lint_files)
## 09/06/2013 - Major changes to support all the type of control signals
##            - Code re-organization
## 08/27/2013 - Initial release based on clockLoads version 1.0 (Greg O'Bryant)
########################################################################################

namespace eval ::tclapp::xilinx::ultrafast {
  namespace export report_reset_signals

}

proc ::tclapp::xilinx::ultrafast::report_reset_signals { args } {
  # Summary: Generate Report for Control Signals (Reset/Set/Clear/Preset)

  # Argument Usage:
  # [-all]: Analyze all control pins
  # [-reset]: Analyze reset control pins (default)
  # [-clear]: Analyze clear control pins
  # [-set]: Analyze set control pins
  # [-preset]: Analyze preset control pins
  # [-setreset]: Analyze setreset control pins
  # [-verbose]: Verbose mode
  # [-file <arg>]: Report file name
  # [-append]: Append to file
  # [-return_string]: Return report as string
  # [-usage]: Usage information

  # Return Value:
  # return report if -return_string is used, otherwise 0. If any error occur TCL_ERROR is returned

  # Categories: xilinxtclstore, ultrafast

  uplevel [concat ::tclapp::xilinx::ultrafast::report_reset_signals::report_reset_signals $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::ultrafast::report_reset_signals { 
  variable version {02/02/2015}
} ]

## ---------------------------------------------------------------------
## Description
##    Procedure "lint_async_reset_deasertion" searches for synchronous primitives
##    with an asynchronous set or reset net and the net is driven asynchronously
##    to the destination primitive. This procedure can be executed with
##    the post synthesis netlist (checkpoint) or post implementation netlist
##    (checkpoint) loaded.
##    The linting results are directed to stdio.
## Author: Greg O'Bryant
## Version Number: 1.0
## Version Change History
## Version 1.0 - Initial release
## ---------------------------------------------------------------------

proc ::tclapp::xilinx::ultrafast::report_reset_signals::areClocksSynchronous { clock1 clock2 _clockInteraction } {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, ultrafast

  upvar 1 $_clockInteraction clockInteraction
  set clock1 [[namespace parent]::lflatten $clock1]
  set clock2 [[namespace parent]::lflatten $clock2]
  if {($clock1 == {}) || ($clock2 == {})} {
    return 0
  }
  # Are both list of clock(s) synchronous (= timed together)?
  set async 0
  foreach c1 [lsort -unique $clock1] {
    foreach c2 [lsort -unique $clock2] {
#       if {![regexp -nocase {^Timed$} $clockInteraction(ICC:${c1}:${c2})]} {}
      # Checking the Common Primary Clock information between the 2 clocks
      if {![regexp -nocase {^Yes$} $clockInteraction(CPC:${c1}:${c2})]} {
        # If a single pair of start and destination clock domains are asynchronous,
        # then stop
        set async 1
        break
      }
    }
  }
  if {$async} {
    return 0
  } else {
    return 1
  }
}

proc ::tclapp::xilinx::ultrafast::report_reset_signals::report_reset_signals { args } {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, ultrafast

  #-------------------------------------------------------
  # Process command line arguments
  #-------------------------------------------------------
  set error 0
  set filename {}
  set mode {w}
  set verbose 0
  set debug 0
  set ctrlSignalType 0
  set returnString 0
  set help 0
  while {[llength $args]} {
    set name [[namespace parent]::lshift args]
    switch -regexp -- $name {
      -reset -
      {^-res(et?)?$} {
           set ctrlSignalType [expr $ctrlSignalType | 2]
      }
      -preset -
      {^-p(r(e(s(et?)?)?)?)?$} {
           set ctrlSignalType [expr $ctrlSignalType | 4]
      }
      -clear -
      {^-c(l(e(ar?)?)?)?$} {
           set ctrlSignalType [expr $ctrlSignalType | 8]
      }
      -setreset -
      {^-setr(e(s(et?)?)?)?$} {
           set ctrlSignalType [expr $ctrlSignalType | 16]
      }
      -set -
      {^-set?$} {
           set ctrlSignalType [expr $ctrlSignalType | 32]
      }
      -all -
      {^-a(ll?)?$} {
           set ctrlSignalType [expr $ctrlSignalType | 64]
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
      {^-a(p(p(e(nd?)?)?)?)?$} {
           set mode {a}
      }
      -verbose -
      {^-v(e(r(b(o(se?)?)?)?)?)?$} {
           set verbose 1
      }
      -return_string -
      {^-ret(u(r(n(_(s(t(r(i(ng?)?)?)?)?)?)?)?)?)?$} {
           set returnString 1
      }
      -usage -
      {^-u(s(a(ge?)?)?)?$} -
      -help -
      {^-h(e(lp?)?)?$} {
           set help 1
      }
      ^-debug$ {
           set debug 1
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
  Usage: report_reset_signals
              [-all|-reset|-set|-preset|-clear|-setreset]          
                                     - Control pins to analyze
                                       Default: reset
              [-file]                - Report file name
              [-append]              - Append to file
              [-verbose]             - Verbose mode
              [-return_string]       - Return report as string
              [-usage|-u]            - This help message

  Description: Reports Information about Reset/Clear/Preset/SetPreset Pins

     This command reports detailed infromation about the control signals.

     This command must be run on a synthesized or implemented design.

  Example:
     report_reset_signals -set
     report_reset_signals -verbose -file myreport.rpt -append
} ]
    # HELP -->
    return {}
  }
  
  switch $ctrlSignalType {
    0 -
    2 {
      set ctrlPins [get_pins -quiet -filter {IS_RESET} -of_object [get_cells -hierarchical * -filter {IS_PRIMITIVE && IS_SEQUENTIAL}]]
      set ctrlName {Reset}
    }
    4 {
      set ctrlPins [get_pins -quiet -filter {IS_PRESET} -of_object [get_cells -hierarchical * -filter {IS_PRIMITIVE && IS_SEQUENTIAL}]]
      set ctrlName {Preset}
    }
    8 {
      set ctrlPins [get_pins -quiet -filter {IS_CLEAR} -of_object [get_cells -hierarchical * -filter {IS_PRIMITIVE && IS_SEQUENTIAL}]]
      set ctrlName {Clear}
    }
    16 {
      set ctrlPins [get_pins -quiet -filter {IS_SETRESET} -of_object [get_cells -hierarchical * -filter {IS_PRIMITIVE && IS_SEQUENTIAL}]]
      set ctrlName {SetReset}
    }
    32 {
      set ctrlPins [get_pins -quiet -filter {IS_SET} -of_object [get_cells -hierarchical * -filter {IS_PRIMITIVE && IS_SEQUENTIAL}]]
      set ctrlName {Set}
    }
    64 {
      set ctrlPins [get_pins -quiet -filter {IS_RESET || IS_PRESET || IS_CLEAR || IS_SETRESET || IS_SET} -of_object [get_cells -hierarchical * -filter {IS_PRIMITIVE && IS_SEQUENTIAL}]]
      set ctrlName {Resets}
    }
    default {
      puts " -E- options -reset/-set/-clear/-setreset/-all are mutually exclusive."
      incr error
    }
  }
  
  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  # Associative array that holds the various tables to be printed
  catch {unset tables}
  # Associative array that holds the count of the number of elements per table
  catch {unset count}
  # Associative array that holds the clock domains information
  catch {unset clockInteraction}

  set tables(clockInteraction) [[namespace parent]::Table::Create]
  $tables(clockInteraction) title "Clock Interaction Summary"
  foreach c1 [get_clocks -quiet] {
    foreach c2 [get_clocks -quiet] {
      set clockInteraction(${c1}:${c2}) {}
    }
  }
  set colFromClock 0
  set colToClock 0
  set colCommonPrimaryClock 0
  set colInterClockConstraints 0
  # Get the table inside the clock interaction report
#   set clock_interaction_report [report_clock_interaction -quiet -delay_type min_max -return_string]
#   set clock_interaction_report [report_clock_interaction -quiet -return_string]
  set clock_interaction_report [report_clock_interaction -quiet -setup -return_string]
  set clock_interaction_table [[namespace parent]::Parse::report_clock_interaction $clock_interaction_report]
  if {$clock_interaction_table != {}} {
    set header [lindex $clock_interaction_table 0]
    for {set i 0} {$i < [llength $header]} {incr i} {
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
    foreach row [lrange $clock_interaction_table 1 end] {
      set fromClock [lindex $row $colFromClock]
      set toClock [lindex $row $colToClock]
      set commonPrimaryClock [lindex $row $colCommonPrimaryClock]
      set interClockConstraints [lindex $row $colInterClockConstraints]
      # CPC: Common Primary Clock
      set clockInteraction(CPC:${fromClock}:${toClock}) $commonPrimaryClock
      # ICC: Inter clock Constraints
      set clockInteraction(ICC:${fromClock}:${toClock}) $interClockConstraints
      $tables(clockInteraction) addrow [list $fromClock $toClock $commonPrimaryClock $interClockConstraints]
    }
  }
  

  set startTime [clock seconds]
  catch {unset cache}
  set output [list]
  set count(portDriven) 0
  set count(asynchronous) 0
  set count(synchronous) 0
  set count(diffClkDomain) 0
  set count(sameClkDomain) 0
  set count(unconnected) 0
  set count(tiedPower) 0
  set count(tiedGround) 0
  set count(multiDrivers) 0
  set count(missingClock) 0
  set count(combDriver) 0
  # Create the various tables
  set tables(portDriven) [[namespace parent]::Table::Create]
  set tables(asynchronous) [[namespace parent]::Table::Create]
  set tables(synchronous) [[namespace parent]::Table::Create]
  set tables(diffClkDomain) [[namespace parent]::Table::Create]
  set tables(sameClkDomain) [[namespace parent]::Table::Create]
  set tables(unconnected) [[namespace parent]::Table::Create]
  set tables(tiedPower) [[namespace parent]::Table::Create]
  set tables(tiedGround) [[namespace parent]::Table::Create]
  set tables(multiDrivers) [[namespace parent]::Table::Create]
  set tables(missingClock) [[namespace parent]::Table::Create]
  set tables(summaryControlNets) [[namespace parent]::Table::Create]
  set tables(combDriver) [[namespace parent]::Table::Create]

  # Cases that need to be covered:
  #  Note: the reset/clock startpoint is/are the startpoint(s) returned by 'all_fanin -flat -startpoint_only <resetPin|clockPin>'
  #  1) Control pin unconnected
  #  2) Control pin connected to power/ground nets
  #  3) Control startpoint is the output of a combinational cell that has all its inputs tied to power/ground
  #  4) Multiple reset startpoints
  #  5) Control startpoint is a primary port
  #  6) Control startpoint is the output of a sequential cell with multiple clock pins
  #  7) Clock pin of the flip-flop unconnected
  #  9) Clock pin of the flip-flop connected to power/ground nets
  # 10) Clock pin of the flip-flop receives multiple clock objects
  # 11) The flip-flop has multiple clock pins
  # 12) The flip-flop has multiple reset pins
  # 13) No clock defined on the flip-flop clock pin
  # 14) No clock defined on the sequential element driving the reset pin

  lappend output "********************************************************************"
  lappend output ""
  lappend output "List of primitives with asynchronous set or reset without a synchronous deasertion:"
  lappend output ""

  set ctrlNets [list]
  set ctrlNameLC [string tolower $ctrlName]
  foreach ctrlPin $ctrlPins {
# # Progress bar
# progressBar $count [llength $cells]
    set cell [get_cell -quiet -of $ctrlPin]
    set cellType [get_property -quiet REF_NAME $cell]
    set ctrlNet [get_nets -quiet -of_object $ctrlPin]

    if {[llength $ctrlNet] == 0} {
      # Control pin is unconnected
      $tables(unconnected) addrow [list $cellType $ctrlPin "unconnected $ctrlNameLC pin"]
      incr count(unconnected)
      continue
    }

    # Keep a list of all the control nets
    lappend ctrlNets $ctrlNet

    # Check if the control net has already been cached
    if {![info exists cache($ctrlNet)]} {
      set cache($ctrlNet) 1
      set cache(ctrlDriverLibCell:$ctrlNet) [get_property -quiet REF_NAME [get_cells -quiet -of [get_pins -quiet -of $ctrlNet -leaf -filter {DIRECTION == OUT}]]]
      set cache(ctrlDriverFanout:$ctrlNet) [expr [get_property -quiet FLAT_PIN_COUNT $ctrlNet] -1]
      set cache(ctrlNetType:$ctrlNet) [string tolower [get_property -quiet TYPE $ctrlNet]]
      set cache(ctrlStartPins:$ctrlNet) [all_fanin -quiet -flat -startpoints_only $ctrlNet]
      set cache(ctrlStartClocks:$ctrlNet) [get_clocks -quiet -of $cache(ctrlStartPins:$ctrlNet)]
      set cache(ctrlStartCells:$ctrlNet) [get_cells -quiet -of_object $cache(ctrlStartPins:$ctrlNet)]
      set cache(ctrlSourceStartPins:$ctrlNet) [all_fanin -quiet -flat -startpoints_only $cache(ctrlStartPins:$ctrlNet)]
#       set cache(destClkPin:$ctrlNet) [get_pins -quiet -filter {IS_CLOCK} -of_object $cell]
#       set cache(destClkPin:$ctrlNet) [get_property -quiet FROM_PIN [get_timing_arcs -quiet -to $ctrlPin -filter {TYPE == setup}]]
      set cache(destClkPin:$ctrlNet) [lindex [filter -quiet [get_property -quiet FROM_PIN [get_timing_arcs -quiet -to $ctrlPin]] {IS_CLOCK}] 0]
      set cache(destClkNet:$ctrlNet) [get_nets -quiet -of_object $cache(destClkPin:$ctrlNet)]
      set cache(destStartPin:$ctrlNet) [all_fanin -quiet -flat -startpoints_only $cache(destClkPin:$ctrlNet)]
      set cache(destClocks:$ctrlNet) [get_clocks -quiet -of $cache(destClkPin:$ctrlNet)]
    }
    
    # Restore data from cache
    set ctrlDriverLibCell $cache(ctrlDriverLibCell:$ctrlNet)
    set ctrlDriverFanout $cache(ctrlDriverFanout:$ctrlNet)
    set ctrlNetType $cache(ctrlNetType:$ctrlNet)
    set ctrlStartPins $cache(ctrlStartPins:$ctrlNet)
    set ctrlStartClocks $cache(ctrlStartClocks:$ctrlNet)
    set ctrlStartCells $cache(ctrlStartCells:$ctrlNet)
    set ctrlSourceStartPins $cache(ctrlSourceStartPins:$ctrlNet)
    set destClkPin $cache(destClkPin:$ctrlNet)
    set destClkNet $cache(destClkNet:$ctrlNet)
    set destStartPin $cache(destStartPin:$ctrlNet)
    set destClocks $cache(destClocks:$ctrlNet)
   
    if {[regexp -nocase {POWER} $ctrlNetType]} {
      # Control net tied to POWER
      $tables(tiedPower) addrow [list $cellType $ctrlPin $ctrlNet $ctrlDriverFanout $ctrlDriverLibCell $ctrlStartPins {tied to power net}]
      incr count(tiedPower)
      continue
    } elseif {[regexp -nocase {GROUND} $ctrlNetType]} {
      # Control net tied to GROUND
      $tables(tiedGround) addrow [list $cellType $ctrlPin $ctrlNet $ctrlDriverFanout $ctrlDriverLibCell $ctrlStartPins {tied to ground net}]
      incr count(tiedGround)
      continue
    }

    if {[llength $ctrlStartPins] > 1} {
      # isSynchronous := 0: asynchronous / 1: synchronous / 2: missing clock(s) / 3: multi-drivers
      set isSynchronous 0
      if {($destClocks == {}) || ($ctrlStartClocks == {})} {
        set isSynchronous 2
      } else {
        set isSynchronous [areClocksSynchronous $ctrlStartClocks $destClocks clockInteraction]
      }
      # Multiple-drivers net
      $tables(multiDrivers) separator
      incr count(multiDrivers)
      switch $isSynchronous {
        0 {
          $tables(asynchronous) separator
          incr count(asynchronous)
        }
        1 {
          $tables(synchronous) separator 
          incr count(synchronous)
        }
        2 {
          $tables(missingClock) separator 
          incr count(missingClock)
        }
      }
      set first 1
      foreach p $ctrlStartPins {
        if {$first} {
          $tables(multiDrivers) addrow [list $cellType $ctrlPin $ctrlNet $ctrlDriverFanout $ctrlDriverLibCell $p [get_clocks -quiet -of $p] $destClocks $destClkPin "$ctrlNameLC with multiple-driver pins"]
          switch $isSynchronous {
            0 {
              $tables(asynchronous) addrow [list $cellType [get_clocks -quiet -of $p] $destClocks $ctrlDriverFanout $ctrlDriverLibCell $ctrlPin $ctrlNet $p $destClkPin "asynchronous $ctrlNameLC with multiple-driver pins"]
            }
            1 {
              $tables(synchronous) addrow [list $cellType [get_clocks -quiet -of $p] $destClocks $ctrlDriverFanout $ctrlDriverLibCell $ctrlPin $ctrlNet $p $destClkPin "synchronous $ctrlNameLC with multiple-driver pins"]
            }
            2 {
              $tables(missingClock) addrow [list $cellType [get_clocks -quiet -of $p] $destClocks $ctrlDriverFanout $ctrlDriverLibCell $ctrlPin $ctrlNet $p $destClkPin {missing clock definition}]
            }
          }
          set first 0
        } else {
          $tables(multiDrivers) addrow [list {"} {"} {"} {"} {"} $p [get_clocks -quiet -of $p] {"} {"} "$ctrlNameLC with multiple-driver pins"]
          switch $isSynchronous {
            0 {
              $tables(asynchronous) addrow [list {"} [get_clocks -quiet -of $p] {"} {"} {"} {"} {"} $p {"} "asynchronous $ctrlNameLC with multiple-driver pins"]
            }
            1 {
              $tables(synchronous) addrow [list {"} [get_clocks -quiet -of $p] {"} {"} {"} {"} {"} $p {"} "synchronous $ctrlNameLC with multiple-driver pins"]
            }
            2 {
              $tables(missingClock) addrow [list {"} [get_clocks -quiet -of $p] {"} {"} {"} {"} {"} $p {"} "missing clock definition"]
            }
          }
        }
      }
      $tables(multiDrivers) separator
      switch $isSynchronous {
        0 {
          $tables(asynchronous) separator
        }
        1 {
          $tables(synchronous) separator 
        }
        2 {
          $tables(missingClock) separator 
        }
      }
      continue
    }

    if {[get_ports -quiet $ctrlStartPins] != {}} {
      # The startpoint is a port ... considered as asynchronous control signal
      $tables(portDriven) addrow [list $cellType $ctrlStartPins $ctrlPin $ctrlNet $ctrlDriverFanout $destClocks $destClkPin "$ctrlNameLC pin driven by primary port"]
      incr count(portDriven)
      continue
    }

    if { [filter $ctrlStartCells {IS_SEQUENTIAL}] != {} } {
      # TODO: check that $destStartPindestStartPin and/or $ctrlSourceStartPins are not empty (missing clock definition)
      if {($destClocks == {}) || ($ctrlStartClocks == {})} {
        $tables(missingClock) addrow [list $cellType $ctrlStartClocks $destClocks $ctrlDriverFanout $ctrlDriverLibCell $ctrlPin $ctrlNet $ctrlStartPins $destClkPin "missing clock definition"]
        incr count(missingClock)
        continue
      }
      if {$destStartPin != $ctrlSourceStartPins} {
        # Both clock domains are different, but are they synchronous (= timed together)?
        if {[areClocksSynchronous $ctrlStartClocks $destClocks clockInteraction]} {
          $tables(synchronous) addrow [list $cellType $ctrlStartClocks $destClocks $ctrlDriverFanout $ctrlDriverLibCell $ctrlPin $ctrlNet $ctrlStartPins $destClkPin "synchronous different clock domains"]
          incr count(synchronous)
        } else {
          $tables(asynchronous) addrow [list $cellType $ctrlStartClocks $destClocks $ctrlDriverFanout $ctrlDriverLibCell $ctrlPin $ctrlNet $ctrlStartPins $destClkPin "asynchronous different clock domains"]
          incr count(asynchronous)
        }
        $tables(diffClkDomain) addrow [list $cellType $ctrlPin $ctrlNet $ctrlDriverFanout $ctrlDriverLibCell $ctrlStartPins $ctrlStartClocks $destClocks $destClkPin "different clock domains"]
        incr count(diffClkDomain)
        continue
      } else {
        # Same clock domains => synchronous
        $tables(synchronous) addrow [list $cellType $ctrlStartClocks $destClocks $ctrlDriverFanout $ctrlDriverLibCell $ctrlPin $ctrlNet $ctrlStartPins $destClkPin "same clock domains"]
        incr count(synchronous)
        $tables(sameClkDomain) addrow [list $cellType $ctrlPin $ctrlNet $ctrlDriverFanout $ctrlDriverLibCell $ctrlStartPins $ctrlStartClocks $destClocks $destClkPin "same clock domains"]
        incr count(sameClkDomain)
        continue
      }
    } else {
      # TODO: if could be the case where the reset pin is driven by a combinational cell
      # which has all its inputs tied to VDD/GND
      # TODO: the driver pins could be also pins of a blackbox
      # E.g: {DUC_DDC_inst/ddc_umts_k7_inst/ddc_srrc_i/U0/i_synth/g_polyphase_decimation.i_polyphase_decimation/g_semi_parallel_and_smac.g_paths[0].g_mem_array[2].i_mem/g_individual.i_mem_a/gen_srl16.gen_mem.d_out_reg[9]/R}
# puts "<ctrlPin:$ctrlPin>"
      $tables(combDriver) addrow [list $cellType $ctrlStartClocks $destClocks $ctrlDriverFanout $ctrlDriverLibCell $ctrlPin $ctrlNet $ctrlStartPins $destClkPin "combinational driver"]
      incr count(combDriver)
#       set flag 0
#       foreach prop [ get_property -quiet TYPE [get_nets -quiet -of [get_pins -quiet -of [get_cells -of $ctrlStartPins] -filter {IS_CONNECTED && (DIRECTION == IN)}]] ] {
#         if {![regexp -nocase {(POWER|GROUND)} $prop]} {
#           set flag 1
#           break
#         }
#       }
#       if {$flag} {
#         # One of the input of $ctrlStartPins is not tied to POWER/GROUND
#         $tables(asynchronous) addrow [list $cellType $ctrlPin $ctrlNet $ctrlDriverFanout $ctrlDriverLibCell $ctrlStartPins $ctrlSourceStartPins $ctrlStartClocks $destClkPin $destStartPin $destClocks "asynchronous source for $ctrlNameLC"]
#         incr count(asynchronous)
#         continue
#       } else {
#         # Not asynchronous reset
#       }
    }
  }

  set endTime [clock seconds]
  set runtime [[namespace parent]::duration [expr $endTime - $startTime]]
  # Set the table tiles
  $tables(portDriven) title [format "$ctrlName Pins Driven by Port (%s)" $count(portDriven)]
  $tables(asynchronous) title [format "Asynchronous $ctrlName Pins (%s)" $count(asynchronous)]
  $tables(synchronous) title [format "Synchronous $ctrlName Pins (%s)" $count(synchronous)]
  $tables(diffClkDomain) title [format {Different Clock Domains (%s)} $count(diffClkDomain)]
  $tables(sameClkDomain) title [format {Same Clock Domain (%s)} $count(sameClkDomain)]
  $tables(unconnected) title [format "Unconnected $ctrlName Pins (%s)" $count(unconnected)]
  $tables(tiedPower) title [format "$ctrlName Pins Tied to Power (%s)" $count(tiedPower)]
  $tables(tiedGround) title [format "$ctrlName Pins Tied to Ground (%s)" $count(tiedGround)]
  $tables(multiDrivers) title [format "$ctrlName Pins with Multiple Driver Pins (%s)" $count(multiDrivers)]
  $tables(missingClock) title [format {Cells with Missing Clock Definition (%s)} $count(missingClock)]
  $tables(combDriver) title [format "Cells with a Combinational Driver for the $ctrlName Pins (%s)" $count(combDriver)]
  # Set the table headers
  $tables(portDriven) header [list "Cell Type" "Launch Source Pin/Port" "$ctrlName Pin" "$ctrlName Net" "$ctrlName Net Fanout" "Capture Clock Domain" "Capture Clock Pin" "Info" ]
  $tables(asynchronous) header [list "Cell Type" "Launch Clock Domain" "Capture Clock Domain" "$ctrlName Net Fanout" "$ctrlName Net Driver Type" "$ctrlName Pin" "$ctrlName Net" "Launch Source Pin" "Capture Clock Pin" "Info" ]
  $tables(synchronous) header [list "Cell Type" "Launch Clock Domain" "Capture Clock Domain" "$ctrlName Net Fanout" "$ctrlName Net Driver Type" "$ctrlName Pin" "$ctrlName Net" "Launch Source Pin" "Capture Clock Pin" "Info" ]
  $tables(diffClkDomain) header [list "Cell Type" "$ctrlName Pin" "$ctrlName Net" "$ctrlName Net Fanout" "$ctrlName Net Driver Type" "Launch Source Pin" "Launch Clock Domain" "Capture Clock Domain" "Capture Clock Pin" "Info" ]
  $tables(sameClkDomain) header [list "Cell Type" "$ctrlName Pin" "$ctrlName Net" "$ctrlName Net Fanout" "$ctrlName Net Driver Type" "Launch Source Pin" "Launch Clock Domain" "Capture Clock Domain" "Capture Clock Pin" "Info" ]
  $tables(unconnected) header [list "Cell Type" "$ctrlName Pin" "Info" ]
  $tables(tiedPower) header [list "Cell Type" "$ctrlName Pin" "$ctrlName Net" "$ctrlName Net Fanout" "$ctrlName Net Driver Type" "Launch Source Pin" "Info" ]
  $tables(tiedGround) header [list "Cell Type" "$ctrlName Pin" "$ctrlName Net" "$ctrlName Net Fanout" "$ctrlName Net Driver Type" "Launch Source Pin" "Info" ]
  $tables(multiDrivers) header [list "Cell Type" "$ctrlName Pin" "$ctrlName Net" "$ctrlName Net Fanout" "$ctrlName Net Driver Type" "Launch Source Pin" "Launch Clock Domain" "Capture Clock Domain" "Capture Clock Pin" "Info" ]
  $tables(missingClock) header [list "Cell Type" "Launch Clock Domain" "Capture Clock Domain" "$ctrlName Net Fanout" "$ctrlName Net Driver Type" "$ctrlName Pin" "$ctrlName Net" "Launch Source Pin" "Capture Clock Pin" "Info" ]
  $tables(combDriver) header [list "Cell Type" "Launch Clock Domain" "Capture Clock Domain" "$ctrlName Net Fanout" "$ctrlName Net Driver Type" "$ctrlName Pin" "$ctrlName Net" "Launch Source Pin" "Capture Clock Pin" "Info" ]
  $tables(summaryControlNets) header [list "Driver Ref" "Fanout" "$ctrlName Net Name" "Driver Pin"]
  $tables(clockInteraction) header [list "From clock" "To Clock" "Common Primary Clock" "Inter-Clock Constraints"]
  lappend output "[string toupper $ctrlName] report\n"
  if {$verbose} {
    set output [concat $output [split [format "
Table of Contents
-----------------
0. report summary
1. clock interaction summary
2. $ctrlNameLC nets summary
3. checking asynchronous
4. checking synchronous
5. checking port_driven
6. checking tied_power
7. checking combinational_driver
8. checking missing_clock
9. checking unconnected
10. checking tied_ground"] \n]]
    if {$debug} {
      set output [concat $output [split [format "11. checking different_clock_domains
12. checking same_clock_domain
13. checking multiple_drivers
"] \n]]
    }
    lappend output "\n0. report summary"
    lappend output "-----------------"
  } else {
    lappend output "Summary"
    lappend output "-------"
  }
  lappend output " There are $count(asynchronous) $ctrlNameLC pins that are asynchronous (asynchronous)"
  lappend output " There are $count(synchronous) $ctrlNameLC pins that are synchronous (synchronous)"
  lappend output " There are $count(portDriven) $ctrlNameLC pins that are driven by primary ports (port_driven)"
  lappend output " There are $count(tiedPower) $ctrlNameLC pins that are tied to power (tied_power)"
  lappend output " There are $count(combDriver) cells that have a combinational driver for the $ctrlNameLC pin (combinational_driver)"
  lappend output " There are $count(missingClock) cells that have missing clock definition on the destination clock pin or sequential element driving the $ctrlNameLC pin (missing_clock)"
  lappend output " There are $count(unconnected) $ctrlNameLC pins that are unconnected (unconnected)"
  lappend output " There are $count(tiedGround) $ctrlNameLC pins that are tied to ground (tied_ground)"
  if {$debug} {
    lappend output " There are $count(diffClkDomain) $ctrlNameLC pins that have a clock domain different from the clock pins (different_clock_domains)"
    lappend output " There are $count(sameClkDomain) $ctrlNameLC pins that have the same clock domains as the clock pins (same_clock_domain)"
    lappend output " There are $count(multiDrivers) $ctrlNameLC pins that have multiple drivers (multiple_drivers)"
  }
  if {$verbose} {
    lappend output "\n1. clock interaction summary"
    lappend output "----------------------------"
    set output [concat $output [split [$tables(clockInteraction) print] \n] ]
    lappend output "\n2. $ctrlNameLC nets summary"
    lappend output "---------------------"
    set num 0
    foreach net [lsort -unique -dictionary $ctrlNets] {
#       if {[regexp -nocase {(POWER|GROUND)} [string tolower [get_property -quiet TYPE $net]] ]} {}
      if {[regexp -nocase {GROUND} [string tolower [get_property -quiet TYPE $net]] ]} {
        # Skip nets tied to ground
        continue
      }
      incr num
      set driverPin [get_pins -quiet -of [get_nets -quiet $net] -leaf -filter {DIRECTION==OUT}]
      set driverRef [get_property -quiet REF_NAME [get_cells -quiet -of $driverPin]]
      $tables(summaryControlNets) addrow [list $driverRef [expr [get_property -quiet FLAT_PIN_COUNT [get_nets $net]] -1] $net $driverPin ]
    }
    $tables(summaryControlNets) title "$ctrlName Nets Summary ($num)"
    # Sort the table based on the 1st column (Driver Ref) and then 3rd column (Net Name)
    $tables(summaryControlNets) sort {-increasing -dictionary -index 2} {-increasing -dictionary -index 0}

    set output [concat $output [split [$tables(summaryControlNets) print] \n] ]
    lappend output "\n3. checking asynchronous"
    lappend output "------------------------"
    if {$count(asynchronous)} { set output [concat $output [split [$tables(asynchronous) print] \n] ] }
    lappend output "\n4. checking synchronous"
    lappend output "-----------------------"
    if {$count(synchronous)} { set output [concat $output [split [$tables(synchronous) print] \n] ] }
    lappend output "\n5. checking port_driven"
    lappend output "-----------------------"
    if {$count(portDriven)} { set output [concat $output [split [$tables(portDriven) print] \n] ] }
    lappend output "\n6. checking tied_power"
    lappend output "----------------------"
    if {$count(tiedPower)} { set output [concat $output [split [$tables(tiedPower) print] \n] ] }
    lappend output "\n7. checking combinational_driver"
    lappend output "--------------------------------"
    if {$count(combDriver)} { set output [concat $output [split [$tables(combDriver) print] \n] ] }
    lappend output "\n8. checking missing_clock"
    lappend output "-------------------------"
    if {$count(missingClock)} { set output [concat $output [split [$tables(missingClock) print] \n] ] }
    lappend output "\n9. checking unconnected"
    lappend output "-----------------------"
    if {$count(unconnected)} { set output [concat $output [split [$tables(unconnected) print] \n] ] }
    lappend output "\n10. checking tied_ground"
    lappend output "------------------------"
    if {$count(tiedGround)} { set output [concat $output [split [$tables(tiedGround) print] \n] ] }
    if {$debug} {
      lappend output "\n11. checking different_clock_domains"
      lappend output "------------------------------------"
      if {$count(diffClkDomain)} { set output [concat $output [split [$tables(diffClkDomain) print] \n] ] }
      lappend output "\n12. checking same_clock_domain"
      lappend output "------------------------------"
      if {$count(sameClkDomain)} { set output [concat $output [split [$tables(sameClkDomain) print] \n] ] }
      lappend output "\n13. checking multiple_drivers"
      lappend output "-----------------------------"
      if {$count(multiDrivers)} { set output [concat $output [split [$tables(multiDrivers) print] \n] ] }
    }
  }

#   lappend output ""
#   lappend output "??? primitives with asynchronous set or reset without a synchronous deasertion"
  lappend output ""
  lappend output "********************************************************************"

  puts "\n Total runtime: $runtime"

  if {$filename != {}} {
    set FH [open $filename $mode]
    puts $FH [::tclapp::xilinx::ultrafast::generate_file_header {report_reset_signals}]
    puts $FH [join $output \n]
    puts $FH "\n Total runtime: $runtime"
    close $FH
    puts "\n Report file [file normalize $filename] has been generated\n"
  } else {
#     puts [join $output \n]
  }

  # Destroy the cache
  catch {unset cache}

  # Destroy the objects
  catch {$tables(portDriven) destroy}
  catch {$tables(asynchronous) destroy}
  catch {$tables(synchronous) destroy}
  catch {$tables(sameClkDomain) destroy}
  catch {$tables(diffClkDomain) destroy}
  catch {$tables(unconnected) destroy}
  catch {$tables(tiedPower) destroy}
  catch {$tables(tiedGround) destroy}
  catch {$tables(multiDrivers) destroy}
  catch {$tables(missingClock) destroy}
  catch {$tables(summaryControlNets) destroy}
  catch {$tables(combDriver) destroy}
  catch {$tables(clockInteraction) destroy}

  # Return result as string?
  if {$returnString} {
    return [join $output \n]
  } else {
    puts [join $output \n]
  }

  return 0
}
