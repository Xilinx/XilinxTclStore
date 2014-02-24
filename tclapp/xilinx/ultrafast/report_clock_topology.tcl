
########################################################################################
## 02/04/2014 - Renamed file and various additional updates for Tcl App Store 
## 02/03/2014 - Updated the namespace and definition of the command line arguments 
##              for the Tcl App Store
## 09/20/2013 - Added a bug fix from Chuck
##            - Quiet some more get_* commands
## 09/16/2013 - Added meta-comment 'Categories' to all procs
## 09/10/2013 - Changed command name from clockTopology to report_clock_topology
## 09/09/2013 - Added support for -file/-append/-return_string
##            - Moved code in a private namespace
##            - Removed errors from linter (lint_files)
## 08/23/2013 - Initial release based on clockTopology version 1.0 (Chuck Daugherty)
########################################################################################

namespace eval ::tclapp::xilinx::ultrafast {
  namespace export report_clock_topology

}

proc ::tclapp::xilinx::ultrafast::report_clock_topology { args } {
  # Summary: Generates a Clock Topology Report

  # Argument Usage:
  # [-no_redundant_path]: Stop tracing once another clock is found
  # [-no_generated_clocks]: Skip generated clocks
  # [-full_report]: Generate a full report
  # [-file <arg>]: Report file name
  # [-append]: Append to file
  # [-return_string]: Return report as string
  # [-usage]: Usage information

  # Return Value:
  # return report if -return_string is used, otherwise 0. If any error occur TCL_ERROR is returned

  # Categories: xilinxtclstore, ultrafast

  uplevel [concat ::tclapp::xilinx::ultrafast::report_clock_topology::report_clock_topology $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::ultrafast::report_clock_topology { 
  variable version {02/04/2014}
  variable output
} ]

## ---------------------------------------------------------------------
## Description
## Procedure: report_clock_topology 
##  Generates a Clock Topology Report.  The report shows the path
##  for each created clock (i.e., only traces clocks that have
##  already been created. Doesn't trace clocks that haven't been
##  defined).
##
## Arguments:
##  redundantFullPath: should the procedure stop tracing the path
##    once another created clock is found
##    0 = stop tracing once another created clock is found
##    1 = trace the full path even if another clock is found
##      along the way
##  simpleReport: controls if the report should be more concise
##    0 = generate a full report (show all pins and nets)
##    1 = generate a simple report (don't show all details)
##  reportGenerated: controls if generated clocks should be traced
##    0 = do not trace generated clocks
##    1 = trace all created clocks (including generated)
##
## Author: Chuck Daugherty
## Version Number: 1.0
## Version Change History
## Version 1.0 - Initial release
## --------------------------------------------------------------------- 

proc ::tclapp::xilinx::ultrafast::report_clock_topology::report_clock_topology { args } {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, ultrafast

  variable output
  #-------------------------------------------------------
  # Process command line arguments
  #-------------------------------------------------------
  set error 0
  set help 0
  set redundantFullPath 1
  set simpleReport 1
  set reportGenerated 1
  set filename {}
  set mode {w}
  set FH {}
  set returnString 0
  while {[llength $args]} {
    set name [[namespace parent]::lshift args]
    switch -regexp -- $name {
      -no_redundant_path -
      {^-no_r(e(d(u(n(d(a(n(t(_(p(a(th?)?)?)?)?)?)?)?)?)?)?)?)?$} {
           set redundantFullPath 0
      }
      -no_generated_clocks -
      {^-no_g(e(n(e(r(a(t(e(d(_(c(l(o(c(ks?)?)?)?)?)?)?)?)?)?)?)?)?)?)?$} {
           set reportGenerated 0
      }
      -full_report -
      {^-fu(l(l(_(r(e(p(o(rt?)?)?)?)?)?)?)?)?$} {
           set simpleReport 0
      }
      -file -
      {^-fi(le?)?$} {
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
      -return_string -
      {^-r(e(t(u(r(n(_(s(t(r(i(ng?)?)?)?)?)?)?)?)?)?)?)?$} {
           set returnString 1
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
  Usage: report_clock_topology
              [-no_redundant_path]   - Stop tracing once another clock is found
              [-no_generated_clocks] - Skip generated clocks
              [-full_report]         - Generate a full report
              [-file]                - Report file name
              [-append]              - Append to file
              [-return_string]       - Return report as string
              [-usage|-u]            - This help message

  Description: Generates a Clock Topology Report

     Generates a Clock Topology Report.  The report shows the path
     for each created clock (i.e., only traces clocks that have
     already been created. Does not trace clocks that haven't been
     defined).

  Example:
     report_clock_topology
     report_clock_topology -no_redundant_path -full_report -file myreport.rpt
} ]
    # HELP -->
    return {}
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }


  # disable reporting of not finding nets (for netless output pins)
  set_msg_config -id {Vivado 12-1023} -suppress

  # Clear output list
  set output [list]

  # trace ALL created clocks
  set clk [lsort [all_clocks]]

  foreach clock $clk {
    set isGen [expr [get_property -quiet IS_GENERATED $clock] || [get_property -quiet IS_USER_GENERATED $clock]]
    set isVirtual [get_property -quiet IS_VIRTUAL $clock]
    # decide if we're processing propagated clocks - is this one?
    if {($reportGenerated == 0) && ($isGen == 1)} {
      continue
    }
    lappend output ""
    lappend output [string repeat {+} [string length "Clock: $clock"]]
    lappend output "Clock: $clock"
    lappend output [string repeat {+} [string length "Clock: $clock"]]
    if {$isGen == 1} {
      set clkType "Type: Generated Clock"
    } else {
      set clkType "Type: Primary Clock"
    }
    if {$isVirtual == 1} {
      set clkType "Type: Virtual Clock"
      lappend output $clkType
      # Virtual clock have no topology
      continue
    }
    lappend output $clkType
    set isTopPort 0
    # starting net is the net associated with the created clock
    set clkNet [get_nets -quiet -of $clock]
    lappend output "Net: $clkNet"

    # determine if this is a top level port (get's analyzed a
    #   little different in proc getLoads called later)
    set portName ""
    set clkcopy $clkNet
    foreach mynet $clkcopy {
      set routeStatus [get_property -quiet ROUTE_STATUS $mynet]
      if {$routeStatus == "INTRASITE"} {
        set portName [get_ports -quiet -of $mynet]
        set clkNet $mynet
        # Should we stop at the first one?
#         break
      }
    }

    # if it's a top level port
    if {$portName != {}} {
      set isTopPort 1
      set portPin [get_property -quiet PACKAGE_PIN $portName]
      # if it has a pin number, report it
      if [llength $portPin] {
        lappend output "Sourced by top level Port: $portName (package pin: $portPin)"
      } else {
        lappend output "Sourced by top level Port: $portName (package pin: not LOCed)"
      }
    # else not a top level port
    } else {
      set sourcePin [get_pins -quiet -of [get_clocks -quiet $clock]]
      set sourceInst [get_cells -quiet -of $sourcePin]
      set sourceType [get_property -quiet REF_NAME $sourceInst]
      set cellLOC [get_property -quiet LOC $sourceInst]
      # if it has a LOC, report it
      if {$cellLOC != {}} {
        lappend output "Sourced by $sourceType ($cellLOC) pin: $sourcePin"
      } else {
        lappend output "Sourced by $sourceType (not LOCed) pin: $sourcePin"
      }
    }
    if {$simpleReport == 0} {
      lappend output "Topology:"
    }

    getLoads $clkNet $isTopPort $redundantFullPath $simpleReport
    lappend output " "

  }

  # reset message limit back to default
  reset_msg_config -id {Vivado 12-1023} -suppress

  if {$filename !={}} {
    set FH [open $filename $mode]
    puts $FH [::tclapp::xilinx::ultrafast::generate_file_header {report_clock_topology}]
    puts $FH [join $output \n]
    close $FH
    puts "\n Report file [file normalize $filename] has been generated\n"
  } else {
    puts [join $output \n]
  }

  # Return result as string?
  if {$returnString} {
    return [join $output \n]
  }

  return 0
}

## ---------------------------------------------------------------------
## Description
## Procedure: getLoads
##  Called by procedure report_clock_topology to provide the recursive
##  searching of clock paths.  This procedure finds the load cells
##  of the specified net.  It traces forward through clock elements
##  reports a summary of what synchronous elements are found.
##
## Arguments:
##  clkNet: net used as a starting (or continuation) point
##  isPort: identifies if net is a top level port
##    0 = net is not a top level port
##    1 = net is a top level port
##  redundantFullPath: should the procedure stop tracing the path
##    once another created clock is found
##    0 = stop tracing once another created clock is found
##    1 = trace the full path even if another clock is found
##      along the way (i.e., trace through that clock)
##  simpleReport: controls if the report should be more concise
##    0 = generate a full report (show all pins and nets)
##    1 = generate a simple report (don't show all details)
##  prefix: used in recursive call as part of hierarchy formatting
##    by putting more spaces in front of deeper hierarchy
##    <number> = number of leading spaces in puts
##
## Author: Chuck Daugherty
## Version Number: 1.0
## Version Change History
## Version 1.0 - Initial release
## --------------------------------------------------------------------- 

proc ::tclapp::xilinx::ultrafast::report_clock_topology::getLoads { clkNet {isPort 0} {redundantFullPath 0} {simpleReport 0} {prefix 0} } {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, ultrafast

  variable output
  # disable reporting of not finding nets (for netless output pins)
#   set_msg_config -id {Vivado 12-1023} -suppress

  # increase the number of puts spaces (gets increased for each recursive call
  set numSpaces [expr {$prefix + 2}]
  set spaces [string repeat " " $numSpaces]
  set netLoadCells ""

  # how many things are driven by this net?
  set pinCount [get_property -quiet FLAT_PIN_COUNT $clkNet]

  # if it's not a top level port, it needs to connect to at least
  #   two pins (the output pin and 1 or more inputs).
  # top level ports just need to drive 1 input
  set minCount 0
  if {$isPort == 0} {
    set minCount 1
  }

  # check if there are any loads based on FLAT_PIN_COUNT
  #   before bothering to search for cells
  if {$pinCount > $minCount} {
    # get all leaf nodes (inputs - don't want the source cell)
    set netLoadCells [get_cells -quiet -of [get_pins -quiet -of [get_nets -quiet $clkNet] -leaf -filter {DIRECTION == "IN"}]]

    # how many of those loads are sequential primitives?  We'll report them.
    set syncElements 0
    foreach cell $netLoadCells {
      set isSync [get_property -quiet IS_SEQUENTIAL $cell]
      if {$isSync == 1} {
        set syncElements 1
        break
      }
    }
    if {$syncElements > 0} {
      set syncElements [get_cells -quiet -of [get_pins -quiet -of [get_nets -quiet $clkNet] -leaf -filter {DIRECTION == "IN"}] -filter IS_SEQUENTIAL]
      set syncElementTypes [get_property -quiet REF_NAME $syncElements]
      set syncElementsLength [llength $syncElements]

      # provide a summary of the sequential (synchronous) elements - just report unique types
      lappend output "$spaces  Drives $syncElementsLength synchronous elements of type(s): [lsort -unique $syncElementTypes]"
    }
  } else {
    # let user know if this pin has no loads
    lappend output "$spaces  Net has 0 loads (disconnected output)."
  }

  # analyze each load cell (IBUFx vs. BUFx vs. PLL/MMCM each treated differently)
  foreach cell $netLoadCells {
    set cellType [get_property -quiet REF_NAME $cell]

    # just grab first 3 characters of REF_NAME - makes it easier to treat them as categories
    set type [string range $cellType 0 2]

    # we'll set traceForward when we find input buffers, clock buffers and PLL/MMCM's
    set traceForward 0
    set isPll 0

    # is the load cell an input buffer?
    if {$type == "IBU"} {
      set traceForward 1
      # trace forward on all output pins
      set cellPins [get_pins -quiet -of $cell -filter {DIRECTION == "OUT"}]
    }

    # is the load cell a clock buffer?
    if {$type == "BUF" } {
      set traceForward 1
      # trace forward on all output pins
      set cellPins [get_pins -quiet -of $cell -filter {DIRECTION == "OUT"}]
    }

    # is the load cell a PLL or MMCM?
    if {$type == "PLL" || $type == "MMC"} {
      # set isPll to change how later reporting is done (different than IBUF/BUF)
      set isPll 1

      # figure out which net drives CLKIN1 so we can figure out if
      #   we should trace forward for this particular net
      set clkinNet [get_nets -quiet -of [get_pins -quiet -of $cell -filter {NAME =~ "*CLKIN1"}]]
      # also grab the feedback net. we'll report if this is part of the feedback path
      set clkinNetFb [get_nets -quiet -of [get_pins -quiet -of $cell -filter {NAME =~ "*CLKFBIN"}]]
      set clkinNetClkin2 [get_nets -quiet -of [get_pins -quiet -of $cell -filter {NAME =~ "*CLKIN2"}]]
      if {$clkinNet == $clkNet} {
        set traceForward 1
        set cellPins [get_pins -quiet -of $cell -filter {DIRECTION==OUT && (NAME =~ "*CLKFBOUT" || NAME =~ "*CLKFBOUTB" || NAME =~ "*CLKOUT?")} ]
      } else {
        if {$clkinNetFb == $clkNet} {
          lappend output "$spaces  Connected to CLKFBIN of $cellType: $cell"
        }
        if {$clkinNetClkin2 == $clkNet} {
          lappend output "$spaces  Connected to CLKIN2 of $cellType: $cell"
        }
      }
    }

    # is the load cell an IDELAY primitive?  we trace through those, too
    if {$type == "IDE" && $cellType != "IDELAYCTRL"} {
      set clkinNet [get_nets -quiet -of [get_pins -quiet -of $cell -filter {NAME =~ "*IDATAIN"}]]
      if {$clkinNet == $clkNet} {
        set traceForward 1
        set cellPins [get_pins -quiet -of $cell -filter {DIRECTION == "OUT" && NAME =~ "*DATAOUT"} ]
      }
    }

    # we'll trace forward through this cell if the parsing above determined we should
    if $traceForward {
      # does this cell have a fixed location?  Report it.
      set cellLOC [get_property -quiet LOC $cell]
      if [llength $cellLOC] {
        lappend output "$spaces$cellType ($cellLOC):    $cell"
      } else {
        lappend output "$spaces$cellType (not LOCed):    $cell"
      }

      # we'll trace forward through "some" of the pins (was previously set
      #   depending on cell type)
      foreach pin $cellPins {
        set net [get_nets -quiet -of $pin]
#         set pinName [string range $pin [string last "/" $pin]+1 end]
        set pinName [get_property -quiet REF_PIN_NAME $pin]
        # only process if there is a net associated with this pin
        # note that processing includes a recursive call back to getLoads
        if {$net != {}} {
          set clock [get_clocks -quiet -of $net]
          set checkNet [get_nets -quiet -of $clock]
          # is this net associated with another created clock?
          if [llength $clock] {
            if {$net == $checkNet} {
              if {$simpleReport == 0} {
                lappend output "$spaces  pin: $pinName, net: $net (Net of Created Clock: $clock)"
              } else {
                if $isPll {
                  lappend output "$spaces  pin: $pinName (Drives Net of Created Clock: $clock)"
                } else {
                  lappend output "$spaces  (Drives Net of Created Clock: $clock)"
                }
              }
              if {$redundantFullPath > 0} {
                getLoads $net 0 $redundantFullPath $simpleReport [expr {$numSpaces + 2}]
              }
            } else {
              if {$simpleReport == 0} {
                lappend output "$spaces  pin: $pinName, net: $net"
              } else {
                if $isPll {
                  lappend output "$spaces  pin: $pinName"
                }
              }
              getLoads $net 0 $redundantFullPath $simpleReport [expr {$numSpaces + 2}]
            }
          } else {
            if {$simpleReport == 0} {
              lappend output "$spaces  pin: $pinName, net: $net"
            } else {
              if $isPll {
                lappend output "$spaces  pin: $pinName"
              }
            }
            getLoads $net 0 $redundantFullPath $simpleReport [expr {$numSpaces + 2}]
          }
        }
      }
    }
  }
}

