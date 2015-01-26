
########################################################################################
## 01/23/2015 - Added support for Native mode for UltraScale
## 01/22/2015 - Added support for UltraScale
## 06/05/2014 - Fixed final message as the list of input/output ports were inverted
## 02/04/2014 - Renamed file and various additional updates for Tcl App Store
## 02/03/2014 - Updated the namespace and definition of the command line arguments
##              for the Tcl App Store
## 09/16/2013 - Added meta-comment 'Categories' to all procs
## 09/10/2013 - Changed command name from checkio to report_io_reg
##            - Minor updates to output formating
## 09/09/2013 - Added support for -file/-append/-return_string
##            - Moved code in a private namespace
##            - Removed errors from linter (lint_files)
## 08/23/2013 - Initial release based on checkio version 1.0 (Jon Beckwith)
########################################################################################

## ---------------------------------------------------------------------
## Description
##    This proc displays information related to IO ports.  It is a
##    supplement to the I/O ports view in Vivado.  It shows the site,
##    clock region, coordinate, as well as whether IDELAY/ODELAY and
##    ILOGIC/OLOGIC are instantiated for the ports in use.
##
##    Warnings are displayed if IDELAY/ODELAYs are not used
##
## Author: Jon Beckwith
## Version Number: 1.0
## Version Change History
## Version 1.0 - Initial release
## ---------------------------------------------------------------------

namespace eval ::tclapp::xilinx::ultrafast {
  namespace export report_io_reg

}

proc ::tclapp::xilinx::ultrafast::report_io_reg { args } {
  # Summary: Report I/O ports information

  # Argument Usage:
  # [-verbose]: Verbose mode
  # [-file <arg>]: Report file name
  # [-append]: Append to file
  # [-return_string]: Return report as string
  # [-usage]: Usage information

  # Return Value:
  # return report if -return_string is used, otherwise 0. If any error occur TCL_ERROR is returned

  # Categories: xilinxtclstore, ultrafast

  uplevel [concat ::tclapp::xilinx::ultrafast::report_io_reg::report_io_reg $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::ultrafast::report_io_reg {
  variable version {01/23/2015}
} ]

proc ::tclapp::xilinx::ultrafast::report_io_reg::report_io_reg { args } {
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
  set help 0
  set returnString 0
  set verbose 0
  while {[llength $args]} {
    set name [[namespace parent]::lshift args]
    switch -regexp -- $name {
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
  Usage: report_io_reg
              [-file]              - Report file name
              [-append]            - Append to file
              [-verbose]           - Verbose mode
              [-return_string]     - Return report as string
              [-usage|-u]          - This help message

  Description: Report I/O ports information

     This command displays information related to IO ports.  It is a
     supplement to the I/O ports view in Vivado.  It shows the site,
     clock region, coordinate, as well as whether IDELAY/ODELAY and
     ILOGIC/OLOGIC are instantiated for the ports in use.

     Warnings are displayed if IDELAY/ODELAYs are not used

  Example:
     report_io_reg
     report_io_reg -verbose -file myreport.rpt
} ]
    # HELP -->
    return {}
  }

  # Get the current architecture
  set architecture [::tclapp::xilinx::ultrafast::getArchitecture]
  switch $architecture {
    artix7 -
    kintex7 -
    virtex7 -
    zynq {
    }
    kintexu -
    kintexum -
    virtexu -
    virtexum {
    }
    default {
      puts " -E- architecture $architecture is not supported."
      incr error
    }
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  set table [[namespace parent]::Table::Create {IO Ports Summary}]
  $table header [list {Port} {Dir} {Coord} {Package pin} {IO Bank} {Clock Region} {IDELAY} {ODELAY} {ILOGIC} {OLOGIC} {Info}]

  set output [list]
  set noOFF 0
  set noIFF 0
  set noUnconnected 0

  # This is the part that loops through the instantiated ports in the design
  # and gets various information for each.  Result is displayed in a table.
  foreach port [lsort -dictionary [get_ports -quiet]] {
    set info {}
    set bank [get_iobanks -quiet -of $port]
    set sitename [get_sites -quiet -of $port]
    set sitetype [string range $sitename 0 [string last "_" $sitename]-1]
    if {[string match -nocase $sitetype "IOB"]>0} {
      set pp [get_property -quiet PACKAGE_PIN $port]
      set dir [get_property -quiet DIRECTION $port]
      set CR [get_clock_regions -quiet -of [get_sites -of $port]]
      # The LOC information on a top-level port must be extracted as below:
      set tileloc [get_sites -quiet -of_object $pp]
#       set tileloc [get_property LOC $port]
      set coord [string range $tileloc [string last "_" $tileloc]+1 end]

      # Determine if anything has been instantiated in the IDELAY block in the same
      # tile region
      set idelay_used {}
      set odelay_used {}
      set ilogic_used {}
      set ologic_used {}
      switch $architecture {
        artix7 -
        kintex7 -
        virtex7 -
        zynq {
          set idelay_used [get_cells -quiet -of [get_sites -quiet "IDELAY_$coord"]]
          set odelay_used [get_cells -quiet -of [get_sites -quiet "ODELAY_$coord"]]
          set ilogic_used [get_cells -quiet -of [get_sites -quiet "ILOGIC_$coord"]]
          set ologic_used [get_cells -quiet -of [get_sites -quiet "OLOGIC_$coord"]]
        }
        kintexu -
        kintexum -
        virtexu -
        virtexum {
          # Support for both Component/Native modes
          set idelay_used [get_cells -quiet -of [concat [get_bels -quiet "BITSLICE_RX_TX_$coord/IDELAY"] \
                                                        [get_bels -quiet "BITSLICE_RX_TX_$coord/RX_BITSLICE"] \
                                                        [get_bels -quiet "BITSLICE_RX_TX_$coord/RXTX_BITSLICE"] ]]
          set odelay_used [get_cells -quiet -of [concat [get_bels -quiet "BITSLICE_RX_TX_$coord/ODELAY"] \
                                                        [get_bels -quiet "BITSLICE_RX_TX_$coord/TX_BITSLICE"] \
                                                        [get_bels -quiet "BITSLICE_RX_TX_$coord/TX_BITSLICE_TRI"] \
                                                        [get_bels -quiet "BITSLICE_RX_TX_$coord/RXTX_BITSLICE"] ]]
#           set idelay_used [get_cells -quiet -of [get_bels -quiet "BITSLICE_RX_TX_$coord/IDELAY"]]
#           set odelay_used [get_cells -quiet -of [get_bels -quiet "BITSLICE_RX_TX_$coord/ODELAY"]]
          set ilogic_used [get_cells -quiet -of [get_bels -quiet "BITSLICE_RX_TX_$coord/IN_FF"]]
          set ologic_used [get_cells -quiet -of [get_bels -quiet "BITSLICE_RX_TX_$coord/OUT_FF"]]
        }
      }

      # Input ports should have ILOGIC, Output ports should have OLOGIC
      if {[string match -nocase $dir "OUT"]>0} {
        if {[llength $ologic_used] == 0} {
          incr noOFF
          set info {No Output FF}
        }
      } else {
        if {[llength $ilogic_used] == 0} {
          incr noIFF
          set info {No Input FF}
        }
      }

      if {$verbose} {
        $table addrow [list $port $dir $coord $pp $bank $CR $idelay_used $odelay_used $ilogic_used $ologic_used $info]
      } else {
        $table addrow [list $port $dir $coord $pp $bank $CR [llength $idelay_used] [llength $odelay_used] [llength $ilogic_used] [llength $ologic_used] $info ]
      }

    } else {
      # Port with no site ... it is unconnected
      set pp [get_property -quiet PACKAGE_PIN $port]
      set dir [get_property -quiet DIRECTION $port]
      # The LOC information on a top-level port must be extracted as below:
      set tileloc [get_sites -quiet -of_object $pp]
#       set tileloc [get_property LOC $port]
      set coord [string range $tileloc [string last "_" $tileloc]+1 end]
      $table addrow [list $port $dir $coord $pp $bank {} {} {} {} {} {Unconnected}]
      incr noUnconnected
    }
  }

  # Print out the summary table
  lappend output ""
  set output [concat $output [split [$table print] \n] ]

  # Display a warning message if no OFF or IFF is detected
  lappend output "\n # Ports with no Input FF: $noIFF"
  lappend output " # Ports with no Output FF: $noOFF"
  lappend output " # Unconnected Ports: $noUnconnected"

  if {$filename !={}} {
    set FH [open $filename $mode]
    puts $FH [::tclapp::xilinx::ultrafast::generate_file_header {report_io_reg}]
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

