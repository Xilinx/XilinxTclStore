# Example of report:
#
#  vivado% tclapp::xilinx::designutils::report_nets -net CL/xcl_design_i/expanded_region/u_ocl_region/dr_i/*/inst/rst* -file nets.rpt -min 10 -plot -thresh 10000
#
#   +---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
#   | Nets Summary                                                                                                                                                                                                                                                                                                                                                  |
#   +-------+-----------------------------------------------------------------------------------------------+------------+--------+-----------+------------+------------+-----------------------------------------------------------------+-------------------------------------------------------------------------------------------------------------------------+
#   | Index | Net Name                                                                                      | Driver Pin | Fanout | Inter-SLR | DONT_TOUCH | MARK_DEBUG | Unique Loads                                                    | Driver Pin Name                                                                                                         |
#   +-------+-----------------------------------------------------------------------------------------------+------------+--------+-----------+------------+------------+-----------------------------------------------------------------+-------------------------------------------------------------------------------------------------------------------------+
#   | 1     | CL/xcl_design_i/expanded_region/u_ocl_region/dr_i/lstm_axi_top_vu9p_bot_1/inst/rst            | BUFGCE/O   | 5474   | 0         | 0          | 0          | FDPE FDRE FDSE                                                  | CL/xcl_design_i/expanded_region/u_ocl_region/dr_i/lstm_axi_top_vu9p_bot_1/inst/inst_c1_mmu_dma_top/rst_reg_bufg_place/O |
#   | 2     | CL/xcl_design_i/expanded_region/u_ocl_region/dr_i/lstm_axi_top_vu9p_bot_1/inst/rst_bufg_place | FDRE/Q     | 2404   | 0         | 0          | 0          | BUFGCE FDRE FDSE FIFO18E2 LUT2 LUT3 LUT4 LUT5 LUT6 URAM288_BASE | CL/xcl_design_i/expanded_region/u_ocl_region/dr_i/lstm_axi_top_vu9p_bot_1/inst/inst_c1_mmu_dma_top/rst_reg/Q            |
#   | 3     | CL/xcl_design_i/expanded_region/u_ocl_region/dr_i/lstm_axi_top_vu9p_mid_1/inst/rst            | BUFGCE/O   | 2830   | 0         | 0          | 0          | FDPE FDRE FDSE                                                  | CL/xcl_design_i/expanded_region/u_ocl_region/dr_i/lstm_axi_top_vu9p_mid_1/inst/inst_c1_mmu_dma_top/rst_reg_bufg_place/O |
#   | 4     | CL/xcl_design_i/expanded_region/u_ocl_region/dr_i/lstm_axi_top_vu9p_mid_1/inst/rst_bufg_place | FDRE/Q     | 5048   | 0         | 0          | 0          | BUFGCE FDRE FDSE FIFO18E2 LUT2 LUT3 LUT4 LUT5 LUT6 URAM288_BASE | CL/xcl_design_i/expanded_region/u_ocl_region/dr_i/lstm_axi_top_vu9p_mid_1/inst/inst_c1_mmu_dma_top/rst_reg/Q            |
#   | 5     | CL/xcl_design_i/expanded_region/u_ocl_region/dr_i/lstm_axi_top_vu9p_top_1/inst/rst            | BUFGCE/O   | 7489   | 0         | 0          | 0          | FDPE FDRE FDSE                                                  | CL/xcl_design_i/expanded_region/u_ocl_region/dr_i/lstm_axi_top_vu9p_top_1/inst/inst_c1_mmu_dma_top/rst_reg_bufg_place/O |
#   | 6     | CL/xcl_design_i/expanded_region/u_ocl_region/dr_i/lstm_axi_top_vu9p_top_1/inst/rst_bufg_place | FDRE/Q     | 3058   | 0         | 0          | 0          | BUFGCE FDRE FDSE FIFO18E2 LUT2 LUT3 LUT4 LUT5 LUT6 URAM288_BASE | CL/xcl_design_i/expanded_region/u_ocl_region/dr_i/lstm_axi_top_vu9p_top_1/inst/inst_c1_mmu_dma_top/rst_reg/Q            |
#   +-------+-----------------------------------------------------------------------------------------------+------------+--------+-----------+------------+------------+-----------------------------------------------------------------+-------------------------------------------------------------------------------------------------------------------------+
#
#   (1) Clock/Signal Net: CL/xcl_design_i/expanded_region/u_ocl_region/dr_i/lstm_axi_top_vu9p_bot_1/inst/rst
#    Fanout:        5474
#    Source:        BUFGCE/O
#    Unique Loads to Non-Clock Pin: FDPE/PRE FDRE/R FDSE/S
#    +-------------------+
#    | Non-Clock Pin Loads |
#    +------+-----+------+
#    | Cell | Pin | #    |
#    +------+-----+------+
#    | FDPE | PRE | 256  |
#    | FDRE | R   | 5117 |
#    | FDSE | S   | 101  |
#    +------+-----+------+
#    +----------------------------------------------+
#    | Driver: CL/xcl_design_i/expanded_region/u_ocl_region/dr_i/lstm_axi_top_vu9p_bot_1/inst/inst_c1_mmu_dma_top/rst_reg_bufg_place/O |
#    | Cell: BUFGCE                                 |
#    | Fanout: 5474                                 |
#    | Clock:                                       |
#    | CLOCK_ROOT: X2Y2                             |
#    +-----+----+-----+-------------+-----+----+----+
#    |     | X0 | X1  | X2          | X3  | X4 | X5 |
#    +-----+----+-----+-------------+-----+----+----+
#    | Y14 |    |     |             |     |    |    |
#    | Y13 |    |     |             |     |    |    |
#    | Y12 |    |     |             |     |    |    |
#    | Y11 |    |     |             |     |    |    |
#    | Y10 |    |     |             |     |    |    |
#    +-----+----+-----+-------------+-----+----+----+
#    |  Y9 |    |     |             |     |    |    |
#    |  Y8 |    |     |             |     |    |    |
#    |  Y7 |    |     |             |     |    |    |
#    |  Y6 |    |     |             |     |    |    |
#    |  Y5 |    |     |             |     |    |    |
#    +-----+----+-----+-------------+-----+----+----+
#    |  Y4 |    |     |           3 |     |    |    |
#    |  Y3 | 74 | 316 |        2230 | 479 |    |    |
#    |  Y2 | 60 | 298 | (R) (D) 824 | 953 |    |    |
#    |  Y1 |  2 |  84 |         107 |  36 |    |    |
#    |  Y0 |    |   6 |           2 |     |    |    |
#    +-----+----+-----+-------------+-----+----+----+

package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {                                    
  namespace export report_nets
}

proc ::tclapp::xilinx::designutils::report_nets {args} {
  # Summary : Generate a report for specified nets

  # Argument Usage:
  # [-nets <arg>]: Net(s)
  # [-type <arg>]: Net type (SIGNAL|CLOCK|ALL)
  # [-cells <arg>]: Nets driven by the cells
  # [-summary]: Generate net summary table only
  # [-slack]: Include the slack to the report
  # [-clock]: Include the clock domains to the report
  # [-load_pins]: Show unique load pins in the summary table
  # [-plot]: Show the plot of driver/loads
  # [-expand]: Show the expanded table of leaf pins
  # [-max_fanout <arg>]: Max fanout limit for nets to be considered
  # [-min_fanout <ar>]: Min fanout limit for nets to be considered
  # [-threshold <arg>]: Max net fanout limit to get the detailed reports
  # [-file]: Report file name
  # [-append]: Append to file
  # [-csv]: CSV format
  # [-mark_leafs]: Add a marker on all leaf pins
  # [-highlight_leafs]: Highlight all the leaf pins
  # [-show_ancestor]: Show ancestor on the plot graph
  # [-verbose]: Verbose mode
  # [-return_string]: Return report as string

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened
  
  # Categories: xilinxtclstore, designutils
  
  return [::tclapp::xilinx::designutils::report_nets::report_nets {*}$args]
}

namespace eval ::tclapp::xilinx::designutils::report_nets {
  namespace export report_nets
  variable version {2022.12.06}
  variable params
  variable output {}
  array set params [list format {table} verbose 0 debug 0 debug_level 1]
}

proc ::tclapp::xilinx::designutils::report_nets::lshift {inputlist} {
  # Summary : Report all the available nets in inputlist

  # Argument Usage:

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened
  
  # Categories: xilinxtclstore, designutils
	
  upvar $inputlist argv    
  set arg  [lindex $argv 0]
  set argv [lrange $argv 1 end]
  return $arg
}

proc ::tclapp::xilinx::designutils::report_nets::report_nets { args } {
  # Summary : Report all the available nets in args

  # Argument Usage:
   # args : command line option (-help option for more details)

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened
  
  # Categories: xilinxtclstore, designutils
	
  variable version
  variable params
  #-------------------------------------------------------
  # Process command line arguments
  #-------------------------------------------------------
  set params(verbose) 0
  set params(debug) 0
  set params(debug_level) 1
  set params(format) {table}
  set error 0
  set filename {}
  set filemode {w}
  set FH {}
  set cellName {}
  set netName {}
  set netType {all}
  set summaryOnly 0
  set showClockDomains 0
  set showSlack 0
  set showPlot 0
  set showPlotAncestor 0
  set showExpandedLeafPinsTable 0
  set showLoadPinsSummaryTable 0
  set returnString 0
  set minFanout 0
  set maxFanout 1000000
  set thresholdFanout 250
  set markLeafPins 0
  set highlistLeafPins 0
  set help 0
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-nets$} -
      {^-n(e(ts?)?)?$} {
        set netName [concat $netName [lshift args]]
      }
      {^-cells$} -
      {^-ce(l(ls?)?)?$} {
        set cellName [concat $cellName [lshift args]]
      }
      {^-type$} -
      {^-t(y(pe?)?)?$} {
        set netType [lshift args]
      }
      {^-summary$} -
      {^-s(u(m(m(a(ry?)?)?)?)?)?$} {
        set summaryOnly 1
      }
      {^-clocks$} -
      {^-cl(o(c(ks?)?)?)?$} {
        set showClockDomains 1
      }
      {^-sl(a(ck?)?)?} -
      {^-slack$} {
        set showSlack 1
      }
      {^-pl(ot?)?} -
      {^-plot$} {
        set showPlot 1
      }
      {^-lo(a(d(_(p(i(ns?)?)?)?)?)?)?$} -
      {^-load_pins$} {
        set showLoadPinsSummaryTable 1
      }
      {^-sh(o(w(_(a(n(c(e(s(t(or?)?)?)?)?)?)?)?)?)?)?$} -
      {^-show_ancestor$} {
        set showPlotAncestor 1
      }
      {^-ex(p(a(nd?)?)?)?} -
      {^-expand$} {
        set showExpandedLeafPinsTable 1
      }
      {^-min_fanout$} -
      {^-mi(n(_(f(a(n(o(ut?)?)?)?)?)?)?)?$} {
        set minFanout [lshift args]
      }
      {^-max_fanout$} -
      {^-ma(x(_(f(a(n(o(ut?)?)?)?)?)?)?)?$} {
        set maxFanout [lshift args]
      }
      {^-threshold$} -
      {^-t(h(r(e(s(h(o(ld?)?)?)?)?)?)?)?$} {
        set thresholdFanout [lshift args]
      }
      {^-file$} -
      {^-f(i(le?)?)?$} {
        set filename [lshift args]
        if {$filename == {}} {
          puts " -E- no filename specified."
          incr error
        }
      }
      {^-append$} -
      {^-a(p(p(e(nd?)?)?)?)?$} {
        set filemode {a}
      }
      {^-c(sv?)?$} -
      {^-csv$} {
        set params(format) {csv}
      }
      {^-return_string$} -
      {^-r(e(t(u(r(n(_(s(t(r(i(ng?)?)?)?)?)?)?)?)?)?)?)?$} {
        set returnString 1
      }
      {^-verbose$} -
      {^-v(e(r(b(o(se?)?)?)?)?)?$} {
        set verbose 1
        set params(verbose) 1
      }
      {^-d(e(b(ug?)?)?)?$} {
        set params(debug) 1
      }
      {^--debug-level$} -
      {^-debug_level$} {
        set params(debug_level) [lshift args]
      }
      {^--debug-mark-leafs?$} -
      {^--mark-leafs?$} -
      {^-ma(r(k(_(l(e(a(fs?)?)?)?)?)?)?)?$} {
        set markLeafPins 1
      }
      {^--debug-highlight-leafs?$} -
      {^--highlight-leafs?$} -
      {^-hi(g(h(l(i(g(h(t(_(l(e(a(fs?)?)?)?)?)?)?)?)?)?)?)?)?$} {
        set highlistLeafPins 1
      }
      {^-help$} -
      {^-h(e(lp?)?)?$} {
        set help 1
      }
      {^--version$} {
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
  Usage: ::xilinx::designutils::report_nets
              [-nets <net(s)>]         - Net(s)
              [-type <name>]           - Net type (SIGNAL|CLOCK|ALL)
                                         Default: ALL
              [-cells <cells(s)>]      - Nets driven by the cells
              [-summary]               - Generate net summary table only
              [-slack]                 - Include the slack to the report
              [-clock]                 - Include the clock domains to the report
              [-load_pins]             - Show unique load pins in the summary table
              [-plot]                  - Show the plot of driver/loads
              [-expand]                - Show the expanded table of leaf pins
              [-max_fanout <int>]      - Max fanout limit for nets to be considered
                                         Default: 1000000
              [-min_fanout <int>]      - Min fanout limit for nets to be considered
                                         Default: 0
              [-threshold <int>]       - Max net fanout limit to get the detailed reports
                                         Default: 250
              [-file]                  - Report file name
              [-append]                - Append to file
              [-csv]                   - CSV format
              [-mark_leafs]            - Add a marker on all leaf pins
              [-highlight_leafs]       - Highlight all the leaf pins
              [-show_ancestor]         - Show ancestor on the plot graph
              [-verbose]               - Verbose mode
              [-return_string]         - Return report as string
              [-help|-h]               - This help message

  Description: Generates a Net Loads Report

     Version: %s

     This command creates a net load report. All nets matching a type or name pattern
     are discovered. The fanout, driver and loads are captured. A unique list of load
     cells is generated. Each unique cell is searched for in the netload cells list.

  Example:
     tclapp::xilinx::designutils::report_nets -type clock
     tclapp::xilinx::designutils::report_nets -net [get_selected_objects] -clock -slack -plot -show_ancestor -clock
     tclapp::xilinx::designutils::report_nets -net *reset* -summary -clock -slack -file my_report.rpt
} $version ]
    # HELP -->
    return {}
  }

  if {($netName == {}) && ($cellName == {})} {
    puts " -E- no net specified (-net)"
    incr error
  }

  if {($netName != {}) && ($cellName != {})} {
    puts " -E- -nets/cells are mutually exclusive"
    incr error
  }

  if {$returnString && ($filename != {})} {
    puts " -E- -file/-return_string are mutually exclusive"
    incr error
  }

  if {![regexp {^[0-9]+$} $thresholdFanout]} {
    puts " -E- invalid -threshold value. Should be an integer"
    incr error
  }

  if {![regexp {^[0-9]+$} $maxFanout]} {
    puts " -E- invalid -max_fanout value. Should be an integer"
    incr error
  }

  if {![regexp {^[0-9]+$} $minFanout]} {
    puts " -E- invalid -min_fanout value. Should be an integer"
    incr error
  }
  switch [string toupper $netType] {
    SIGNAL -
    CLOCK -
    ALL {
      set netType [string toupper $netType]
    }
    default {
      puts " -E- invalid net type '$netType'. The valid values are: clock | signal | all"
      incr error
    }
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }
  set start [clock seconds]
  set systemTime [clock seconds]
  set netCount 0
  set allNets [list]
  set output [list]
  set tableSummary [::tclapp::xilinx::designutils::prettyTable]
  set table [::tclapp::xilinx::designutils::prettyTable]

  set rejectedNets [list]
  if {$cellName != {}} {
    set allNets [get_nets -quiet -of [get_pins -quiet -of [get_cells -quiet -hier $cellName] -filter {DIRECTION == OUT}]]
    # Filter by min/max fanout
    set rejectedNets [lsort -dictionary [filter $allNets -filter "FLAT_PIN_COUNT<=$minFanout || FLAT_PIN_COUNT>=$maxFanout"]]
    set allNets [lsort -dictionary [filter $allNets -filter "FLAT_PIN_COUNT>$minFanout && FLAT_PIN_COUNT<$maxFanout"]]
  } else {
    # Filter by min/max fanout
#     set allNets [lsort -dictionary [filter [get_nets -quiet -top_net_of_hierarchical_group -hierarchical $netName] -filter "FLAT_PIN_COUNT>$minFanout && FLAT_PIN_COUNT<$maxFanout"]]
    set rejectedNets [lsort -dictionary [filter [get_nets -quiet -top_net_of_hierarchical_group $netName] -filter "FLAT_PIN_COUNT<=$minFanout || FLAT_PIN_COUNT>=$maxFanout"]]
    set allNets [lsort -dictionary [filter [get_nets -quiet -top_net_of_hierarchical_group $netName] -filter "FLAT_PIN_COUNT>$minFanout && FLAT_PIN_COUNT<$maxFanout"]]
  }
  if {[llength $rejectedNets]} {
    foreach n $rejectedNets {
      puts " -W- net '$n' is skipped due to fanout limit (min:$minFanout / max:$maxFanout)"
    }
  }

  # Additional filter by type?
  switch $netType {
    ALL {
    }
    default {
      set allNets [filter -quiet $allNets "TYPE=~*$netType*"]
    }
  }
  set allPinCounts [get_property -quiet FLAT_PIN_COUNT $allNets]

  puts " -I- Processing [llength $allNets] nets ..."

  # Define the summary table of all the nets
  # +---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
  # | Nets Summary                                                                                                                                                                                                                                                                                                                                                                                            |
  # +-------+---------------------------------------------------------+---------------------+--------+-----------+------------+------------+-------+--------------+----------------------------------------------------+-------------------------------+-------------------------------+--------------------------------------------------------------------------------------+-------------------------------+
  # | Index | Net Name                                                | Driver Pin          | Fanout | Inter-SLR | DONT_TOUCH | MARK_DEBUG | Slack | Unique Loads | Driver Pin Name                                    | Clock Domain Driver Pin       | Clock Domain Load Pins        | Clock Domain Driver Cell                                                             | Clock Domain Load Cells       |
  # +-------+---------------------------------------------------------+---------------------+--------+-----------+------------+------------+-------+--------------+----------------------------------------------------+-------------------------------+-------------------------------+--------------------------------------------------------------------------------------+-------------------------------+
  # | 1     | design_1_i/clk_wiz_1/inst/clk_out1_design_1_clk_wiz_1_0 | MMCME3_ADV/CLKOUT0  | 1      | 0         | 0          | 0          |       | BUFGCE       | design_1_i/clk_wiz_1/inst/mmcme3_adv_inst/CLKOUT0  | clk_out1_design_1_clk_wiz_1_0 | clk_out1_design_1_clk_wiz_1_0 | clk_out1_design_1_clk_wiz_1_0 clkfbout_design_1_clk_wiz_1_0 default_sysclk_300_clk_p | clk_out1_design_1_clk_wiz_1_0 |
  # | 2     | design_1_i/clk_wiz_1/inst/clkfbout_design_1_clk_wiz_1_0 | MMCME3_ADV/CLKFBOUT | 1      | 0         | 0          | 0          |       | BUFGCE       | design_1_i/clk_wiz_1/inst/mmcme3_adv_inst/CLKFBOUT | clkfbout_design_1_clk_wiz_1_0 | clkfbout_design_1_clk_wiz_1_0 | clk_out1_design_1_clk_wiz_1_0 clkfbout_design_1_clk_wiz_1_0 default_sysclk_300_clk_p | clkfbout_design_1_clk_wiz_1_0 |
  # | 3     | design_1_i/clk_wiz_1/inst/locked                        | MMCME3_ADV/LOCKED   | 1      | 0         | 0          | 0          |       | LUT4         | design_1_i/clk_wiz_1/inst/mmcme3_adv_inst/LOCKED   |                               |                               | clk_out1_design_1_clk_wiz_1_0 clkfbout_design_1_clk_wiz_1_0 default_sysclk_300_clk_p |                               |
  # +-------+---------------------------------------------------------+---------------------+--------+-----------+------------+------------+-------+--------------+----------------------------------------------------+-------------------------------+-------------------------------+--------------------------------------------------------------------------------------+-------------------------------+
  $tableSummary reset
  $tableSummary indent 0
  $tableSummary title {Nets Summary}
  $tableSummary header [list {Index} {Net Name} {Driver Pin} {Fanout} {Inter-SLR} {DONT_TOUCH} {MARK_DEBUG} {Slack} {Unique Loads} {Driver Pin Name} {Clock Domain Driver Pin} {Clock Domain Load Pins} {Clock Domain Driver Cell} {Clock Domain Load Cells} ]

  foreach net $allNets pinCount $allPinCounts {
    # Progress bar
#     progressBar $netCount [llength $allNets]

    set netPins [get_pins -quiet -of $net -leaf]
    set driverPin [filter -quiet $netPins {DIRECTION==OUT}]
    if {$driverPin == {}} {
      set driverPin [get_ports -quiet -of $net -filter {DIRECTION==IN}]
      set driverCell $driverPin
      set driverRef {<PORT>}
      # When the driver is a port, it is not included inside the FLAT_PIN_COUNT property, so
      # it should not be removed from the fanout calculation
      set netFan $pinCount
    } else {
      set driverCell [get_cells -quiet -of $driverPin]
      set driverRef [format {%s/%s} [get_property -quiet REF_NAME $driverPin] [get_property -quiet REF_PIN_NAME $driverPin] ]
      # Remove the driver from the fanout calculation
      set netFan [expr $pinCount -1]
    }
    set netLoadPins [filter -quiet $netPins {DIRECTION==IN}]
    set netLoadCells [get_cells -quiet -of_objects $netLoadPins]

    if {$highlistLeafPins} {
      highlight_objects -quiet -color green $driverPin
      highlight_objects -quiet -color orange $netLoadPins
    }
    if {$markLeafPins} {
      mark_objects -quiet -color green $driverPin
      mark_objects -quiet -color orange $netLoadPins
    }

    set slack {-}
    if {$showSlack} {
#       set slack [get_property -quiet SLACK [get_timing_path -quiet -setup -from $driverPin -max 1 -nworst 1]]
      set slack [get_property -quiet SLACK [get_timing_path -quiet -setup -through $driverPin -max 1 -nworst 1]]
    }

    set allNetSegments [get_nets -quiet -segments $net]
    if {[lsearch [get_property -quiet DONT_TOUCH $allNetSegments] {1}] != -1} {
      set dontTouch 1
    } else {
      set dontTouch 0
#       # No DONT_TOUCH found on net segments.
#       # Check now that DONT_TOUCH is not set on hierarchical modules
#       set parents [getParentCells $netLoadCells]
#       set dontTouchHierCells [filter -quiet $parents {DONT_TOUCH}]
#       if {[llength $dontTouchHierCells]} {
#         set dontTouch 1
#       } else {
#         set dontTouch 0
#       }
    }
    if {[lsearch [get_property -quiet MARK_DEBUG $allNetSegments] {1}] != -1} {
      set markDebug 1
    } else {
      set markDebug 0
    }
    if {[get_slrs -quiet -of_objects $driverCell] != [get_slrs -quiet -of_objects $netLoadCells]} {
      set interSlr 1
    } else {
      set interSlr 0
    }

    if {$netLoadPins == {}} {
      # No leaf pin load (i.e. net connected to output port)
      continue
    }

    if {($netFan > $maxFanout) || ($netFan < $minFanout)} {
      # Skip nets that do not fit the fanout condition from the detailed report
      continue
    }

    set uniqueLoads [list]
    if {$showLoadPinsSummaryTable} {
      # Column "Unique Loads" should report a distribution of the load pins:
      # E.g: FDCE/C (204730) FDPE/C (26) FDRE/C (130873) FDSE/C (5218) HARD_SYNC/CLK (1) RAMB36E2/CLKARDCLK (196)
      catch {unset tmp}
      foreach pin $netLoadPins \
              refname [get_property -quiet REF_NAME $netLoadPins] \
              refpinname [get_property -quiet REF_PIN_NAME $netLoadPins] {
        incr tmp([format {%s/%s} $refname $refpinname])
      }
      foreach el [lsort -dictionary [array names tmp]] {
        lappend uniqueLoads [format {%s (%s)} $el $tmp($el)]
      }
      set uniqueLoads [join $uniqueLoads { }]
    } else {
      # Column "Unique Loads" should report the list of the load cells:
      # E.g: FDCE FDPE FDRE FDSE HARD_SYNC RAMB36E2 RAMD32 RAMS32 SRL16E SRLC16E SRLC32E
      set uniqueLoads [lsort -unique [get_property REF_NAME -quiet $netLoadCells]]
    }

    incr netCount

    # Update the summary table
    if {$showClockDomains} {
      $tableSummary addrow [list $netCount \
                             $net \
                             $driverRef \
                             $netFan \
                             $interSlr \
                             $dontTouch \
                             $markDebug \
                             $slack \
                             $uniqueLoads \
                             $driverPin \
                             [lsort [get_clocks -quiet -of_objects $driverPin]] \
                             [lsort [get_clocks -quiet -of_objects $netLoadPins]] \
                             [lsort [get_clocks -quiet -of_objects $driverCell]] \
                             [lsort [get_clocks -quiet -of_objects $netLoadCells]] \
                       ]
    } else {
      $tableSummary addrow [list $netCount \
                             $net \
                             $driverRef \
                             $netFan \
                             $interSlr \
                             $dontTouch \
                             $markDebug \
                             $slack \
                             $uniqueLoads \
                             $driverPin \
                             {-} \
                             {-} \
                             {-} \
                             {-} \
                       ]
    }

    if {$summaryOnly} {
      # Skip detailed reports and process next net
      continue
    }

    if {$netFan > $thresholdFanout} {
      # Skip nets that do not fit the fanout condition from the detailed report
      lappend output [format "\n(%-d) %-7s %-s **DETAILED REPORTS SKIPPED (fanout=$netFan)** " ${netCount} {Net:} $net]
      if {$params(verbose)} {
#         lappend output [format "\n(%-d) %-7s %-s **DETAILED REPORTS SKIPPED (fanout=$netFan)** " ${netCount} {Net:} $net]
      }
      # Plot?
      if {$showPlot} {
        if {$showPlotAncestor} {
          set res [plot $netPins -ancestor 1]
        } else {
          set res [plot $netPins -ancestor 0]
        }
        set output [concat $output [split $res \n] ]
      }
      continue
    }

    # List for all the loads so that it can be sorted out
    set nonClockPinloads [list]
    set clockPinloads [list]
    # Array to extract the list of count per unique load
    catch {unset uniqueClockPinLoads}
    catch {unset uniqueNonClockPinLoads}
    if {$showExpandedLeafPinsTable} {
      # In -details mode, some pre processing is done to be able to generate the
      # detailed tables. Since this is runtime intensive, only run this code in
      # this mode
      foreach pin $netLoadPins \
              isClock [get_property -quiet {IS_CLOCK} $netLoadPins] \
              refname [get_property -quiet REF_NAME $netLoadPins] \
              refpinname [get_property -quiet REF_PIN_NAME $netLoadPins] {
        set pinname [format {%s/%s} $refname $refpinname ]
        if {$isClock} {
          incr uniqueClockPinLoads($pinname) 1
          lappend clockPinloads [list $pin $pinname]
        } else {
          incr uniqueNonClockPinLoads($pinname) 1
          lappend nonClockPinloads [list $pin $pinname]
        }
      }
      # Sort 'clockPinloads' and 'nonClockPinloads' first on the cell name
      set clockPinloads [lsort -dictionary -index 0 $clockPinloads]
      set nonClockPinloads [lsort -dictionary -index 0 $nonClockPinloads]
      # ... then on the cell ref name
      set clockPinloads [lsort -dictionary -index 1 $clockPinloads]
      set nonClockPinloads [lsort -dictionary -index 1 $nonClockPinloads]
    } else {
      # When -details is not used, simplify the code so that only the 'uniqueLoads'
      # array is being built
      foreach pin $netLoadPins \
              isClock [get_property -quiet {IS_CLOCK} $netLoadPins] \
              refname [get_property -quiet REF_NAME $netLoadPins] \
              refpinname [get_property -quiet REF_PIN_NAME $netLoadPins] {
        set pinname [format {%s/%s} $refname $refpinname ]
        if {$isClock} {
          if {![info exists uniqueClockPinLoads($pinname)]} { set uniqueClockPinLoads($pinname) 0 }
          incr uniqueClockPinLoads($pinname) 1
        } else {
          if {![info exists uniqueNonClockPinLoads($pinname)]} { set uniqueNonClockPinLoads($pinname) 0 }
          incr uniqueNonClockPinLoads($pinname) 1
        }
      }
    }

    switch $netType {
      CLOCK {
        lappend output [format "\n(%-d) %-7s %-s" ${netCount} {Clock Net:} $net]
      }
      SIGNAL {
        lappend output [format "\n(%-d) %-7s %-s" ${netCount} {Signal Net:} $net]
      }
      ALL {
        lappend output [format "\n(%-d) %-7s %-s" ${netCount} {Clock/Signal Net:} $net]
      }
    }
    lappend output [format "   %-14s %-14d" Fanout: $netFan]
    if {$showExpandedLeafPinsTable == 1 }  {
      lappend output [format "   %-14s %-s" {Source Pin:} $driverCell]
    }
    lappend output [format "   %-14s %-s" Source: $driverRef]
    if {[info exists uniqueNonClockPinLoads]} {
      lappend output [format "   %-14s %-s" {Unique Loads to Non-Clock Pin:} [lsort -unique [array names uniqueNonClockPinLoads]]]
    }
    if {[info exists uniqueClockPinLoads]} {
      lappend output [format "   %-14s %-s" {Unique Loads to Clock Pin:} [lsort -unique [array names uniqueClockPinLoads]]]
    }

    if {[info exists uniqueNonClockPinLoads]} {
      # +-----------+-------+------+
      # | Non-Clock Pin Loads      |
      # +-----------+-------+------+
      # | Cell      | Pin   | #    |
      # +-----------+-------+------+
      # | FDPE      | PRE   | 256  |
      # | FDRE      | R     | 5117 |
      # | FDSE      | S     | 101  |
      # | PLLE4_ADV | CLKIN | 3    |
      # +-----------+-------+------+
      $table reset
      $table indent 3
      $table title {Non-Clock Pin Loads}
      $table header [list {Cell} {Pin} {#}]
      foreach elm [lsort [array names uniqueNonClockPinLoads]] {
        foreach {cellname pinname} [split $elm {/}] { break }
        $table addrow [list $cellname $pinname $uniqueNonClockPinLoads($elm)]
      }
      set output [concat $output [split [$table export -format $params(format)] \n] ]
    }
    if {[info exists uniqueClockPinLoads]} {
      # +-------------------------------+
      # | Clock Pin Loads               |
      # +----------+-----------+--------+
      # | Cell     | Pin       | #      |
      # +----------+-----------+--------+
      # | FDCE     | C         | 587    |
      # | FDPE     | C         | 234    |
      # | FDRE     | C         | 117970 |
      # | RAMB18E2 | CLKARDCLK | 5      |
      # | RAMB18E2 | CLKBWRCLK | 4      |
      # | SRL16E   | CLK       | 1411   |
      # | SRLC32E  | CLK       | 4672   |
      # +----------+-----------+--------+
      $table reset
      $table indent 3
      $table title {Clock Pin Loads}
      $table header [list {Cell} {Pin} {#}]
      foreach elm [lsort [array names uniqueClockPinLoads]] {
        foreach {cellname pinname} [split $elm {/}] { break }
        $table addrow [list $cellname $pinname $uniqueClockPinLoads($elm)]
      }
      set output [concat $output [split [$table export -format $params(format)] \n] ]
    }

    if {$showExpandedLeafPinsTable} {
      if {$nonClockPinloads != {}} {
        # +-----------------------------------------------------------------------------------------------------------------------------+
        # | Detail of All Non-Clock Pins Loads                                                                                          |
        # +------+-----+------------------------------------------------------------------------+-------+-------------------------------+
        # | Cell | Pin | Pin Name                                                               | Slack | Cell Clock Domain             |
        # +------+-----+------------------------------------------------------------------------+-------+-------------------------------+
        # | FDRE | CE  | design_1_i/microblaze_0/U0/exponent_res_reg[0]/CE                      | 4.971 | clk_out1_design_1_clk_wiz_1_0 |
        # | FDRE | CE  | design_1_i/microblaze_0/U0/exponent_res_reg[1]/CE                      | 4.971 | clk_out1_design_1_clk_wiz_1_0 |
        # | FDRE | CE  | design_1_i/microblaze_0/U0/exponent_res_reg[2]/CE                      | 4.971 | clk_out1_design_1_clk_wiz_1_0 |
        # | FDRE | CE  | design_1_i/microblaze_0/U0/exponent_res_reg[3]/CE                      | 4.971 | clk_out1_design_1_clk_wiz_1_0 |
        # | FDRE | CE  | design_1_i/microblaze_0/U0/exponent_res_reg[4]/CE                      | 4.964 | clk_out1_design_1_clk_wiz_1_0 |
        # | LUT2 | I1  | design_1_i/microblaze_0/U0/AddSub_Gen[0].MUXCY_XOR_I/Q_Reg[24]_i_1/I1  | 4.971 |                               |
        # | LUT2 | I1  | design_1_i/microblaze_0/U0/AddSub_Gen[2].MUXCY_XOR_I/R_Reg[0]_i_1/I1   | 4.897 |                               |
        # | LUT2 | I1  | design_1_i/microblaze_0/U0/AddSub_Gen[3].MUXCY_XOR_I/R_Reg[1]_i_1/I1   | 4.922 |                               |
        # +------+-----+------------------------------------------------------------------------+-------+-------------------------------+
        $table reset
        $table indent 3
        $table title {Detail of All Non-Clock Pins Loads}
        $table header [list {Cell} {Pin} {Pin Name} {Slack} {Cell Clock Domain} ]
        foreach elm $nonClockPinloads {
          foreach {pin refname} $elm { break }
          # E.g: $refname == FDRE/C
          foreach {cellname pinname} [split $refname {/}] { break }
          set slack {-}
          if {$showSlack} {
            set slack [get_property -quiet SLACK [get_timing_path -quiet -setup -through $pin -max 1 -nworst 1]]
          }
          set clock {-}
          if {$showClockDomains} {
            set clock [get_clocks -quiet -of_objects [get_cells -quiet -of_objects $pin]]
          }
          $table addrow [list $cellname $pinname $pin $slack $clock ]
        }
        if {$showClockDomains == 0} {
          # If the clock information is not requested, remove the column
          $table delcolumns 4
        }
        if {$showSlack == 0} {
          # If the slack information is not requested, remove the column
          $table delcolumns 3
        }
        set output [concat $output [split [$table export -format $params(format)] \n] ]
      }
      if {$clockPinloads != {}} {
        # +-------------------------------------------------------------------------------------+
        # | Detail of All Clock Pins Loads                                                      |
        # +--------+-----+--------------------------------------+-------------------------------+
        # | Cell   | Pin | Pin Name                             | Pin Clock Domain              |
        # +--------+-----+--------------------------------------+-------------------------------+
        # | BUFGCE | I   | design_1_i/clk_wiz_1/inst/clkf_buf/I | clkfbout_design_1_clk_wiz_1_0 |
        # +--------+-----+--------------------------------------+-------------------------------+
        $table reset
        $table indent 3
        $table title {Detail of All Clock Pins Loads}
        # Timing slack is not reported on clock leaf pins
        $table header [list {Cell} {Pin} {Pin Name} {Pin Clock Domain} ]
        foreach elm $clockPinloads {
          foreach {pin refname} $elm { break }
          # E.g: $refname == FDRE/C
          foreach {cellname pinname} [split $refname {/}] { break }
          set clock {-}
          if {$showClockDomains} {
            set clock [get_clocks -quiet -of_objects $pin]
          }
          $table addrow [list $cellname $pinname $pin $clock ]
        }
        if {$showClockDomains == 0} {
          # If the clock information is not requested, remove the column
          $table delcolumns 3
        }
        set output [concat $output [split [$table export -format $params(format)] \n] ]
      }
    }

    # Plot?
    if {$showPlot} {
      if {$showPlotAncestor} {
        set res [plot $netPins -ancestor 1]
      } else {
        set res [plot $netPins -ancestor 0]
      }
      set output [concat $output [split $res \n] ]
    }

  }

  # To keep the columns index unchanged, columns must be deleted from the
  # latest one to the first one
  if {$showClockDomains == 0} {
    # If the clock information is not requested, remove the column
    $tableSummary delcolumns {10 11 12 13}
  }
  if {$showSlack == 0} {
    # If the slack information is not requested, remove the column
    $tableSummary delcolumns 7
  }

  set end [clock seconds]
  set duration [expr $end - $start]
  switch $netType {
    CLOCK {
      lappend output " -I- Generated report on $netCount clock nets in $duration seconds"
      puts " -I- Generated report on $netCount clock nets in $duration seconds"
    }
    SIGNAL {
      lappend output " -I- Generated report on $netCount signal nets in $duration seconds"
      puts " -I- Generated report on $netCount signal nets in $duration seconds"
    }
    ALL {
      lappend output " -I- Generated report on $netCount clock/signal nets in $duration seconds"
      puts " -I- Generated report on $netCount clock/signal nets in $duration seconds"
    }
  }

  # Add the summary table at the very begining
  set output [concat [split [$tableSummary export -format $params(format)] \n] $output ]

  # Destroy the objects
  catch {$tableSummary destroy}
  catch {$table destroy}

  if {$filename !={}} {
    set FH [open $filename $filemode]
    puts $FH [::tclapp::xilinx::designutils::report_nets::generate_file_header {report_nets}]
    puts $FH [join $output \n]
    close $FH
    puts " -I- Generated file [file normalize $filename]"
    return -code ok
  }

  # Return result as string?
  if {$returnString} {
    return [join $output \n]
  }

  puts [join $output \n]

  return -code ok
}

#   +---------------------------------------------------------------+
#   | PTM_RESERVED_FOR_ENMAPPING_mapped_SCG_SST_logic_4_0/slot_clock[1]_BUFGCE |
#   | BUFGCE                                                        |
#   | Fanout: 2361                                                  |
#   | Clock: microblaze_0_Clk                                       |
#   | CLOCK_ROOT: X7Y7                                              |
#   | USER_CLOCK_ROOT: X7Y7                                         |
#   +-----+----+----+----+-----+----+-----+----+--------------+-----+
#   |     | X0 | X1 | X2 | X3  | X4 | X5  | X6 | X7           | X8  |
#   +-----+----+----+----+-----+----+-----+----+--------------+-----+
#   | Y14 |    | 12 | 13 |  13 | 13 |     |    |              |     |
#   | Y13 |    | 57 | 23 |  19 | 39 |  26 |    |              |     |
#   | Y12 |    | 31 | 14 |  33 | 75 |  14 | 17 |              |     |
#   | Y11 |    | 40 | 26 |  13 |    | 164 | 32 |              |     |
#   | Y10 |    | 26 | 13 |  24 | 48 |  67 | 18 |              |     |
#   +-----+----+----+----+-----+----+-----+----+--------------+-----+
#   |  Y9 |    | 18 |  1 |     |    |     | 10 |          134 | 117 |
#   |  Y8 |    |    | 69 |     |  1 |  27 | 15 |            3 |     |
#   |  Y7 |    |    |    |   3 |  8 |  53 | 59 | (U) (R) (D)  |     |
#   |  Y6 |    | 10 |    |   9 | 77 | 139 | 15 | (A)          |     |
#   |  Y5 |    |    | 43 |  52 |  8 |  18 |    |              |     |
#   +-----+----+----+----+-----+----+-----+----+--------------+-----+
#   |  Y4 |    |    | 52 |  46 | 18 |   3 |  7 |            7 |     |
#   |  Y3 |    |    |    | 123 | 23 |     |    |              |     |
#   |  Y2 |    |    |    |  78 | 28 |  14 | 31 |           18 |     |
#   |  Y1 |    |    |    |     |    |     |  5 |           46 |     |
#   |  Y0 |    |    |    |  19 | 35 |  18 |    |           22 |   9 |
#   +-----+----+----+----+-----+----+-----+----+--------------+-----+

proc ::tclapp::xilinx::designutils::report_nets::plot {pins args} {
  # Summary : Report all the available nets in args

  # Argument Usage:
  #args : command line option (-help option for more details)

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened
  
  # Categories: xilinxtclstore, designutils
	
  variable params
  set defaults [list -file {} -mode {w} -ancestor 0]
  array set options $defaults
  array set options $args

  set channel {stdout}
  if {$options(-file) != {}} {
    set channel [open $options(-file) $options(-mode)]
  }

  set tbl [::tclapp::xilinx::designutils::prettyTable template deviceview]
  $tbl indent 3

  set driver [filter -quiet $pins {DIRECTION == OUT}]
  # Ancestor: driver pin of $driver
  set ancestor [get_pins -quiet -of [get_nets -quiet -of [get_pins -quiet -of [get_cells -quiet -of $driver] -filter {(DIRECTION == IN) && !IS_ENABLE}]] -leaf -filter {DIRECTION == OUT}]
  set loads [filter -quiet $pins {DIRECTION == IN}]
  set net [get_nets -quiet -of $driver]
  set cell [get_cells -quiet -of $driver]

  $tbl cleardevice
#   $tbl cleartable
#   $tbl configure -align_right

  set unplaced [list]
  foreach load [get_cells -quiet -of $loads] {
    set region [get_clock_regions -quiet -of $load]
    if {[regexp {^(S([0-9]))?X([0-9]+)Y([0-9]+)$} $region - - S X Y]} {
      foreach {X Y} [::tclapp::xilinx::designutils::prettyTable::deviceview::region2XY $tbl $region] { break }
      $tbl incrcell $X $Y
    } elseif {$region == {}} {
      lappend unplaced $region
    }
  }

  foreach c [get_cells -quiet -of $driver] {
    set region [get_clock_regions -quiet -of $c]
    if {[regexp {^(S([0-9]))?X([0-9]+)Y([0-9]+)$} $region - - S X Y]} {
      foreach {X Y} [::tclapp::xilinx::designutils::prettyTable::deviceview::region2XY $tbl $region] { break }
    #   $tbl appendcell $X $Y " (D)"
      $tbl prependcell $X $Y "(D) "
    }
  }

  # There can be multiple ancestors when $driver is not a BUFGCE (e.g BUFG_GT)
  # Only report the ancestor when there is a single one
  if {$options(-ancestor) && ([llength $ancestor] == 1)} {
    foreach c [get_cells -quiet -of $ancestor] {
      set region [get_clock_regions -quiet -of $c]
      if {[regexp {^(S([0-9]))?X([0-9]+)Y([0-9]+)$} $region - - S X Y]} {
        foreach {X Y} [::tclapp::xilinx::designutils::prettyTable::deviceview::region2XY $tbl $region] { break }
      #   $tbl appendcell $X $Y " (A)"
        $tbl prependcell $X $Y "(A) "
      }
    }
    set ancestorstr "\nAncestor: [get_property -quiet REF_NAME $ancestor]/[get_property -quiet REF_PIN_NAME $ancestor]\nAncestor Fanout: [expr [get_property -quiet FLAT_PIN_COUNT [get_nets -quiet -of $ancestor]] -1]"
  } else {
    set ancestorstr {}
  }

  set clockRoot [lsort -unique [get_property -quiet CLOCK_ROOT $net]]
  set userClockRoot [lsort -unique [get_property -quiet USER_CLOCK_ROOT $net]]

  if {$clockRoot != {}} {
    foreach root $clockRoot {
      if {[regexp {^(S([0-9]))?X([0-9]+)Y([0-9]+)$} $root - - S X Y]} {
        foreach {X Y} [::tclapp::xilinx::designutils::prettyTable::deviceview::region2XY $tbl $root] { break }
        $tbl prependcell $X $Y "(R) "
      }
    }
  }

  if {$userClockRoot != {}} {
    if {[regexp {^(S([0-9]))?X([0-9]+)Y([0-9]+)$} $userClockRoot - - S X Y]} {
      foreach {X Y} [::tclapp::xilinx::designutils::prettyTable::deviceview::region2XY $tbl $userClockRoot] { break }
      $tbl prependcell $X $Y "(U) "
    }
  }

  if {$clockRoot != {}} {
    set clockRoot [format "\nCLOCK_ROOT: %s" $clockRoot]
  }

  if {$userClockRoot != {}} {
    set userClockRoot [format "\nUSER_CLOCK_ROOT: %s" $userClockRoot]
  }

  if {[llength $unplaced] == 0} {
    set title "Driver: $driver\nCell: [get_property -quiet REF_NAME $cell]\nFanout: [expr [get_property -quiet FLAT_PIN_COUNT $net] -1]\nClock: [get_clocks -quiet -of $driver]${clockRoot}${userClockRoot}"
    # Append optional ancestor information
    append title $ancestorstr
    $tbl title $title
  } else {
    set title "Driver: $driver\nCell: [get_property -quiet REF_NAME $cell]\nFanout: [expr [get_property -quiet FLAT_PIN_COUNT $net] -1]\nUnplaced loads: [llength $unplaced]\nClock: [get_clocks -quiet -of $driver]${clockRoot}${userClockRoot}"
    # Append optional ancestor information
    append title $ancestorstr
    $tbl title $title
  }
#   $tbl title "Driver: $driver\nCell: [get_property -quiet REF_NAME $cell]\nFanout: [expr [get_property -quiet FLAT_PIN_COUNT $net] -1]\nClock: [get_clocks -quiet -of $driver]${clockRoot}${userClockRoot}"

  if {$channel != {stdout}} {
    puts $channel [$tbl export -format $params(format)]
    close $channel
    puts " -I- Generated file '[file normalize $options(-file)]'"
  }
  set result [$tbl export -format $params(format)]
  catch {$tbl destroy}
  return $result
}

proc ::tclapp::xilinx::designutils::report_nets::progressBar {cur tot} {
  # Summary : Report all the available nets in tot

  # Argument Usage:

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened
  
  # Categories: xilinxtclstore, designutils
	
  # http://wiki.tcl.tk/16939
  # if you don't want to redraw all the time, uncomment and change ferquency
  #if {$cur % ($tot/300)} { return }
  # set to total width of progress bar
  set total 76

  # Do not show the progress bar in GUI and Batch modes
  if {$rdi::mode != {tcl}} { return }

  set half [expr {$total/2}]
  set percent [expr {100.*$cur/$tot}]
  set val (\ [format "%6.2f%%" $percent]\ )
  set str "\r|[string repeat = [expr {round($percent*$total/100)}]][string repeat { } [expr {$total-round($percent*$total/100)}]]|"
  set str "[string range $str 0 $half]$val[string range $str [expr {$half+[string length $val]-1}] end]"
  puts -nonewline stderr $str
}

proc ::tclapp::xilinx::designutils::report_nets::generate_file_header {cmd} {
  # Summary : Report all the available nets in cmd

  # Argument Usage:

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened
  
  # Categories: xilinxtclstore, designutils
	
  set header [list "# ---------------------------------------------------------------------------------" ]
  lappend header [format {# Created on %s with report_nets (%s)} [clock format [clock seconds]] $::tclapp::xilinx::designutils::report_nets::version ]
  lappend header "# ---------------------------------------------------------------------------------\n"
  return [join $header \n]
}

##-----------------------------------------------------------------------
## duration
##-----------------------------------------------------------------------
## Convert a number of seconds in a human readable string.
## Example:
##      set startTime [clock seconds]
##      ...
##      set endTime [clock seconds]
##      puts "The runtime is: [duration [expr $endTime - $startTime]]"
##-----------------------------------------------------------------------

proc ::tclapp::xilinx::designutils::report_nets::duration { int_time } {
  # Summary : Report all the available nets in int_time

  # Argument Usage:

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened
  
  # Categories: xilinxtclstore, designutils
	
   set timeList [list]
   if {$int_time == 0} { return "0 sec" }
   foreach div {86400 3600 60 1} mod {0 24 60 60} name {day hr min sec} {
     set n [expr {$int_time / $div}]
     if {$mod > 0} {set n [expr {$n % $mod}]}
     if {$n > 1} {
       lappend timeList "$n ${name}s"
     } elseif {$n == 1} {
       lappend timeList "$n $name"
     }
   }
   return [join $timeList]
}

# Example:
#   getFrequencyDistribution [list clk_out2_pll_clrx_2 clk_out2_pll_lnrx_3 clk_out2_pll_lnrx_3 ]
# => {clk_out2_pll_lnrx_3 2} {clk_out2_pll_clrx_2 1}
proc ::tclapp::xilinx::designutils::report_nets::getFrequencyDistribution {L} {
  # Summary : Report all the available Frequencies 

  # Argument Usage:

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened
  
  # Categories: xilinxtclstore, designutils
	
  catch {unset arr}
  set res [list]
  foreach el $L {
    if {![info exists arr($el)]} { set arr($el) 0 }
    incr arr($el)
  }
  foreach {el num} [array get arr] {
    lappend res [list $el $num]
  }
  set res [lsort -decreasing -real -index 1 [lsort -increasing -dictionary -index 0 $res]]
  return $res
}

# Get the list of PARENT modules for a list of cell(s)
proc ::tclapp::xilinx::designutils::report_nets::getParentCells {cells} {
  # Summary : Report all the available nets in cells

  # Argument Usage:

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened
  
  # Categories: xilinxtclstore, designutils
	
  set cells [get_cells -quiet $cells]
  if {$cells == {}} {
    return {}
  }
  set parents [list]
  while {1} {
    set L [get_property -quiet PARENT $cells]
    if {$L == {}} {
      break
    }
    set parents [concat $parents $L]
    set cells $L
  }
  set parents [lsort -unique [get_cells -quiet $parents] ]
  return $parents
}


#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::report_nets::dputs
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::report_nets::dputs {args} {
  # Summary : Report all the available nets in args

  # Argument Usage:
  #args : command line option (-help option for more details)

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened
  
  # Categories: xilinxtclstore, designutils
	
  variable params
  if {$params(debug)} {
    if {$params(debug_level) >= 1} {
      catch { eval [concat puts $args] }
    }
  }
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::report_nets::debug
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::report_nets::debug {body} {
  # Summary : Report all the available nets in body

  # Argument Usage:

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened
  
  # Categories: xilinxtclstore, designutils
	
  variable params
  if {$params(debug)} {
    uplevel 1 [list eval $body]
  }
  return -code ok
}

namespace eval ::tclapp::xilinx::designutils {
  namespace import -force ::tclapp::xilinx::designutils::report_nets
}

# namespace import -force ::tclapp::xilinx::designutils::report_nets

