
########################################################################################
## 02/04/2014 - Renamed file and various additional updates for Tcl App Store 
## 02/03/2014 - Updated the namespace and definition of the command line arguments 
##              for the Tcl App Store
## 10/01/2013 - Based on Chuck's feedback, show unconnected and clocks by default
##              Replace -show_unconnected with -hide_unconnected
##              Replace -show_clocks with -hide_clocks
## 09/16/2013 - Added meta-comment 'Categories' to all procs
## 09/10/2013 - Changed command name from pll_io_check to check_pll_connectivity
##            - Minor updates to output formating
## 09/09/2013 - Added support for -file/-append/-return_string
##            - Moved code in a private namespace
##            - Removed errors from linter (lint_files)
## 09/03/2013 - Disabled 'Vivado 12-1023' messages
## 08/23/2013 - Initial release based on pll_io_check version 1.0 (Chuck Daugherty)
########################################################################################

## ---------------------------------------------------------------------
## Description
## Procedure: pll_io_check
##  This procedure displays the signals hooked up to each PLL and
##  MMCM in the design.  A warning is displayed if the RST port or
##      LOCKED port are not connected to signals.  Floating inputs are
##      also reported.  Display of outputs that are No-Connects can be
##  optionally disabled by setting display_no_connects to 0.
##
##  check_pll and check_mmcm control which of PLL and/or MMCM's are
##  checked.  By default, both are checked.  Setting check_pll to
##  0 disables PLL checking while setting check_mmcm to 0 disables
##  MMCM checking.
##
## Author: Chuck Daugherty
## Version Number: 1.0
## Version Change History
## Version 1.0 - Initial release
## --------------------------------------------------------------------- 

namespace eval ::tclapp::xilinx::ultrafast {
  namespace export check_pll_connectivity
  
}

proc ::tclapp::xilinx::ultrafast::check_pll_connectivity { args } {
  # Summary: Report MMCM/PLL information

  # Argument Usage:
  # [-pll]: Report information about PLLs
  # [-mmcm]: Report information about MMCMs
  # [-hide_unconnected]: Hide unconnected output pins
  # [-hide_clock]: Hide clock signals
  # [-file <arg>]: Report file name
  # [-append]: Append to file
  # [-return_string]: Return report as string
  # [-usage]: Usage information

  # Return Value:
  # return report if -return_string is used, otherwise 0. If any error occur TCL_ERROR is returned

  # Categories: xilinxtclstore, ultrafast

  uplevel [concat ::tclapp::xilinx::ultrafast::check_pll_connectivity::check_pll_connectivity $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::ultrafast::check_pll_connectivity { 
  variable version {02/04/2014}
} ]

proc ::tclapp::xilinx::ultrafast::check_pll_connectivity::check_pll_connectivity { args } {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, ultrafast

  #-------------------------------------------------------
  # Process command line arguments
  #-------------------------------------------------------
  set error 0
  set help 0
  set filename {}
  set mode {w}
  set check_pll 0
  set check_mmcm 0
  set display_no_connects 1
  set display_clocks 1
  set returnString 0
  while {[llength $args]} {
    set name [[namespace parent]::lshift args]
    switch -regexp -- $name {
      -pll -
      {^-p(ll?)?$} {
           set check_pll 1
      }
      -mmcm -
      {^-m(m(cm?)?)?$} {
           set check_mmcm 1
      }
      -hide_unconnected -
      {^-hide_u(n(c(o(n(n(e(c(t(ed?)?)?)?)?)?)?)?)?)?$} {
           set display_no_connects 0
      }
      -hide_clocks -
      {^-hide_c(l(o(c(ks?)?)?)?)?$} {
           set display_clocks 0
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
  
  if {!$check_pll && !$check_mmcm} {
    set check_pll 1
    set check_mmcm 1
  }

  if {$help} {
    puts [format {
  Usage: check_pll_connectivity
              [-pll]               - Report information about PLLs
              [-mmcm]              - Report information about MMCMs
              [-hide_unconnected]  - Hide unconnected output pins
              [-hide_clock]        - Hide clock signals
              [-file]              - Report file name
              [-append]            - Append to file
              [-return_string]     - Return report as string
              [-usage|-u]          - This help message
              
  Description: Report MMCM/PLL information
  
     This command displays the signals hooked up to each PLL and
     MMCM in the design.  A warning is displayed if the RST port or
     LOCKED port are not connected to signals.  Floating inputs are
     also reported.  Display of outputs that are No-Connects can be
     optionally disabled by setting display_no_connects to 0.
   
     check_pll and check_mmcm control which of PLL and/or MMCM's are
     checked.  By default, both are checked.  Setting check_pll to
     0 disables PLL checking while setting check_mmcm to 0 disables
     MMCM checking.

  Example:
     check_pll_connectivity
     check_pll_connectivity -mmcm
     check_pll_connectivity -mmcm -hide_unconnected -file myreport.rpt -append
} ]
    # HELP -->
    return {}
  }
  
  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }
  
  # disable reporting of not finding nets (for netless output pins)
  set_msg_config -id {Vivado 12-1023} -suppress

  set output [list]
  set table [[namespace parent]::Table::Create]

  set inst [list]
  if {$check_pll} {
    set inst [concat $inst [get_cells -quiet -hier * -filter {REF_NAME =~ "PLL*"}] ]
  }
  if {$check_mmcm} {
    set inst [concat $inst [get_cells -quiet -hier * -filter {REF_NAME =~ "MMCM*"}] ]
  }

  foreach pll [lsort -dictionary $inst] {
    # Make sure this is a cell object. Because the way 'inst' is built with the 'concat'
    # command, the Vivado objects can be converted into Tcl strings
    set pll [get_cells -quiet $pll]
    $table reset
    $table title "Instance name: $pll\nPrimitive type: [get_property REF_NAME $pll]"
    if {$display_clocks} {
      $table header [list {Pin} {Dir} {Net} {Clock} {Severity} {Info} {Recommendation}]
    } else {
      $table header [list {Pin} {Dir} {Net} {Severity} {Info} {Recommendation}]
    }
    foreach pin [lsort -dictionary [get_pins -quiet -of $pll]] {
#       set is_connected [get_attribute IS_CONNECTED $pin]
      # Check is the pin is a clear/reset pin. 
      set is_reset [expr [get_property -quiet IS_CLEAR $pin] \
                      || [get_property -quiet IS_PRESET $pin] \
                      || [get_property -quiet IS_RESET $pin] \
                      || [get_property -quiet IS_SETRESET $pin] \
                   ]
      set net [get_nets -quiet -of $pin];
      set direction [get_property -quiet DIRECTION $pin]
      set info {}
      set severity {}
      set recommendation {}
      set clock_name {}
      set pin_name [get_property -quiet REF_PIN_NAME $pin]

      # test if the pin is unconnected
      if {$net == {}} {
        set net_name {};

        # if this is an input, bad stuff (floating input)
        if {$direction == "IN"} {
          set info {floating input}
          set severity {warning}
        } else {
          set info {unconnected output}
          # if output pin LOCKED, a warning is generated
          if {$pin_name == "LOCKED"} {
            set recommendation {should be connected to user logic (asynchronous signal)}
            set severity {warning}
          } else {
            if {!$display_no_connects} {
              continue
            }
          }
        }

      # pin connected, but test if it's a Ground
      } else {
        set net_type [string toupper [get_property -quiet TYPE $net]]
        set clock_name [get_clocks -quiet -of $pin]
        # test if the RST pin is connected to something other than a user net; if so, generate a warning
#         if {$net_type != {SIGNAL} && $pin_name == {RST}} {}
        if {$net_type != {SIGNAL} && $is_reset} {
          set severity {warning}
          set recommendation {should be driven by user logic}
        }

        # clearly identify pins hooked up to Power (rather than cryptic net name)
        if {$net_type == {POWER}} {
          set info "Tie high"
        }

        # clearly identify pins hooked up to Ground (and generate warning if RST is grounded)
        if {$net_type == {GROUND}} {
#           if {$pin_name == "RST"} {}
          if {$is_reset} {
            set info "Tie low"
            set recommendation {should be driven by user logic}
            set severity {warning}
          } else {
            set info "Tie low"
          }
        } else {
        }
      }
      if {$display_clocks} {
        $table addrow [list $pin_name $direction $net $clock_name $severity $info $recommendation]
      } else {
        $table addrow [list $pin_name $direction $net $severity $info $recommendation]
      }
    }

    # Print out the summary table
    set output [concat $output [split [$table print] \n] ]
  }

  # reset message limit back to default
  reset_msg_config -id {Vivado 12-1023} -suppress

  if {$filename !={}} {
    set FH [open $filename $mode]
    puts $FH [::tclapp::xilinx::ultrafast::generate_file_header {check_pll_connectivity}]
    puts $FH [join $output \n]
    close $FH
    puts "\n Report file [file normalize $filename] has been generated\n"
  } else {
    puts [join $output \n]
  }

  # Destroy the object
  catch {$table destroy}

  # Return result as string?
  if {$returnString} {
    return [join $output \n]
  }

  return 0
}

