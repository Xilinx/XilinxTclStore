package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export report_failfast
}

########################################################################################
## 2018.05.04 - Changes -no_methodology_check => -no_methodology_checks to match
##              the command line option name inside Tcl Store
## 2018.05.01 - Fixed issue when the Vivado version includes letters
## 2018.04.10 - Added support to 'report_utilization -evaluate_pblocks' to reduce
##              the utilization metrics runtime (2018.2 and above)
##            - Added support for -no_header
## 2018.03.28 - Detailed reports are saved inside the output report directory
## 2018.03.24 - Added LUT/Net interactive reports (RPX) to detailed reports
## 2018.02.22 - Fixed issue with path budgeting when there is only 1 timing path
##              being analyzed
## 2018.02.15 - Added support for -max_paths
##            - Improved debug options
## 2018.02.14 - Fixed incorrect LUT/Net budgeting calculation
##            - Added summary table at the beginning of the LUT/Net detailed reports
## 2018.02.12 - Added support for -exclude_cell
##            - Added support for -no_hfn / -no_control_sets
##            - Fixed some cells being double-counted
## 2017.12.05 - Fixed debug message
## 2017.11.03 - Fixed sticky -show_resources
##            - Minor update
## 2017.11.01 - Added support for -csv
##            - Changed format for output report (table reported before optional CSV)
##            - Detailed reports are only generated when not empty
## 2017.10.23 - Added metric for counting the DONT_TOUCH properties (cells/nets)
##            - Added detailed report for DONT_TOUCH property
##            - Added support for -append for detailed reports
##            - Added support for -no_dont_touch
##            - Do no report 'LUT Combining' metric when LUT utilization < 50%
##            - Fixed issue when the script is used outside of the Tcl Store
## 2017.10.11 - Moved code to Xilinx Tcl Store
##            - Moved to prettyTable
##            - Fixed issue with the number of failures not returned with -by_slr
## 2017.10.09 - Added support for -post_ooc_synth
## 2017.10.06 - Minor code improvement
## 2017.09.21 - Added support for analysis based on clock regions (-regions)
##            - Added support for -show_resources
##            - Added detailed report for Non-FD HFN (-detailed_reports)
##            - Added detailed report for Average Fanout (-detailed_reports)
##            - Fixed incorrect resource calculation when PR is auto-detected
## 2017.09.15 - Added support for Partial Reconfigurable designs (-cell/-pblock)
##            - Added support for SLR-level analysis (-slr/-by_slr)
##            - Recommended control sets based on number of available FD resources
##            - Added metrics related to URAM
##            - BUFGCE that are inserted by PSIP are not counted
##            - Added support for -no_methodology_check/-no_path_budgeting/-no_fanout
##            - Changed some of the terminology used inside the final table
##            - Changed reports parsing for better resilience to format changes
##            - Added long help
## 2017.06.07 - Improved LUT/Net budgeting calculation
## 2017.05.04 - Added detailed description for TIMING checks
##            - Added new metric related to latches
## 2017.02.03 - Added support for -detailed_reports
## 2016.12.09 - Added support for -transpose. The default CSV format has changed.
##              Use -transpose to revert to previous format
## 2016.12.05 - Added metric for net budgeting
##            - Modified metric names for LUT budgeting
## 2016.11.18 - Metrics that are not specified in the config file are not calculated
##              and reported
## 2016.11.16 - Added support for -config_file/-export_config
##            - Added support for configurable metrics thresholds for pass/fail
##              through configuration file
## 2016.11.01 - Added few more utilization metrics inside CSV
## 2016.10.31 - Fix minor formating issue with some percent metrics
##            - Added missing metrics inside CSV
##            - Added new columns to CSV with design and run directory
## 2016.10.28 - Added better support for post-place utilization report
##            - Added support for extracting small percent such as "<0.1"
## 2016.10.24 - Renamed proc and namespace to report_failfast
## 2016.10.11 - Improved runtime for average fanout calculation
## 2016.10.10 - Initial release
########################################################################################

# Example of report:

#      +-----------------------------------------------------------------------------------------+
#      | Design Summary                                                                          |
#      | checkpoint_top_sp_opt                                                                   |
#      | xcvu9p-flgb2104-2-i                                                                     |
#      | Cell: CL                                                                                |
#      | Pblock: pblock_CL                                                                       |
#      +-----------------------------------------------------------+-----------+--------+--------+
#      | Criteria                                                  | Guideline | Actual | Status |
#      +-----------------------------------------------------------+-----------+--------+--------+
#      | LUT                                                       | 70%       | 64.58% | OK     |
#      | FD                                                        | 50%       | 43.06% | OK     |
#      | LUTRAM+SRL                                                | 25%       | 30.47% | REVIEW |
#      | CARRY8                                                    | 25%       | 3.63%  | OK     |
#      | MUXF7                                                     | 15%       | 1.63%  | OK     |
#      | LUT Combining                                             | 20%       | 36.71% | REVIEW |
#      | DSP48                                                     | 80%       | 40.02% | OK     |
#      | RAMB/FIFO                                                 | 80%       | 62.50% | OK     |
#      | URAM                                                      | 80%       | 50.00% | OK     |
#      | DSP48+RAMB+URAM (Avg)                                     | 70%       | 41.09% | OK     |
#      | BUFGCE* + BUFGCTRL                                        | 24        | 0      | OK     |
#      | Control Sets                                              | 17145     | 18498  | REVIEW |
#      | Average Fanout for modules > 100k cells                   | 4         | 3.06   | OK     |
#      | Non-FD high fanout nets > 10k loads                       | 0         | 0      | OK     |
#      +-----------------------------------------------------------+-----------+--------+--------+
#      | TIMING-6 (No common primary clock between related clocks) | 0         | 1      | REVIEW |
#      | TIMING-7 (No common node between related clocks)          | 0         | 1      | REVIEW |
#      | TIMING-8 (No common period between related clocks)        | 0         | 0      | OK     |
#      | TIMING-14 (LUT on the clock tree)                         | 0         | 0      | OK     |
#      | TIMING-35 (No common node in paths with the same clock)   | 0         | 0      | OK     |
#      +-----------------------------------------------------------+-----------+--------+--------+
#      | Number of paths above max LUT budgeting (0.300ns)         | 0         | 15     | REVIEW |
#      | Number of paths above max Net budgeting (0.208ns)         | 0         | 28     | REVIEW |
#      +-----------------------------------------------------------+-----------+--------+--------+
#
#  With -show_resources:
#      +------------------------------------------------------------------------------------------------------------+
#      | Design Summary                                                                                             |
#      | checkpoint_stage_9_route_design                                                                            |
#      | xcku085-flvb1760-2-e                                                                                       |
#      | Regions: X0Y0 X1Y0 X0Y1 X1Y1 X0Y2 X1Y2                                                                     |
#      +-----------------------------------------------------------+-----------+---------+--------+--------+--------+
#      | Criteria                                                  | Guideline | Actual  | Used   | Avail  | Status |
#      +-----------------------------------------------------------+-----------+---------+--------+--------+--------+
#      | LUT                                                       | 70%       | 171.44% | 115205 | 67200  | REVIEW |
#      | FD                                                        | 50%       | 52.13%  | 70059  | 134400 | REVIEW |
#      | LUTRAM+SRL                                                | 25%       | 0.32%   | 108    | 34080  | OK     |
#      | CARRY8                                                    | 25%       | 63.56%  | 5339   | 8400   | REVIEW |
#      | MUXF7                                                     | 15%       | 2.74%   | 920    | 33600  | OK     |
#      | LUT Combining                                             | 20%       | 19.45%  | 26049  | -      | OK     |
#      | DSP48                                                     | 80%       | 39.04%  | 253    | 648    | OK     |
#      | RAMB/FIFO                                                 | 80%       | 13.19%  | 28.5   | 216    | OK     |
#      | DSP48+RAMB+URAM (Avg)                                     | 70%       | 26.11%  | 281.5  | 864    | OK     |
#      | BUFGCE* + BUFGCTRL                                        | 24        | 5       | 5      | -      | OK     |
#      | Control Sets                                              | 1260      | 3593    | 3593   | -      | REVIEW |
#      | Average Fanout for modules > 100k cells                   | 4         | 3.00    | 3.00   | -      | OK     |
#      | Non-FD high fanout nets > 10k loads                       | 0         | 0       | 0      | -      | OK     |
#      +-----------------------------------------------------------+-----------+---------+--------+--------+--------+
#      | TIMING-6 (No common primary clock between related clocks) | 0         | 0       | 0      | -      | OK     |
#      | TIMING-7 (No common node between related clocks)          | 0         | 8       | 8      | -      | REVIEW |
#      | TIMING-8 (No common period between related clocks)        | 0         | 0       | 0      | -      | OK     |
#      | TIMING-14 (LUT on the clock tree)                         | 0         | 122     | 122    | -      | REVIEW |
#      | TIMING-35 (No common node in paths with the same clock)   | 0         | 0       | 0      | -      | OK     |
#      +-----------------------------------------------------------+-----------+---------+--------+--------+--------+
#      | Number of paths above max LUT budgeting (0.425ns)         | 0         | 34      | 34     | -      | REVIEW |
#      | Number of paths above max Net budgeting (0.298ns)         | 0         | 35      | 35     | -      | REVIEW |
#      +-----------------------------------------------------------+-----------+---------+--------+--------+--------+

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils {
  namespace export report_failfast
} ]

proc ::tclapp::xilinx::designutils::report_failfast {args} {
  # Summary : Generate a fail/pass report

  # Argument Usage:
  # [-file <arg>]: Output report file name
  # [-append]: Append to existing file
  # [-detailed_reports <arg>]: Prefix for output detailed reports
  # [-config_file <arg>]: Confile file name to import
  # [-export_config <arg>]: Confile file name to export
  # [-cell <arg>]: Hierarchical cell name
  # [-exclude_cell <arg>]: Hierarchical cell name to exclude
  # [-top]: Use top-level design
  # [-pblock <arg>]: Pblock name
  # [-regions <arg>]: Clock regions patterns
  # [-slr <arg>]: SLR name
  # [-by_slr]: Run the report on each SLR
  # [-no_methodology_checks]: Skip methodology checks
  # [-no_path_budgeting]: Skip LUT/Net budgeting
  # [-no_fanout]: Skip average fanout calculation
  # [-no_dont_touch]: Skip DONT_TOUCH check
  # [-no_hfn]: Skip Non-FD high fanout nets metric
  # [-no_control_sets]: Skip control sets metric
  # [-max_paths <arg>]: max number of paths per clock group for LUT/Net budgeting. Default is 100
  # [-post_ooc_synth]: Post OOC Synthesis - only run LUT/Net budgeting
  # [-ignore_pr]: Disable auto-detection of Partial Reconfigurable designs
  # [-show_resources]: Show Used/Available resources count in the summary table
  # [-show_not_found]: Show metrics that could not be extracted
  # [-csv]: Add CSV to the output report
  # [-transpose]: Transpose the CSV file
  # [-no_header]: Suppress the files header
  # [-longhelp]: Display Long help with the supported use models

  # Return Value:
  # Number of rules to review

  # Categories: xilinxtclstore, designutils

  return [::tclapp::xilinx::designutils::report_failfast::report_failfast {*}$args]
#   uplevel [concat ::tclapp::xilinx::designutils::report_failfast::report_failfast $args]
#   return 0
}

eval [list namespace eval ::tclapp::xilinx::designutils::report_failfast {
  namespace export report_failfast
} ]

##-----------------------------------------------------------------------
## Long help function
##-----------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::report_failfast::print_help {} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils


## Options:
##
##   -input             Input report file(s)
##
set help_message [format {
########################################################################################
##
## ::xilinx::designutils::report_failfast
##
## Example:
##    ::xilinx::designutils::report_failfast
##
## Description:
##   Generate a fail/pass report
##
########################################################################################
## Pblock-based analysis:
##   1. Use -pblock to select the pblock-based analysis
##      By default, the script calculates the utilization metrics based on all the
##      primitives assigned to the pblock and its nested pblocks over the resources
##      available inside the pblock
##   2. If -top is specified, then the metrics are calculated based on all the
##      primitives in the design over the resources available inside the pblock (What-If analysis)
##   3. If -cell is specified, then the metrics are calculated based on all the
##      primitives below the specified cell over the resources available inside the pblock (What-If analysis)
##   4. If -pblock is specified without -top/-cell, the following metrics are not run:
##      a. Methodology checks
##      b. LUT/Net budgeting
##      c. Average fanout
##
## SLR-based analysis:
##   1. Use -slr or by_slr to select the SLR-based analysis
##      By default, the script calculates the utilization metrics based on all the
##      primitives placed inside the SLR over the resources available inside the SLR
##      The default mode is only valid on a post-placed design
##   2. If -top is specified, then the metrics are calculated based on all the
##      primitives in the design over the resources available inside the SLR (What-If analysis)
##   3. If -cell is specified, then the metrics are calculated based on all the
##      primitives below the specified cell over the resources available inside the SLR (What-If analysis)
##   4. Use -by_slr to force the analysis on all the SLRs of the device
##   5. If -slr is specified without -top/-cell, the following metrics are not run:
##      a. Methodology checks
##      b. LUT/Net budgeting
##      c. Average fanout
##
## Clock Region(s)-based analysis:
##   1. Use -regions to select the clock region(s) based analysis
##      By default, the script calculates the utilization metrics based on all the
##      primitives placed inside the clock region(s) over the resources
##      available inside the clock region(s)
##      The default mode is only valid on a post-placed design
##   2. If -top is specified, then the metrics are calculated based on all the
##      primitives in the design over the resources available inside the clock region(s) (What-If analysis)
##   3. If -cell is specified, then the metrics are calculated based on all the
##      primitives below the specified cell over the resources available inside the clock region(s) (What-If analysis)
##   4. -region support comma separated list of clock region patterns
##      For example: X0Y0:X1Y2,X2Y4 => X0Y0 X1Y0 X0Y1 X1Y1 X0Y2 X1Y2 X2Y4
##   5. If -pblock is specified without -top/-cell, the following metrics are not run:
##      a. Methodology checks
##      b. LUT/Net budgeting
##      c. Average fanout
##
## Support for Partial Reconfigurable designs:
##   1. Uses the "Pblock-based analysis" mode
##   2. Use -cell/-block options to specify the hierarchical module and pblock
##      The hierarchical module (-cell) is used to extract the number of used resources
##      The pblock (-pblock) is used to extract the number of available resources
##      Only 1 cell and 1 pblock can be specified at a time
##   3. PR design can be automatically detected only if a module CL exists and a pblock pblock_CL exists.
##      If both conditions are met, then -cell/-pblock don’t need to be specified as they are both set to -cell CL -pblock pblock_CL
##      For any other combination of cell/pblock, it is needed to manually specify -cell/-pblock
##   4. To prevent auto-detection of the PR design based on CL/pblock_CL, use -ignore_pr
##
## Notes:
##   1. TIMING-* checks are never scoped and always run on the whole design
##      a. Skipped during Pblock/Clock Regions/SLR-based analysis when neither -top/-cell are specified
##   2. If you want to test if KernelA fits in SLR1, you will need to:
##      a. Create a pblock to cover SLR1 (i.e pblock_SLR1)
##      b. run report_failfast -cell KernelA -pblock pblock_SLR1
##   3. If you want to test if KernelA + KernelB fits in middle pblock (i.e pblock_CL_mid), you will need to:
##      a. run report_failfast -cell KernelA -pblock pblock_CL_mid
##      b. run report_failfast -cell KernelB -pblock pblock_CL_mid
##      c. Do the math to add utilization numbers from a) and b). There is no automation.
##
## Summary Table:
## ==============
##   +---------+--------------------+-----------------------------------------------------------------------------------------------------------------------------------------++------------------------------------------------------------------+----------------------------------------++------+-------+---------+---------+------++------------------------------------------------------+-----------------------------------------------------------------+
##   | Mode    | Category           | Scenario                                                                                                                                || Logical Resources (Used Resources)                               | HW Resources (Available Resources)     || -top | -cell | -pblock | -region | -slr || Command line                                         | Note                                                            |
##   +---------+--------------------+-----------------------------------------------------------------------------------------------------------------------------------------++------------------------------------------------------------------+----------------------------------------++------+-------+---------+---------+------++------------------------------------------------------+-----------------------------------------------------------------+
##   | Mode 0  | Default            | Utilization metrics for the design and the device                                                                                       || Full Design                                                      | Full Device                            ||      |       |         |         |      || report_failfast                                      |                                                                 |
##   +---------+--------------------+-----------------------------------------------------------------------------------------------------------------------------------------++------------------------------------------------------------------+----------------------------------------++------+-------+---------+---------+------++------------------------------------------------------+-----------------------------------------------------------------+
##   | Mode 1a | Pblock Based       | Utilization metrics for all the cells assigned to the pblock w.r.t the pblock resources                                                 || Primitives assigned to the pblock and nested pblocks             | Resources covered by the pblock        ||      |       |    x    |         |      || report_failfast -pblock <PBLOCK>                     | No Methodology check / No LUT/Net Budgeting / No Average Fanout |
##   | Mode 1b | Pblock Based       | Utilization metrics if the entire design was  assigned to the pblock                                                                    || Full Design                                                      | Resources covered by the pblock        ||  x   |       |    x    |         |      || report_failfast -pblock <PBLOCK> -top                |                                                                 |
##   | Mode 1c | Pblock Based       | Utilization metrics if the hierarchical cell was assigned to the pblock                                                                 || Primitives under the hierarchical cell                           | Resources covered by the pblock        ||      |   x   |    x    |         |      || report_failfast -pblock <PBLOCK> -cell <CELL>        | Partial Reconfigurable Design                                   |
##   +---------+--------------------+-----------------------------------------------------------------------------------------------------------------------------------------++------------------------------------------------------------------+----------------------------------------++------+-------+---------+---------+------++------------------------------------------------------+-----------------------------------------------------------------+
##   | Mode 2a | Clock Region Based | Utilization metrics for all the cells placed inside the clock region(s) w.r.t the clock region(s) resources. Only valid after placement || Primitives placed inside the clock regions (post-placement only) | Resources covered by the clock regions ||      |       |         |    x    |      || report_failfast -region <CLOCK_REGIONS>              | No Methodology check / No LUT/Net Budgeting / No Average Fanout |
##   | Mode 2b | Clock Region Based | Utilization metrics if the entire design is  placed inside the clock region(s)                                                          || Full Design                                                      | Resources covered by the clock regions ||  x   |       |         |    x    |      || report_failfast -region <CLOCK_REGIONS> -top         |                                                                 |
##   | Mode 2c | Clock Region Based | Utilization metrics if the hierarchical cell is placed inside the clock region(s)                                                       || Primitives under the hierarchical cell                           | Resources covered by the clock regions ||      |   x   |         |    x    |      || report_failfast -region <CLOCK_REGIONS> -cell <CELL> |                                                                 |
##   +---------+--------------------+-----------------------------------------------------------------------------------------------------------------------------------------++------------------------------------------------------------------+----------------------------------------++------+-------+---------+---------+------++------------------------------------------------------+-----------------------------------------------------------------+
##   | Mode 3a | SLR Based          | Utilization metrics for all the cells placed inside the SLR w.r.t the SLR resources. Only valid after placement                         || Primitives placed inside the SLR (post-placement only)           | Resources covered by the SLR           ||      |       |         |         |  x   || report_failfast -slr <SLR>                           | No Methodology check / No LUT/Net Budgeting / No Average Fanout |
##   | Mode 3b | SLR Based          | Utilization metrics if the entire design is  placed inside the SLR                                                                      || Full Design                                                      | Resources covered by the SLR           ||  x   |       |         |         |  x   || report_failfast -slr <SLR> -top                      |                                                                 |
##   | Mode 3c | SLR Based          | Utilization metrics if the hierarchical cell is placed inside the SLR                                                                   || Primitives under the hierarchical cell                           | Resources covered by the SLR           ||      |   x   |         |         |  x   || report_failfast -slr <SLR> -cell <CELL>              |                                                                 |
##   +---------+--------------------+-----------------------------------------------------------------------------------------------------------------------------------------++------------------------------------------------------------------+----------------------------------------++------+-------+---------+---------+------++------------------------------------------------------+-----------------------------------------------------------------+
########################################################################################
} ]

  foreach line [split $help_message "\n"] {
    regsub {##} $line {  } line
    puts $line
  }

}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils::report_failfast {
  namespace export report_failfast
  variable version {2018.05.04}
  variable script [info script]
  variable SUITE_INTEGRATION 0
  variable params
  variable output {}
  variable metrics
  variable guidelines
  variable data
  array set params [list failed 0 format {table} max_paths 100 show_resources 0 transpose 0 verbose 0 debug 0 debug_level 1 vivado_version [version -short] ]
  array set reports [list]
  catch {unset metrics}
  array set metrics [list]
  catch {unset data}
  catch {unset guidelines}
} ]

proc ::tclapp::xilinx::designutils::report_failfast::lshift {inputlist} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  upvar $inputlist argv
  set arg  [lindex $argv 0]
  set argv [lrange $argv 1 end]
  return $arg
}

proc ::tclapp::xilinx::designutils::report_failfast::report_failfast {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  variable SUITE_INTEGRATION
  variable version
  variable metrics
  variable params
  variable guidelines
  variable output
  variable data
  catch {unset guidelines}
  catch {unset metrics}
  array set metrics [list]
  set params(failed) 0
  set params(verbose) 0
  set params(debug) 0
  set params(debug_level) 1
  set params(format) {table}
  set params(transpose) 0
  set params(show_resources) 0
  set params(max_paths) 100
#   set params(vivado_version) [version -short]
  set params(vivado_version) [regsub -all {[a-zA-Z]} [version -short] {0}] ; # Remove any letter that would fail 'package vcompare'
  set pid {tmp}
  catch { set pid [pid] }
  set filename {}
  set filemode {w}
  set detailedReportsPrefix {}
#   set detailedReportsDir {.}
  set detailedReportsDir [file normalize .] ; # Current directory
  set userConfigFilename {}
  set time [clock seconds]
  set date [clock format $time]
  # -top/-cell/-pblock/-region/-slr
  set optionTop 0
  set optionCell 0
  set optionPblock 0
  set optionRegion 0
  set optionSlr 0
  # For Partial Reconfigurable designs: both the cell and pblock must be specified
  set prDetect 1
  set prCell {}
  set prPblock {}
  set excludeCell {}
  set leafCells [list]
  set slrs {}
  set slrPblock {}
  set reportBySLR 0
  # List of clock regions (-region)
  set regions {}
  # Pblock created for the clock regions (-region)
  set regionPblock {}
  set skipChecks [list]
  set hideUnextractedMetrics 1
  # Report mode
  set reportMode {default}
  # Timing paths to be considered for LUT/Net budgeting
  set timingPathsBudgeting [list]
  # Override LUT budgeting
  set lutBudgeting 0
  # Override Net budgeting
  set netBudgeting 0
  set deletePblocks 1
  set markLeafCells 0
  set highlistLeafCells 0
  set showFileHeader 1
  set cmdLine $args
  set error 0
  set help 0
  set show_long_help 0
#   if {[llength $args] == 0} {
#     set help 1
#   }
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-f(i(le?)?)?$} {
        set filename [lshift args]
        # The detailed reports should be saved inside the same directory as the output report
        set detailedReportsDir [file dirname [file normalize $filename]]
      }
      {^-ap(p(e(nd?)?)?)?$} {
        set filemode {a}
      }
      {^-de(t(a(i(l(e(d(_(r(e(p(o(r(ts?)?)?)?)?)?)?)?)?)?)?)?)?)?$} {
        set detailedReportsPrefix [lshift args]
      }
      {^-co(n(f(i(g(_(f(i(le?)?)?)?)?)?)?)?)?$} {
        set userConfigFilename [lshift args]
      }
      {^-ex(p(o(r(t(_(c(o(n(f(ig?)?)?)?)?)?)?)?)?)?)?$} {
        set file [lshift args]
        if {$file == {}} {
          puts " -E- no output file provided"
          return -code ok
        }
        set FH [open $file {w}]
        set content [info body ::tclapp::xilinx::designutils::report_failfast::config]
        puts $FH "# Configuration file for report_failfast"
        puts $FH "# Use report_failfast -config_file <filename> to read the configuration file back in\n"
        foreach line [lrange [split $content \n] 2 end-2] {
          puts $FH [string trimleft $line]
        }
        close $FH
        puts " -I- Exported configuration to [file normalize $file]"
        return -code ok
      }
      {^-ig(n(o(r(e(_(pr?)?)?)?)?)?)?$} {
        # Do not try to auto detect PR designs
        set prDetect 0
      }
      {^-no_m(e(t(h(o(d(o(l(o(g(y(_(c(h(e(c(ks?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?$} {
        lappend skipChecks {methodology_check}
      }
      {^-no_pa(t(h(_(b(u(d(g(e(t(i(ng?)?)?)?)?)?)?)?)?)?)?)?$} {
        lappend skipChecks {path_budgeting}
      }
      {^-no_fa(n(o(ut?)?)?)?$} {
        lappend skipChecks {average_fanout}
      }
      {^-no_do(n(t(_(t(o(u(ch?)?)?)?)?)?)?)?$} {
        lappend skipChecks {dont_touch}
      }
      {^-no_h(fn?)?$} -
      {^-no_fd(_(h(fn?)?)?)?$} {
        lappend skipChecks {non_fd_hfn}
      }
      {^-no_co(n(t(r(o(l(_(s(e(ts?)?)?)?)?)?)?)?)?)?$} {
        lappend skipChecks {control_sets}
      }
      {^-no_u(t(i(l(i(z(a(t(i(on?)?)?)?)?)?)?)?)?)?$} {
        # Hidden command line option
        lappend skipChecks {utilization}
      }
      {^-po(s(t(_(o(o(c(_(s(y(n(th?)?)?)?)?)?)?)?)?)?)?)?$} -
      {^-pa(t(h(_(b(u(d(g(e(t(i(n(g(_(o(n(ly?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?$} {
        set skipChecks [concat $skipChecks {utilization dont_touch control_sets non_fd_hfn average_fanout methodology_check}]
      }
      {^-ce(ll?)?$} {
        set prCell [lshift args]
        set optionCell 1
      }
      {^-ex(c(l(u(d(e(_(c(e(ll?)?)?)?)?)?)?)?)?)?$} {
        set excludeCell [lshift args]
      }
      {^-top?$} {
        set optionTop 1
      }
      {^-by_slr$} {
        set reportBySLR 1
      }
      {^-slrs?$} {
        set slrs [lshift args]
        set optionSlr 1
      }
      {^-pb(l(o(ck?)?)?)?$} {
        set prPblock [lshift args]
        set optionPblock 1
      }
      {^-r(e(g(i(o(ns?)?)?)?)?)?$} {
        set patterns [lshift args]
        set L [list]
        foreach pattern [split $patterns ,] {
          set L [concat $L [get_clock_regions -quiet [expandPattern $pattern]] ]
        }
        if {[llength $L] == 0} {
          puts " -E- pattern '$patterns' does not match any clock region"
          incr error
        } else {
          set regions [get_clock_regions -quiet $L]
#           set regions [lsort -dictionary [get_clock_regions -quiet $L]]
        }
        set optionRegion 1
      }
      {^-show_n(o(t(_(f(o(u(nd?)?)?)?)?)?)?)?$} {
        set hideUnextractedMetrics 0
      }
      {^-show_r(e(s(o(u(r(c(es?)?)?)?)?)?)?)?$} {
        set params(show_resources) 1
      }
      {^-ma(x(_(p(a(t(hs?)?)?)?)?)?)?$} {
        set params(max_paths) [lshift args]
      }
      {^-c(sv?)?$} -
      {^-csv$} {
        set params(format) {csv}
      }
      {^-tr(a(n(s(p(o(se?)?)?)?)?)?)?$} {
        set params(transpose) 1
      }
      {^-no_h(e(a(d(er?)?)?)?)?$} {
        set showFileHeader 0
      }
      {^-v(e(r(b(o(se?)?)?)?)?)?$} {
        set params(verbose) 1
      }
      {^-d(e(b(ug?)?)?)?$} {
        set params(debug) 1
      }
      {^--debug-level$} -
      {^-debug_level$} {
        set params(debug_level) [lshift args]
      }
      {^--debug-keep-pblocks?$} -
      {^--keep-pblocks?$} {
        set deletePblocks 0
      }
      {^--debug-mark-leafs?$} -
      {^--mark-leafs?$} {
        set markLeafCells 1
      }
      {^--debug-highlight-leafs?$} -
      {^--highlight-leafs?$} {
        set highlistLeafCells 1
      }
      {^--debug-paths?$} -
      {^--paths?$} {
        set timingPathsBudgeting [lshift args]
      }
      {^--debug-lut-budgeting?$} -
      {^--debug-lut(-(b(u(d(g(e(t(i(ng?)?)?)?)?)?)?)?)?)?$} -
      {^--lut(-(b(u(d(g(e(t(i(ng?)?)?)?)?)?)?)?)?)?$} {
        set lutBudgeting [lshift args]
      }
      {^--debug-net-budgeting?$} -
      {^--debug-net(-(b(u(d(g(e(t(i(ng?)?)?)?)?)?)?)?)?)?$} -
      {^--net(-(b(u(d(g(e(t(i(ng?)?)?)?)?)?)?)?)?)?$} {
        set netBudgeting [lshift args]
      }
      {^--debug-vivado-version?$} -
      {^--debug-v(i(v(a(d(o(-(v(e(r(s(i(on?)?)?)?)?)?)?)?)?)?)?)?)?$} -
      {^--v(i(v(a(d(o(-(v(e(r(s(i(on?)?)?)?)?)?)?)?)?)?)?)?)?$} {
        set params(vivado_version) [lshift args]
      }
      {^-h(e(lp?)?)?$} {
        set help 1
      }
      {^-lo(n(g(h(e(lp?)?)?)?)?)?$} {
#         set help 1
        set show_long_help 1
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
  Usage: ::xilinx::designutils::report_failfast
              [-file <filename>]
              [-append]
              [-detailed_reports <prefix>]
              [-config_file <filename>]
              [-export_config <filename>]
              [-cell <cell>][-top]
              [-pblock <pblock>]
              [-slr <slr>][-by_slr]
              [-regions <pattern>]
              [-no_methodology_checks]
              [-no_path_budgeting]
              [-no_hfn]
              [-no_fanout]
              [-no_dont_touch]
              [-no_control_sets]
              [-post_ooc_synth]
              [-ignore_pr]
              [-exclude_cell <cell>]
              [-max_paths <num>]
              [-show_resources]
              [-show_not_found]
              [-csv][-transpose]
              [-no_header]
              [-verbose|-v]
              [-help|-h]
              [-longhelp]

  Description: Generate a fail/pass report

    Version: %s

    Use -export_config to export configuration file
    Use -config_file to import user configuration file
    Use -csv to generate a CSV format
    Use -transpose to transpose the CSV table and export it as 1-liner
    Use -detailed_reports to generate detailed reports for methdology checks, paths failing LUT/Net budgeting, the Non-FD HFN and Average Fanout
    Use -cell/-pblock to force the analysis on a specific module and pblock in a Partial Reconfigurable design. By default, the analysis is done from the top-level. The full hierarchical path must be specified for -cell
    Use -top to specify the top-level design
    Use -pblock for Pblock-based analysis (more info with -longhelp)
    Use -region for Clock Region-based analysis (more info with -longhelp)
    Use -slr for SLR-based analysis (more info with -longhelp)
    Use -by_slr to automatically run the analysis for each SLR
    Use -no_methodology_checks to prevent extraction of the TIMING-* metrics
    Use -no_fanout to prevent calculation of the average fanout
    Use -no_path_budgeting to prevent calculation of the LUT/Net budgeting
    Use -no_hfn to prevent calculation of Non-FD high fanout nets
    Use -no_dont_touch to prevent calculation of DONT_TOUCH metric
    Use -no_control_sets to prevent extraction of control sets metric
    Use -ignore_pr to prevent auto detection of Partial Reconfigurable designs and always runs the analysis from top-level
    Use -show_resources to report the detailed number of used and available resources in the summary table
    Use -show_not_found to report metrics that have not been extracted (hidden by default)
    Use -post_ooc_synth to only run the LUT/Net path budgeting
    Use -exclude_cell to exclude a hierarchical module from consideration. Only utilization metrics are reported
    Use -max_paths to define the max number of paths per clock group for LUT/Net budgeting. Default is 100
    Use -no_header to suppress the files header

    Use -longhelp for further information about use models

  Example:
     ::xilinx::designutils::report_failfast
     ::xilinx::designutils::report_failfast -file failfast.rpt
     ::xilinx::designutils::report_failfast -file failfast.rpt -csv -transpose
     ::xilinx::designutils::report_failfast -export_config report_failfast.cfg
     ::xilinx::designutils::report_failfast -config_file report_failfast.cfg -file failfast.rpt
     ::xilinx::designutils::report_failfast -detailed_reports synth -file failfast.rpt
     ::xilinx::designutils::report_failfast -detailed_reports synth -file failfast.rpt -cell CL -pblock pblock_CL
     ::xilinx::designutils::report_failfast -file failfast.rpt -slr SLR0
     ::xilinx::designutils::report_failfast -file failfast.rpt -by_slr
     ::xilinx::designutils::report_failfast -file failfast.rpt -regions X0Y0:X0Y4,X0Y4:X5Y4,X5Y0 -top
} $version ]
    # HELP -->

#     if {$show_long_help} { print_help }

    return -code ok
  }

  if {$show_long_help} {
    print_help
    return -code ok
  }

  if {($filename == {}) && ($params(transpose) || ($params(format) == {csv}))} {
    puts " -E- -csv/-transpose must be used with -file"
    incr error
  }

  if {$params(transpose) && ($params(format) != {csv})} {
    puts " -E- -transpose must be used with -csv"
    incr error
  }

  if {($userConfigFilename != {}) && ![file exists $userConfigFilename]} {
    puts " -E- config file '$userConfigFilename' does not exist"
    incr error
  }

  switch -regexp -- "${optionTop}${optionCell}${optionPblock}${optionRegion}${optionSlr}${reportBySLR}" {
    {^11....$} {
      puts " -E- -top/-cells are mutually exclusive"
      incr error
    }
    {^010000$} {
      puts " -E- -cell must be used with -pblock/-slr/-by_slr/-region"
      incr error
    }
    {^100000$} {
      puts " -E- -top must be used with -pblock/-slr/-by_slr/-region"
      incr error
    }
    {^..11..$} -
    {^..1.1.$} -
    {^..1..1$} -
    {^...11.$} -
    {^...1.1$} -
    {^....11$} {
      puts " -E- -pblock/-slr/-by_slr/-region are mutually exclusive"
      incr error
    }
    default {
    }
  }

  if {$prPblock != {}} {
    set pblock [get_pblocks -quiet $prPblock]
    if {$pblock == {}} {
      puts " -E- pblock '$prPblock' does not exists (-pblock)"
      incr error
    } else {
      set prPblock $pblock
    }
  }

  if {$slrs != {}} {
    set slr [get_slrs -quiet $slrs]
    if {$slr == {}} {
      puts " -E- SLR '$slrs' does not exists (-slr)"
      incr error
    } elseif {[llength $slrs] > 1} {
      puts " -E- cannot specify multiple SLRs at the same time (-slr)"
      incr error
    } else {
      set slrs $slr
    }
  }

  if {$prCell != {}} {
    set cell [get_cells -quiet $prCell]
    if {$cell == {}} {
      puts " -E- cell '$prCell' does not exists (-cell)"
      incr error
    } else {
      set prCell $cell
    }
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  if {$reportBySLR} {
    # Remove -by_slr from original command line
    set cmd [lsearch -all -inline -not -exact $cmdLine {-by_slr}]
    set res 0
    set failures 0
    foreach slr [get_slrs -quiet] {
      # Calling the command with the original (but modified) command line
      # Adding -append to make sure that all SLR data are being saved into the file
      if {[catch {
        set res [tclapp::xilinx::designutils::report_failfast -append -slr $slr {*}$cmd]
        if {[regexp {^[0-9]+$} $res]} {
          set failures [expr $failures + $res]
        }
      } errorstring]} {
        puts " -E- $errorstring"
      }
    }
    # All the SLR(s) have been processed. Exit
    return $failures
  }

  if {$regions != {}} {
    # Create pblock to cover all the clock regions
    set L {}
    foreach region $regions {
      lappend L "CLOCKREGION_${region}"
    }
    # For safety, delete ghosts pblocks before
    delete_pblocks -quiet failfast_regions
    create_pblock -quiet failfast_regions
    resize_pblock -quiet failfast_regions -add $L
    if {$params(debug)} { puts " -D- clock regions ([llength $regions]): $regions" }
    if {$params(debug)} { puts " -D- creating pblock: failfast_regions := $L" }
    set regionPblock [get_pblocks -quiet failfast_regions]
  }

  switch -regexp -- "${optionTop}${optionCell}${optionPblock}${optionRegion}${optionSlr}" {
    {^1.1..$} {
      set reportMode {pblockAndTop}
      set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != MACRO)"]
    }
    {^.11..$} {
      set reportMode {pblockAndCell}
      set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != MACRO) && NAME =~ $prCell/*"]
    }
    {^..1..$} {
      set reportMode {pblockOnly}
      dputs " -D- parent pblock: $pblock"
      # Get pblock + all nested pblocks
      set allPblocks [getChildPblocks $prPblock]
      dputs " -D- parent+nested pblocks: $allPblocks"
      set leafCells [list]
      foreach pblock $allPblocks {
        set cells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != MACRO) && PBLOCK == $pblock"]
        dputs " -D- pblock $pblock: [llength $cells] cells"
        set leafCells [concat $leafCells $cells]
      }
      set leafCells [get_cells -quiet $leafCells]
      # The following checks are not supported in this mode
      set skipChecks [concat $skipChecks {average_fanout path_budgeting methodology_check}]
    }
    {^1..1.$} {
      set reportMode {regionAndTop}
      set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != MACRO)"]
    }
    {^.1.1.$} {
      set reportMode {regionAndCell}
      set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != MACRO) && NAME =~ $prCell/*"]
    }
    {^...1.$} {
      set reportMode {regionOnly}
      set leafCells [get_cells -quiet -of [get_clock_regions -quiet $regions]]
      # The following checks are not supported in this mode
      set skipChecks [concat $skipChecks {average_fanout path_budgeting methodology_check}]
      # Sanity check for a tuned message
      if {[llength $leafCells] == 0} {
        puts " -E- no leaf primitive found under regions '$regions'. Make sure the design is placed. Cannot continue"
        return -code ok
      }
    }
    {^1...1$} {
      set reportMode {slrAndTop}
      set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != MACRO)"]
    }
    {^.1..1$} {
      set reportMode {slrAndCell}
      set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != MACRO) && NAME =~ $prCell/*"]
    }
    {^....1$} {
      set reportMode {slrOnly}
      set leafCells [get_cells -quiet -of [get_slrs -quiet $slrs]]
      # The following checks are not supported in this mode
      set skipChecks [concat $skipChecks {average_fanout path_budgeting methodology_check}]
      # dont_touch is not supported in this mode as it would flag DONT_TOUCH on shell/static
      # logic contained in some of the SLRs
      set skipChecks [concat $skipChecks {dont_touch}]
      # Sanity check for a tuned message
      if {[llength $leafCells] == 0} {
        puts " -E- no leaf primitive found under SLR $slrs. Make sure the design is placed. Cannot continue"
        return -code ok
      }
    }
    default {
      # Check for Partial Reconfigurable design
      if {$prDetect} {
        # -cell/-pblock have not been specified
        if {([get_cells -quiet {CL}] == {CL}) && ([get_pblocks -quiet {pblock_CL}] == {pblock_CL})} {
          # Partial Reconfigurable design detected
          set prCell [get_cells -quiet {CL}]
          set prPblock [get_pblocks -quiet {pblock_CL}]
          # Change reporting mode
          set reportMode {pblockAndCell}
          set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != MACRO) && NAME =~ $prCell/*"]
          puts " -I- Partial Reconfigurable design detected (cell:$prCell / pblock:$prPblock)"
        } else {
          set reportMode {default}
          set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != MACRO)"]
        }
      } else {
        set reportMode {default}
        set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != MACRO)"]
      }
    }
  }
  if {[llength $leafCells] == 0} {
    puts " -E- no leaf primitive found under the request. Cannot continue"
    return -code ok
  }
  # Remove excluded leaf cells
  if {$excludeCell != {}} {
    # The following checks are not supported with -exclude_cell
    set skipChecks [concat $skipChecks {average_fanout path_budgeting methodology_check dont_touch control_sets non_fd_hfn}]
#     set skipChecks [concat $skipChecks {average_fanout path_budgeting methodology_check dont_touch control_sets}]
    puts " -W- Disabled checks (-exclude_cell): control sets / non-FD HFN / average fanout / path budgeting / methodology checks / DONT_TOUCH attributes"
    dputs " -D- number of extracted leaf cells: [llength $leafCells]"
    dputs " -D- excluded cell: $excludeCell"
    set leafCells [filter -quiet $leafCells "NAME !~ $excludeCell/*"]
    if {[llength $leafCells] == 0} {
      puts " -E- no leaf primitive found after excluding cell '$excludeCell'. Cannot continue"
      return -code ok
    }
    dputs " -D- number of extracted leaf cells: [llength $leafCells]"
  } else {
    dputs " -D- number of extracted leaf cells: [llength $leafCells]"
  }
  dputs " -D- report mode: $reportMode"
  if {$highlistLeafCells} {
    highlight_objects -quiet -color orange $leafCells
  }
  if {$markLeafCells} {
    mark_objects -quiet -color orange $leafCells
  }

  # Reset internal data structures
  reset

  if {$userConfigFilename != {}} {
    # Read the user config file
    puts " -I- reading user config file [file normalize $userConfigFilename]"
    source $userConfigFilename
  } else {
    # Set the default config guidelines
    config
  }

  if {$slrs != {}} {
    # Create SLR-level pblocks
    foreach SLR $slrs {
      regexp {X(\d*)Y(\d*)} [lindex [lsort -dictionary [get_clock_regions -of $SLR ]] 0] - Xmin Ymin
      regexp {X(\d*)Y(\d*)} [lindex [lsort -dictionary [get_clock_regions -of $SLR ]] end] - Xmax Ymax
      # For safety, delete ghosts pblocks before
      delete_pblocks -quiet failfast_${SLR}
      create_pblock -quiet failfast_${SLR}
      resize_pblock -quiet failfast_${SLR} -add "CLOCKREGION_X${Xmin}Y${Ymin}:CLOCKREGION_X${Xmax}Y${Ymax}"
      if {$params(debug)} { puts " -D- creating pblock: failfast_${SLR} := CLOCKREGION_X${Xmin}Y${Ymin}:CLOCKREGION_X${Xmax}Y${Ymax}" }
    }
    set slrPblock [get_pblocks -quiet failfast_*]
  }

  if {[lsearch $skipChecks {utilization}] != -1} {
    catch { array unset guidelines design.cells.hlutnm.* }
    catch { array unset guidelines utilization.clb.* }
    catch { array unset guidelines utilization.ram.* }
    catch { array unset guidelines utilization.uram.* }
    catch { array unset guidelines utilization.bigblocks.* }
    catch { array unset guidelines utilization.dsp.* }
    catch { array unset guidelines utilization.clk.* }
  }

  if {[lsearch $skipChecks {dont_touch}] != -1} {
    catch { array unset guidelines design.dont_touch }
  }

  if {[lsearch $skipChecks {control_sets}] != -1} {
    catch { array unset guidelines utilization.ctrlsets.* }
  }

  if {[lsearch $skipChecks {non_fd_hfn}] != -1} {
    catch { array unset guidelines design.nets.nonfdhfn* }
  }

  if {[lsearch $skipChecks {methodology_check}] != -1} {
    catch { array unset guidelines methodology.* }
  }

  if {[lsearch $skipChecks {average_fanout}] != -1} {
    catch { array unset guidelines design.cells.maxavgfo* }
  }

  if {[lsearch $skipChecks {path_budgeting}] != -1} {
    catch { array unset guidelines design.device.maxlvls* }
  }

  # Check if designutils app is already installed as it is needed for prettyTable
  if {[lsearch -exact [::tclapp::list_apps] {xilinx::designutils}] == -1} {
    set script $::tclapp::xilinx::designutils::report_failfast::script
    # Save the verbosity flag as it gets lost when designutils is installed
    set verbose $params(verbose)
    if {$params(verbose)} {
      puts " -I- installing Tcl Store app: designutils"
    }
    uplevel #0 [list ::tclapp::install {designutils} ]
    # The current script needs to be re-sourced since installing the app designutils has
    # overridden report_failfast from the Github version
    if {$verbose} {
      puts " -I- sourcing $script"
    }
    uplevel #0 [list source $script ]
    # The script need to be re-started once designutils has been installed
    set res [tclapp::xilinx::designutils::report_failfast {*}$cmdLine]
    # Return the number of metrics to review
    return $res
  }

  set startTime [clock seconds]
  set output [list]
  set timBudgetPerLUT {}
  set timBudgetPerNet {}

  if {[catch {

    ########################################################################################
    ##
    ## General design metrics
    ##
    ########################################################################################

    if {1} {
      set stepStartTime [clock seconds]
      addMetric {design.part}                   {Part}
      addMetric {design.part.architecture}      {Architecture}
      addMetric {design.part.architecture.name} {Architecture Name}
      addMetric {design.part.speed.class}       {Speed class}
      addMetric {design.part.speed.label}       {Speed label}
      addMetric {design.part.speed.id}          {Speed ID}
      addMetric {design.part.speed.date}        {Speed date}
#       addMetric {design.nets}                   {Number of nets}
      addMetric {design.cells.hlutnm}           {Number of HLUTNM cells}
      addMetric {design.cells.hlutnm.pct}       {Number of HLUTNM cells (%)}
      addMetric {design.ports}                  {Number of ports}
      addMetric {design.slrs}                   {Number of SLRs}
      addMetric {design.dont_touch}             {Number of DONT_TOUCH (cells/nets)}

      set part [get_property -quiet PART [current_design]]
      setMetric {design.part}                   $part
      setMetric {design.part.architecture}      [get_property -quiet ARCHITECTURE $part]
      setMetric {design.part.architecture.name} [get_property -quiet ARCHITECTURE_FULL_NAME $part]
      setMetric {design.part.speed.class}       [get_property -quiet SPEED $part]
      setMetric {design.part.speed.label}       [get_property -quiet SPEED_LABEL $part]
      setMetric {design.part.speed.id}          [get_property -quiet SPEED_LEVEL_ID $part]
      setMetric {design.part.speed.date}        [get_property -quiet SPEED_LEVEL_ID_DATE $part]
      setMetric {design.ports}                  [llength [get_ports -quiet]]
      setMetric {design.slrs}                   [llength [get_slrs -quiet]]
#       setMetric {design.nets}                   [llength [get_nets -quiet -hier -top_net_of_hierarchical_group -filter {TYPE == SIGNAL}]]

      set luts [filter -quiet $leafCells {REF_NAME =~ LUT*}]
      set hlutnm [filter -quiet $luts {SOFT_HLUTNM != "" || HLUTNM != ""}]
      setMetric {design.cells.hlutnm} [llength $hlutnm]
      # Calculate the percent of HLUTNM over the total number of LUT
      if {[llength $luts] != 0} {
        setMetric {design.cells.hlutnm.pct} [format {%.2f} [expr {100.0 * double([llength $hlutnm]) / double([llength $luts])}] ]
      } else {
        setMetric {design.cells.hlutnm.pct} {n/a}
      }

      set stepStopTime [clock seconds]
      puts " -I- design metrics completed in [expr $stepStopTime - $stepStartTime] seconds"
    }

    ########################################################################################
    ##
    ## DONT_TOUCH metric
    ##
    ########################################################################################

    if {1 && [llength [array names guidelines design.dont_touch]] && ([lsearch $skipChecks {dont_touch}] == -1)} {
      set stepStartTime [clock seconds]
      set numDontTouch 0
      set dontTouchNets [list]
      set dontTouchHierCells [list]
      set dontTouchLeafCells [list]
      switch $reportMode {
        pblockAndTop {
          # Number of cells/nets with DONT_TOUCH. Exclude nets with MARK_DEBUG
          set dontTouchNets [get_nets -quiet -hier -filter {DONT_TOUCH && !MARK_DEBUG}]
          set dontTouchHierCells [get_cells -quiet -hier -filter {!IS_PRIMITIVE && DONT_TOUCH}]
          set dontTouchLeafCells [get_cells -quiet -hier -filter {IS_PRIMITIVE && DONT_TOUCH}]
        }
        pblockAndCell {
          # Number of cells/nets with DONT_TOUCH. Exclude nets with MARK_DEBUG
          set dontTouchNets [filter -quiet [get_nets -quiet -of $leafCells] {DONT_TOUCH && !MARK_DEBUG}]
#           if {$excludeCell != {}} {
#             set dontTouchHierCells [get_cells -quiet -hier -filter {!IS_PRIMITIVE && DONT_TOUCH && NAME =~ $prCell/* && NAME !~ $excludeCell/*}]
#             set dontTouchLeafCells [get_cells -quiet -hier -filter {IS_PRIMITIVE && DONT_TOUCH && NAME =~ $prCell/* && NAME !~ $excludeCell/*}]
#           } else {
#             set dontTouchHierCells [get_cells -quiet -hier -filter {!IS_PRIMITIVE && DONT_TOUCH && NAME =~ $prCell/*}]
#             set dontTouchLeafCells [get_cells -quiet -hier -filter {IS_PRIMITIVE && DONT_TOUCH && NAME =~ $prCell/*}]
#           }
          set dontTouchHierCells [get_cells -quiet -hier -filter {!IS_PRIMITIVE && DONT_TOUCH && NAME =~ $prCell/*}]
          set dontTouchLeafCells [get_cells -quiet -hier -filter {IS_PRIMITIVE && DONT_TOUCH && NAME =~ $prCell/*}]
        }
        pblockOnly {
          # Number of cells/nets with DONT_TOUCH. Exclude nets with MARK_DEBUG
          set parents [getParentCells $leafCells]
          set dontTouchNets [filter -quiet [get_nets -quiet -of $leafCells] {DONT_TOUCH && !MARK_DEBUG}]
          set dontTouchHierCells [filter -quiet $parents {DONT_TOUCH}]
          set dontTouchLeafCells [filter -quiet $leafCells {DONT_TOUCH}]
        }
        regionAndTop {
          # Number of cells/nets with DONT_TOUCH. Exclude nets with MARK_DEBUG
          set dontTouchNets [get_nets -quiet -hier -filter {DONT_TOUCH && !MARK_DEBUG}]
          set dontTouchHierCells [get_cells -quiet -hier -filter {!IS_PRIMITIVE && DONT_TOUCH}]
          set dontTouchLeafCells [get_cells -quiet -hier -filter {IS_PRIMITIVE && DONT_TOUCH}]
        }
        regionAndCell {
           # Number of cells/nets with DONT_TOUCH. Exclude nets with MARK_DEBUG
          set dontTouchNets [filter -quiet [get_nets -quiet -of $leafCells] {DONT_TOUCH && !MARK_DEBUG}]
          set dontTouchHierCells [get_cells -quiet -hier -filter {!IS_PRIMITIVE && DONT_TOUCH && NAME =~ $prCell/*}]
          set dontTouchLeafCells [get_cells -quiet -hier -filter {IS_PRIMITIVE && DONT_TOUCH && NAME =~ $prCell/*}]
       }
        regionOnly {
          # Number of cells/nets with DONT_TOUCH. Exclude nets with MARK_DEBUG
          set parents [getParentCells $leafCells]
          set dontTouchNets [filter -quiet [get_nets -quiet -of $leafCells] {DONT_TOUCH && !MARK_DEBUG}]
          set dontTouchHierCells [filter -quiet $parents {DONT_TOUCH}]
          set dontTouchLeafCells [filter -quiet $leafCells {DONT_TOUCH}]
       }
        slrAndTop {
          # Number of cells/nets with DONT_TOUCH. Exclude nets with MARK_DEBUG
          set dontTouchNets [get_nets -quiet -hier -filter {DONT_TOUCH && !MARK_DEBUG}]
          set dontTouchHierCells [get_cells -quiet -hier -filter {!IS_PRIMITIVE && DONT_TOUCH}]
          set dontTouchLeafCells [get_cells -quiet -hier -filter {IS_PRIMITIVE && DONT_TOUCH}]
        }
        slrAndCell {
          # Number of cells/nets with DONT_TOUCH. Exclude nets with MARK_DEBUG
          set dontTouchNets [filter -quiet [get_nets -quiet -of $leafCells] {DONT_TOUCH && !MARK_DEBUG}]
          set dontTouchHierCells [get_cells -quiet -hier -filter {!IS_PRIMITIVE && DONT_TOUCH && NAME =~ $prCell/*}]
          set dontTouchLeafCells [get_cells -quiet -hier -filter {IS_PRIMITIVE && DONT_TOUCH && NAME =~ $prCell/*}]
        }
        slrOnly {
          # Number of cells/nets with DONT_TOUCH. Exclude nets with MARK_DEBUG
#           set parents [getParentCells $leafCells]
#           set dontTouchNets [filter -quiet [get_nets -quiet -of $leafCells] {DONT_TOUCH && !MARK_DEBUG}]
#           set dontTouchHierCells [filter -quiet $parents {DONT_TOUCH}]
#           set dontTouchLeafCells [filter -quiet $leafCells {DONT_TOUCH}]
          # dont_touch is not supported in this mode as it would flag DONT_TOUCH on shell/static
          # logic contained in some of the SLRs
          array unset guidelines design.dont_touch
        }
        default {
          # Number of cells/nets with DONT_TOUCH. Exclude nets with MARK_DEBUG
          set dontTouchNets [get_nets -quiet -hier -filter {DONT_TOUCH && !MARK_DEBUG}]
          set dontTouchHierCells [get_cells -quiet -hier -filter {!IS_PRIMITIVE && DONT_TOUCH}]
          set dontTouchLeafCells [get_cells -quiet -hier -filter {IS_PRIMITIVE && DONT_TOUCH}]
        }
      }
      set numDontTouch [expr [llength $dontTouchNets] + [llength $dontTouchHierCells] + [llength $dontTouchLeafCells] ]
      setMetric {design.dont_touch} $numDontTouch

      if {$detailedReportsPrefix != {}} {
        set empty 1
        catch { file copy ${detailedReportsDir}/${detailedReportsPrefix}.DONT_TOUCH.rpt ${detailedReportsDir}/${detailedReportsPrefix}.DONT_TOUCH.rpt.${pid} }
        set FH [open "${detailedReportsDir}/${detailedReportsPrefix}.DONT_TOUCH.rpt.${pid}" $filemode]
        if {$showFileHeader} {
          puts $FH "# ---------------------------------------------------------------------------"
          puts $FH [format {# Created on %s with report_failfast (%s)} [clock format [clock seconds]] $::tclapp::xilinx::designutils::report_failfast::version ]
          puts $FH "# ---------------------------------------------------------------------------\n"
        }
        # Hierarchical cells
        set tbl [::tclapp::xilinx::designutils::prettyTable create [format "DONT_TOUCH (Hierarchical Cells)\n[llength $dontTouchHierCells] module(s)"] ]
        $tbl indent 1
        $tbl header [list {Cell} ]
        foreach el [lsort $dontTouchHierCells] {
          $tbl addrow [list $el]
          set empty 0
        }
        puts $FH [$tbl print]
        catch {$tbl destroy}
        # Leaf cells
        set tbl [::tclapp::xilinx::designutils::prettyTable create [format "DONT_TOUCH (Leaf Cells)\n[llength $dontTouchLeafCells] cell(s)"] ]
        $tbl indent 1
        $tbl header [list {Cell} ]
        foreach el [lsort $dontTouchLeafCells] {
          $tbl addrow [list $el]
          set empty 0
        }
        puts $FH [$tbl print]
        catch {$tbl destroy}
        # Nets
        set tbl [::tclapp::xilinx::designutils::prettyTable create [format "DONT_TOUCH (Nets)\n[llength $dontTouchNets] net(s)"] ]
        $tbl indent 1
        $tbl header [list {Net} ]
        foreach el [lsort $dontTouchNets] {
          $tbl addrow [list $el]
          set empty 0
        }
        puts $FH [$tbl print]
        catch {$tbl destroy}
        close $FH
        if {$empty} {
          file delete -force ${detailedReportsDir}/${detailedReportsPrefix}.DONT_TOUCH.rpt.${pid}
        } else {
          file rename -force ${detailedReportsDir}/${detailedReportsPrefix}.DONT_TOUCH.rpt.${pid} ${detailedReportsDir}/${detailedReportsPrefix}.DONT_TOUCH.rpt
          puts " -I- Generated file [file normalize ${detailedReportsDir}/${detailedReportsPrefix}.DONT_TOUCH.rpt]"
        }
      }
      set stepStopTime [clock seconds]
      puts " -I- DONT_TOUCH metric completed in [expr $stepStopTime - $stepStartTime] seconds"
    }

    ########################################################################################
    ##
    ## Utilization metrics
    ##
    ########################################################################################

    if {[package vcompare $params(vivado_version) 2018.2.0] >= 0} {
      # With Vivado 2018.2 and above, use -evaluate_pblock to extract the
      # physical resources. This prevents running report_utilization twice
      switch $reportMode {
        pblockAndTop -
        pblockAndCell -
        pblockOnly {
          set rptUtilOpts [list -pblock $prPblock -evaluate_pblock]
          if {$params(debug)} {
            puts " -D- utilization report run with '-pblock $prPblock -evaluate_pblock'"
          }
        }
        regionAndTop -
        regionAndCell -
        regionOnly {
          set rptUtilOpts [list -pblock $regionPblock -evaluate_pblock]
          if {$params(debug)} {
            puts " -D- utilization report run with '-pblock $regionPblock -evaluate_pblock'"
          }
        }
        slrAndTop -
        slrAndCell -
        slrOnly {
          set rptUtilOpts [list -pblock $slrPblock -evaluate_pblock]
          if {$params(debug)} {
            puts " -D- utilization report run with '-pblock $slrPblock -evaluate_pblock'"
          }
        }
        default {
        }
      }
    } else {
      # For Vivado 2018.1 and before
      set rptUtilOpts [list]
    }

    if {1 && [llength [array names guidelines utilization.*]] && ([lsearch $skipChecks {utilization}] == -1)} {
      set stepStartTime [clock seconds]
      switch $reportMode {
        pblockAndTop {
#           set report [report_utilization -quiet -return_string]
          set report [report_utilization {*}$rptUtilOpts -quiet -cells $leafCells -return_string]
        }
        pblockAndCell {
#           set report [report_utilization -quiet -cells $prCell -return_string]
          set report [report_utilization {*}$rptUtilOpts -quiet -cells $leafCells -return_string]
        }
        pblockOnly {
          set report [report_utilization {*}$rptUtilOpts -quiet -cells $leafCells -return_string]
        }
        regionAndTop {
#           set report [report_utilization -quiet -return_string]
          set report [report_utilization {*}$rptUtilOpts -quiet -cells $leafCells -return_string]
        }
        regionAndCell {
#           set report [report_utilization -quiet -cells $prCell -return_string]
          set report [report_utilization {*}$rptUtilOpts -quiet -cells $leafCells -return_string]
        }
        regionOnly {
          set report [report_utilization {*}$rptUtilOpts -quiet -cells $leafCells -return_string]
        }
        slrAndTop {
#           set report [report_utilization -quiet -return_string]
          set report [report_utilization {*}$rptUtilOpts -quiet -cells $leafCells -return_string]
        }
        slrAndCell {
#           set report [report_utilization -quiet -cells $prCell -return_string]
          set report [report_utilization {*}$rptUtilOpts -quiet -cells $leafCells -return_string]
        }
        slrOnly {
          set report [report_utilization {*}$rptUtilOpts -quiet -cells $leafCells -return_string]
        }
        default {
#           set report [report_utilization -quiet -return_string]
          set report [report_utilization -quiet -cells $leafCells -return_string]
        }
      }

      # +----------------------------+--------+-------+-----------+-------+
      # |          Site Type         |  Used  | Fixed | Available | Util% |
      # +----------------------------+--------+-------+-----------+-------+
      # | Slice LUTs                 | 396856 |     0 |   1221600 | 32.49 |
      # |   LUT as Logic             | 394919 |     0 |   1221600 | 32.33 |
      # |   LUT as Memory            |   1937 |     0 |    344800 |  0.56 |
      # |     LUT as Distributed RAM |     64 |     0 |           |       |
      # |     LUT as Shift Register  |   1873 |     0 |           |       |
      # | Slice Registers            | 224301 |     2 |   2443200 |  9.18 |
      # |   Register as Flip Flop    | 200897 |     0 |   2443200 |  8.22 |
      # |   Register as Latch        |  23404 |     2 |   2443200 |  0.96 |
      # | F7 Muxes                   |   6787 |     0 |    610800 |  1.11 |
      # | F8 Muxes                   |   2619 |     0 |    305400 |  0.86 |
      # +----------------------------+--------+-------+-----------+-------+
      # +----------------------------+------+-------+-----------+-------+
      # |          Site Type         | Used | Fixed | Available | Util% |
      # +----------------------------+------+-------+-----------+-------+
      # | CLB LUTs                   | 2088 |     0 |    230400 |  0.91 |
      # |   LUT as Logic             | 1916 |     0 |    230400 |  0.83 |
      # |   LUT as Memory            |  172 |     0 |    101760 |  0.17 |
      # |     LUT as Distributed RAM |   56 |     0 |           |       |
      # |     LUT as Shift Register  |  116 |     0 |           |       |
      # | CLB Registers              | 2612 |     0 |    460800 |  0.57 |
      # |   Register as Flip Flop    | 2612 |     0 |    460800 |  0.57 |
      # |   Register as Latch        |    0 |     0 |    460800 |  0.00 |
      # | CARRY8                     |    8 |     0 |     28800 |  0.03 |
      # | F7 Muxes                   |    7 |     0 |    115200 | <0.01 |
      # | F8 Muxes                   |    0 |     0 |     57600 |  0.00 |
      # | F9 Muxes                   |    0 |     0 |     28800 |  0.00 |
      # +----------------------------+------+-------+-----------+-------+
      # +----------------------------+----------+----------+--------+-------+-----------+-------+
      # |          Site Type         | Assigned | External |  Used  | Fixed | Available | Util% |
      # +----------------------------+----------+----------+--------+-------+-----------+-------+
      # | CLB LUTs                   |    17872 |   559219 | 576869 |     0 |    914400 | 63.09 |
      # |   LUT as Logic             |    14540 |   431349 | 445667 |     0 |    914400 | 48.74 |
      # |   LUT as Memory            |     3332 |   127870 | 131202 |     0 |    460320 | 28.50 |
      # |     LUT as Distributed RAM |     3198 |   112428 | 115626 |     0 |           |       |
      # |     LUT as Shift Register  |      134 |    15442 |  15576 |     0 |           |       |
      # | CLB Registers              |    44456 |   743096 | 787552 |     0 |   1828800 | 43.06 |
      # |   Register as Flip Flop    |    44456 |   743093 | 787549 |     0 |   1828800 | 43.06 |
      # |   Register as Latch        |        0 |        0 |      0 |     0 |   1828800 |  0.00 |
      # |   Register as AND/OR       |        0 |        3 |      3 |     0 |   1828800 | <0.01 |
      # | CARRY8                     |       64 |     4088 |   4152 |     0 |    114300 |  3.63 |
      # | F7 Muxes                   |        0 |     7453 |   7453 |     0 |    457200 |  1.63 |
      # | F8 Muxes                   |        0 |      822 |    822 |     0 |    228600 |  0.36 |
      # | F9 Muxes                   |        0 |        0 |      0 |     0 |    114300 |  0.00 |
      # +----------------------------+----------+----------+--------+-------+-----------+-------+

      # +-------------------------------------------------------------+----------+-------+-----------+-------+
      # |                          Site Type                          |   Used   | Fixed | Available | Util% |
      # +-------------------------------------------------------------+----------+-------+-----------+-------+
      # | CLB                                                         |       33 |     0 |     34260 |  0.10 |
      # |   CLBL                                                      |       21 |     0 |           |       |
      # |   CLBM                                                      |       12 |     0 |           |       |
      # | LUT as Logic                                                |       96 |     0 |    274080 |  0.04 |
      # |   using O5 output only                                      |        0 |       |           |       |
      # |   using O6 output only                                      |       68 |       |           |       |
      # |   using O5 and O6                                           |       28 |       |           |       |
      # | LUT as Memory                                               |        0 |     0 |    144000 |  0.00 |
      # |   LUT as Distributed RAM                                    |        0 |     0 |           |       |
      # |   LUT as Shift Register                                     |        0 |     0 |           |       |
      # | LUT Flip Flop Pairs                                         |      153 |     0 |    274080 |  0.06 |
      # |   fully used LUT-FF pairs                                   |       63 |       |           |       |
      # |   LUT-FF pairs with unused LUT                              |       57 |       |           |       |
      # |   LUT-FF pairs with unused Flip Flop                        |       33 |       |           |       |
      # | Unique Control Sets                                         |       13 |       |           |       |
      # | Maximum number of registers lost to control set restriction | 21(Lost) |       |           |       |
      # +-------------------------------------------------------------+----------+-------+-----------+-------+
      # +-------------------------------------------+----------+----------+--------+-------+-----------+-------+
      # |                 Site Type                 | Assigned | External |  Used  | Fixed | Available | Util% |
      # +-------------------------------------------+----------+----------+--------+-------+-----------+-------+
      # | CLB                                       |     8801 |   101909 | 104626 |     0 |    114300 | 91.54 |
      # |   CLBL                                    |     5408 |    49289 |  51138 |     0 |           |       |
      # |   CLBM                                    |     3393 |    52620 |  53488 |     0 |           |       |
      # | LUT as Logic                              |    14540 |   431349 | 445667 |     0 |    914400 | 48.74 |
      # |   using O5 output only                    |      470 |    10725 |  10973 |       |           |       |
      # |   using O6 output only                    |     9463 |   315289 | 324530 |       |           |       |
      # |   using O5 and O6                         |     4607 |   105335 | 110164 |       |           |       |
      # | LUT as Memory                             |     3332 |   127870 | 131202 |     0 |    460320 | 28.50 |
      # |   LUT as Distributed RAM                  |     3198 |   112428 | 115626 |     0 |           |       |
      # |     using O5 output only                  |        0 |        0 |      0 |       |           |       |
      # |     using O6 output only                  |       22 |    76360 |  76382 |       |           |       |
      # |     using O5 and O6                       |     3176 |    36068 |  39244 |       |           |       |
      # |   LUT as Shift Register                   |      134 |    15442 |  15576 |     0 |           |       |
      # |     using O5 output only                  |        0 |        0 |      0 |       |           |       |
      # |     using O6 output only                  |      134 |     6365 |   6499 |       |           |       |
      # |     using O5 and O6                       |        0 |     9077 |   9077 |       |           |       |
      # | LUT Flip Flop Pairs                       |     9811 |   277265 | 287987 |     0 |    914400 | 31.49 |
      # |   fully used LUT-FF pairs                 |     3283 |    49956 |  53308 |       |           |       |
      # |   LUT-FF pairs with one unused LUT output |     6383 |   221954 | 228949 |       |           |       |
      # |   LUT-FF pairs with one unused Flip Flop  |     2827 |   172829 | 174734 |       |           |       |
      # | Unique Control Sets                       |      651 |    17888 |  18533 |       |           |       |
      # +-------------------------------------------+----------+----------+--------+-------+-----------+-------+

      addMetric {utilization.clb.lut}          {CLB LUTs}
      addMetric {utilization.clb.lut.pct}      {CLB LUTs (%)}
      addMetric {utilization.clb.lut.avail}    {CLB LUTs (Avail)}
      addMetric {utilization.clb.ff}           {CLB Registers}
      addMetric {utilization.clb.ff.pct}       {CLB Registers (%)}
      addMetric {utilization.clb.ff.avail}     {CLB Registers (Avail)}
      addMetric {utilization.clb.ld}           {CLB Latches}
      addMetric {utilization.clb.ld.pct}       {CLB Latches (%)}
      addMetric {utilization.clb.ld.avail}     {CLB Latches (Avail)}
      addMetric {utilization.clb.carry8}       {CARRY8}
      addMetric {utilization.clb.carry8.pct}   {CARRY8 (%)}
      addMetric {utilization.clb.carry8.avail} {CARRY8 (Avail)}
      addMetric {utilization.clb.f7mux}        {F7 Muxes}
      addMetric {utilization.clb.f7mux.pct}    {F7 Muxes (%)}
      addMetric {utilization.clb.f7mux.avail}  {F7 Muxes (Avail)}
      addMetric {utilization.clb.f8mux}        {F8 Muxes}
      addMetric {utilization.clb.f8mux.pct}    {F8 Muxes (%)}
      addMetric {utilization.clb.f8mux.avail}  {F8 Muxes (Avail)}
      addMetric {utilization.clb.f9mux}        {F9 Muxes}
      addMetric {utilization.clb.f9mux.pct}    {F9 Muxes (%)}
      addMetric {utilization.clb.f9mux.avail}  {F9 Muxes (Avail)}
      addMetric {utilization.clb.lutmem}       {LUT as Memory}
      addMetric {utilization.clb.lutmem.pct}   {LUT as Memory (%)}
      addMetric {utilization.clb.lutmem.avail} {LUT as Memory (Avail)}
#       addMetric {utilization.ctrlsets.uniq}  {Unique Control Sets}
#       addMetric {utilization.ctrlsets.lost}  {Registers Lost due to Control Sets}

      extractMetricFromTable report {utilization.clb.lut}          -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{CLB LUTs} {Slice LUTs}} -column {Used} -default {n/a}
      extractMetricFromTable report {utilization.clb.lut.pct}      -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{CLB LUTs} {Slice LUTs}} -column {Util%} -trim float -default {n/a}

      extractMetricFromTable report {utilization.clb.ff}           -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{CLB Registers} {Slice Registers}} -column {Used} -default {n/a}
      extractMetricFromTable report {utilization.clb.ff.pct}       -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{CLB Registers} {Slice Registers}} -column {Util%} -trim float -default {n/a}

      extractMetricFromTable report {utilization.clb.ld}           -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{Register as Latch}} -column {Used} -default {n/a}
      extractMetricFromTable report {utilization.clb.ld.pct}       -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{Register as Latch}} -column {Util%} -trim float -default {n/a}

      extractMetricFromTable report {utilization.clb.carry8}       -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{CARRY8}} -column {Used} -default {n/a}
      extractMetricFromTable report {utilization.clb.carry8.pct}   -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{CARRY8}} -column {Util%} -trim float -default {n/a}

      extractMetricFromTable report {utilization.clb.f7mux}        -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{F7 Muxes}} -column {Used} -default {n/a}
      extractMetricFromTable report {utilization.clb.f7mux.pct}    -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{F7 Muxes}} -column {Util%} -trim float -default {n/a}

      extractMetricFromTable report {utilization.clb.f8mux}        -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{F8 Muxes}} -column {Used} -default {n/a}
      extractMetricFromTable report {utilization.clb.f8mux.pct}    -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{F8 Muxes}} -column {Util%} -trim float -default {n/a}

      extractMetricFromTable report {utilization.clb.f9mux}        -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{F9 Muxes}} -column {Used} -default {n/a}
      extractMetricFromTable report {utilization.clb.f9mux.pct}    -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{F9 Muxes}} -column {Util%} -trim float -default {n/a}

      extractMetricFromTable report {utilization.clb.lutmem}       -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{LUT as Memory}} -column {Used} -default {n/a}
      extractMetricFromTable report {utilization.clb.lutmem.pct}   -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{LUT as Memory}} -column {Util%} -trim float -default {n/a}

      # +-------------------+------+-------+-----------+-------+
      # |     Site Type     | Used | Fixed | Available | Util% |
      # +-------------------+------+-------+-----------+-------+
      # | Block RAM Tile    |    8 |     0 |       912 |  0.88 |
      # |   RAMB36/FIFO*    |    8 |     0 |       912 |  0.88 |
      # |     FIFO36E2 only |    8 |       |           |       |
      # |   RAMB18          |    0 |     0 |      1824 |  0.00 |
      # | URAM              |  400 |     0 |       960 | 41.67 |
      # +-------------------+------+-------+-----------+-------+
      # +-------------------+----------+----------+------+-------+-----------+-------+
      # |     Site Type     | Assigned | External | Used | Fixed | Available | Util% |
      # +-------------------+----------+----------+------+-------+-----------+-------+
      # | Block RAM Tile    |       36 |     1014 | 1050 |     0 |      1680 | 62.50 |
      # |   RAMB36/FIFO*    |       36 |      830 |  866 |     0 |      1680 | 51.55 |
      # |     RAMB36E2 only |       36 |      830 |  866 |       |           |       |
      # |   RAMB18          |        0 |      368 |  368 |     0 |      3360 | 10.95 |
      # |     FIFO18E2 only |        0 |        3 |    3 |       |           |       |
      # |     RAMB18E2 only |        0 |      365 |  365 |       |           |       |
      # | URAM              |        0 |      400 |  400 |     0 |       800 | 50.00 |
      # +-------------------+----------+----------+------+-------+-----------+-------+

      addMetric {utilization.ram.tile}        {Block RAM Tile}
      addMetric {utilization.ram.tile.pct}    {Block RAM Tile (%)}
      addMetric {utilization.ram.tile.avail}  {Block RAM Tile (Avail)}
      addMetric {utilization.uram.tile}       {URAM}
      addMetric {utilization.uram.tile.pct}   {URAM (%)}
      addMetric {utilization.uram.tile.avail} {URAM (Avail)}
      addMetric {utilization.bigblocks}       {Block RAM+URAM+DSP (Avg)}
      addMetric {utilization.bigblocks.pct}   {Block RAM+URAM+DSP (Avg) (%)}
      addMetric {utilization.bigblocks.avail} {Block RAM+URAM+DSP (Avg) (Avail)}

      extractMetricFromTable report {utilization.ram.tile}         -search {{(BLOCKRAM|Memory)\s*$} {(BLOCKRAM|Memory)\s*$}} -row {{Block RAM Tile}} -column {Used} -default {n/a}
      extractMetricFromTable report {utilization.ram.tile.pct}     -search {{(BLOCKRAM|Memory)\s*$} {(BLOCKRAM|Memory)\s*$}} -row {{Block RAM Tile}} -column {Util%} -trim float -default {n/a}

      extractMetricFromTable report {utilization.uram.tile}        -search {{(BLOCKRAM|Memory)\s*$} {(BLOCKRAM|Memory)\s*$}} -row {{URAM}} -column {Used} -default {n/a}
      extractMetricFromTable report {utilization.uram.tile.pct}    -search {{(BLOCKRAM|Memory)\s*$} {(BLOCKRAM|Memory)\s*$}} -row {{URAM}} -column {Util%} -trim float -default {n/a}

      # +-----------+------+-------+-----------+-------+
      # | Site Type | Used | Fixed | Available | Util% |
      # +-----------+------+-------+-----------+-------+
      # | DSPs      |    0 |     0 |      2520 |  0.00 |
      # +-----------+------+-------+-----------+-------+
      # +----------------+----------+----------+------+-------+-----------+-------+
      # |    Site Type   | Assigned | External | Used | Fixed | Available | Util% |
      # +----------------+----------+----------+------+-------+-----------+-------+
      # | DSPs           |        0 |     2257 | 2257 |     0 |      5640 | 40.02 |
      # |   DSP_ALU only |        0 |     2257 | 2257 |       |           |       |
      # +----------------+----------+----------+------+-------+-----------+-------+

      addMetric {utilization.dsp}       {DSPs}
      addMetric {utilization.dsp.pct}   {DSPs (%)}
      addMetric {utilization.dsp.avail} {DSPs (Avail)}

      extractMetricFromTable report {utilization.dsp}              -search {{(ARITHMETIC|DSP)\s*$} {(ARITHMETIC|DSP)\s*$}} -row {{DSPs}} -column {Used} -default {n/a}
      extractMetricFromTable report {utilization.dsp.pct}          -search {{(ARITHMETIC|DSP)\s*$} {(ARITHMETIC|DSP)\s*$}} -row {{DSPs}} -column {Util%} -trim float -default {n/a}

      # +----------------------+------+-------+-----------+-------+
      # |       Site Type      | Used | Fixed | Available | Util% |
      # +----------------------+------+-------+-----------+-------+
      # | GLOBAL CLOCK BUFFERs |    5 |     0 |       544 |  0.92 |
      # |   BUFGCE             |    5 |     0 |       208 |  2.40 |
      # |   BUFGCE_DIV         |    0 |     0 |        32 |  0.00 |
      # |   BUFG_GT            |    0 |     0 |       144 |  0.00 |
      # |   BUFG_PS            |    0 |     0 |        96 |  0.00 |
      # |   BUFGCTRL*          |    0 |     0 |        64 |  0.00 |
      # +----------------------+------+-------+-----------+-------+
      # +----------------------+----------+----------+------+-------+-----------+-------+
      # |       Site Type      | Assigned | External | Used | Fixed | Available | Util% |
      # +----------------------+----------+----------+------+-------+-----------+-------+
      # | GLOBAL CLOCK BUFFERs |        0 |       13 |   13 |     0 |      1200 |  1.08 |
      # |   BUFGCE             |        0 |       13 |   13 |     0 |       480 |  2.71 |
      # |   BUFGCE_DIV         |        0 |        0 |    0 |     0 |        80 |  0.00 |
      # |   BUFG_GT            |        0 |        0 |    0 |     0 |       480 |  0.00 |
      # |   BUFGCTRL*          |        0 |        0 |    0 |     0 |       160 |  0.00 |
      # | PLL                  |        0 |        9 |    9 |     0 |        40 | 22.50 |
      # | MMCM                 |        0 |        3 |    3 |     3 |        20 | 15.00 |
      # +----------------------+----------+----------+------+-------+-----------+-------+

      addMetric {utilization.clk.bufgce}           {BUFGCE Buffers}
      addMetric {utilization.clk.bufgce.pct}       {BUFGCE Buffers (%)}
      addMetric {utilization.clk.bufgcediv}        {BUFGCE_DIV Buffers}
      addMetric {utilization.clk.bufgcediv.pct}    {BUFGCE_DIV Buffers (%)}
      addMetric {utilization.clk.bufggt}           {BUFG_GT Buffers}
      addMetric {utilization.clk.bufggt.pct}       {BUFG_GT Buffers (%)}
      addMetric {utilization.clk.bufgps}           {BUFG_PS Buffers}
      addMetric {utilization.clk.bufgps.pct}       {BUFG_PS Buffers (%)}
      addMetric {utilization.clk.bufgctrl}         {BUFGCTRL Buffers}
      addMetric {utilization.clk.bufgctrl.pct}     {BUFGCTRL Buffers (%)}
      addMetric {utilization.clk.all}              {BUFG* Buffers}

      # Set the default value to 0 as the values are used for calculation later in the code
      extractMetricFromTable report {utilization.clk.bufgce}        -search {{(CLOCK|Clocking)\s*$} {(CLOCK|Clocking)\s*$}} -row {{^BUFGCE$}} -column {Used} -default {0}
      extractMetricFromTable report {utilization.clk.bufgce.pct}    -search {{(CLOCK|Clocking)\s*$} {(CLOCK|Clocking)\s*$}} -row {{^BUFGCE$}} -column {Util%} -trim float -default {0}

      extractMetricFromTable report {utilization.clk.bufgcediv}     -search {{(CLOCK|Clocking)\s*$} {(CLOCK|Clocking)\s*$}} -row {{^BUFGCE_DIV$}} -column {Used} -default {0}
      extractMetricFromTable report {utilization.clk.bufgcediv.pct} -search {{(CLOCK|Clocking)\s*$} {(CLOCK|Clocking)\s*$}} -row {{^BUFGCE_DIV$}} -column {Util%} -trim float -default {0}

      extractMetricFromTable report {utilization.clk.bufggt}        -search {{(CLOCK|Clocking)\s*$} {(CLOCK|Clocking)\s*$}} -row {{^BUFG_GT$}} -column {Used} -default {0}
      extractMetricFromTable report {utilization.clk.bufggt.pct}    -search {{(CLOCK|Clocking)\s*$} {(CLOCK|Clocking)\s*$}} -row {{^BUFG_GT$}} -column {Util%} -trim float -default {0}

      extractMetricFromTable report {utilization.clk.bufgps}        -search {{(CLOCK|Clocking)\s*$} {(CLOCK|Clocking)\s*$}} -row {{^BUFG_PS$}} -column {Used} -default {0}
      extractMetricFromTable report {utilization.clk.bufgps.pct}    -search {{(CLOCK|Clocking)\s*$} {(CLOCK|Clocking)\s*$}} -row {{^BUFG_PS$}} -column {Util%} -trim float -default {0}

      extractMetricFromTable report {utilization.clk.bufgctrl}      -search {{(CLOCK|Clocking)\s*$} {(CLOCK|Clocking)\s*$}} -row {{^BUFGCTRL}} -column {Used} -default {0}
      extractMetricFromTable report {utilization.clk.bufgctrl.pct}  -search {{(CLOCK|Clocking)\s*$} {(CLOCK|Clocking)\s*$}} -row {{^BUFGCTRL}} -column {Util%} -trim float -default {0}

      # Calculate the number of BUFGCE and remove the BUFGCE inserted by PSIP
      setMetric {utilization.clk.bufgce} [llength [filter -quiet $leafCells {(NAME !~ *bufg_place) && (REF_NAME == BUFGCE)}] ]

      if {[catch {
        # Cumulative metric (w/o BUFG_GT/BUFG_PS)
#                                             + [getMetric {utilization.clk.bufggt}]
#                                             + [getMetric {utilization.clk.bufgps}]
        setMetric {utilization.clk.all} [expr [getMetric {utilization.clk.bufgce}] \
                                            + [getMetric {utilization.clk.bufgcediv}] \
                                            + [getMetric {utilization.clk.bufgctrl}] ]
      }]} {
        setMetric {utilization.clk.all} {n/a}
      }

      if {[package vcompare $params(vivado_version) 2018.2.0] < 0} {
        # With Vivado 2018.1 and below, report_utilization needs to be run twice to
        # extract the physical resources. With 2018.2, this is prevented with -evaluate_pblock
        if {$params(debug)} {
          puts " -D- Vivado $params(vivado_version) - report_utilization re-run to extract available resources"
        }
        # With Partial Reconfigurable design, we need to re-run report_utilization to get the actual available resources
        # (same when -slr/-pblock/-region has been specified)
        switch $reportMode {
          pblockAndTop -
          pblockAndCell -
          pblockOnly {
            set report [report_utilization -quiet -pblock $prPblock -return_string]
            if {$params(debug)} {
              puts " -D- generate utilization report for pblock '$prPblock'"
            }
          }
          regionAndTop -
          regionAndCell -
          regionOnly {
            set report [report_utilization -quiet -pblock $regionPblock -return_string]
            if {$params(debug)} {
              puts " -D- generate utilization report for clock regions pblock '$regionPblock'"
            }
          }
          slrAndTop -
          slrAndCell -
          slrOnly {
            set report [report_utilization -quiet -pblock $slrPblock -return_string]
            if {$params(debug)} {
              puts " -D- generate utilization report for SLR '$slrs' / pblock:$slrPblock"
            }
          }
          default {
          }
        }
      } else {
        if {$params(debug)} {
          puts " -D- Vivado $params(vivado_version) - available resources extracted from first report_utilization report"
        }
      }

      extractMetricFromTable report {utilization.clb.lut.avail}    -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{CLB LUTs} {Slice LUTs}} -column {Available} -default {n/a}
      extractMetricFromTable report {utilization.clb.ff.avail}     -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{CLB Registers} {Slice Registers}} -column {Available} -default {n/a}
      extractMetricFromTable report {utilization.clb.ld.avail}     -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{Register as Latch}} -column {Available} -default {n/a}
      extractMetricFromTable report {utilization.clb.carry8.avail} -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{CARRY8}} -column {Available} -default {n/a}
      extractMetricFromTable report {utilization.clb.f7mux.avail}  -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{F7 Muxes}} -column {Available} -default {n/a}
      extractMetricFromTable report {utilization.clb.f8mux.avail}  -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{F8 Muxes}} -column {Available} -default {n/a}
      extractMetricFromTable report {utilization.clb.f9mux.avail}  -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{F9 Muxes}} -column {Available} -default {n/a}
      extractMetricFromTable report {utilization.clb.lutmem.avail} -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{LUT as Memory}} -column {Available} -default {n/a}
      extractMetricFromTable report {utilization.ram.tile.avail}   -search {{(BLOCKRAM|Memory)\s*$} {(BLOCKRAM|Memory)\s*$}} -row {{Block RAM Tile}} -column {Available} -default {n/a}
      extractMetricFromTable report {utilization.uram.tile.avail}  -search {{(BLOCKRAM|Memory)\s*$} {(BLOCKRAM|Memory)\s*$}} -row {{URAM}} -column {Available} -default {n/a}
      extractMetricFromTable report {utilization.dsp.avail}        -search {{(ARITHMETIC|DSP)\s*$}  {(ARITHMETIC|DSP)\s*$}}  -row {{DSPs}} -column {Available} -default {n/a}

      # Calculate the utilization (%) based on the available and used resources
      foreach var [list \
        {utilization.clb.lut}    \
        {utilization.clb.ff}     \
        {utilization.clb.carry8} \
        {utilization.clb.f7mux}  \
        {utilization.clb.f8mux}  \
        {utilization.clb.f9mux}  \
        {utilization.clb.lutmem} \
        {utilization.ram.tile}   \
        {utilization.uram.tile}  \
        {utilization.dsp}        \
        ] {

          if {[package vcompare $params(vivado_version) 2018.2.0] >= 0} {
            # For Vivado 2018.2 and above
            set avail [getMetric ${var}.avail]
            set used [getMetric ${var}]
            # Percent extracted from report
            set percent [getMetric ${var}.pct]
            # Percent calculated
            set calcPercent {n/a}
            if {$params(debug) && ($params(debug_level) >= 2)} {
              puts " -D- $var : Used:$used / Available:$avail"
            }
            if {($avail != {}) && ($avail != 0.0) && ($avail != {n/a})} {
              # The percent are recalculated instead of just extracted from the report so that the same
              # code can be shared between all Vivado versions
#               setMetric ${var}.pct [format {%.2f} [expr 100.0 * double($used) / $avail ]]
              if {[catch {set calcPercent [format {%.2f} [expr 100.0 * double($used) / $avail ] ]} errorstring]} {
                puts " -E- $errorstring"
                setMetric ${var}.pct {n/a}
              } else {
                # Save the percent extracted from the report instead of the calculated one
                setMetric ${var}.pct $percent
                # Void differences if less or equal to 0.01
                if {($calcPercent != $percent) && ([expr abs($percent - $calcPercent)] > 0.005)} {
                  if {$params(debug)} {
                    puts " -W- Percent mismatch for '$var' - report=$percent / calculated=$calcPercent"
                  }
                } else {
                  if {$params(debug) && ($params(debug_level) >= 2)} {
                    puts " -D- Percent match for '$var' - report=$percent / calculated=$calcPercent"
                  }
                }
              }
            } else {
              setMetric ${var}.pct {n/a}
            }

          } else {

            # For Vivado 2018.1 and below
            set avail [getMetric ${var}.avail]
            set used [getMetric ${var}]
            if {$params(debug) && ($params(debug_level) >= 2)} {
              puts " -D- $var : Used:$used / Available:$avail"
            }
            if {($avail != {}) && ($avail != 0.0) && ($avail != {n/a})} {
              if {[catch {setMetric ${var}.pct [format {%.2f} [expr 100.0 * double($used) / $avail ] ]} errorstring]} {
                puts " -E- $errorstring"
                setMetric ${var}.pct {n/a}
              }
            } else {
              setMetric ${var}.pct {n/a}
            }

          }

        }

      # Calculate the average utilization between the big blocks (RAM/URAM/DSP)
      if {[catch {
        # Average metric for DSP/RAM/URAM
        set L_pct [list]
        set L_used [list]
        set L_avail [list]
        if {([getMetric {utilization.dsp.pct}] != 0)
              && ([getMetric {utilization.dsp.pct}] != {n/a})}        { lappend L_pct   [getMetric {utilization.dsp.pct}]
                                                                        lappend L_used  [getMetric {utilization.dsp}]
                                                                        lappend L_avail [getMetric {utilization.dsp.avail}]
                                                                      }
        if {([getMetric {utilization.ram.tile.pct}] != 0)
              && ([getMetric {utilization.ram.tile.pct}] != {n/a})}   { lappend L_pct   [getMetric {utilization.ram.tile.pct}]
                                                                        lappend L_used  [getMetric {utilization.ram.tile}]
                                                                        lappend L_avail [getMetric {utilization.ram.tile.avail}]
                                                                      }
        if {([getMetric {utilization.uram.tile.pct}] != 0)
              && ([getMetric {utilization.uram.tile.pct}] != {n/a})}  { lappend L_pct   [getMetric {utilization.uram.tile.pct}]
                                                                        lappend L_used  [getMetric {utilization.uram.tile}]
                                                                        lappend L_avail [getMetric {utilization.uram.tile.avail}]
                                                                      }
        if {[llength $L_pct]} {
          # Divide by the number of elements in the list
                  setMetric {utilization.bigblocks.pct}   [format {%.2f} [expr double([join $L_pct +]) / [llength $L_pct] ] ]
          catch { setMetric {utilization.bigblocks}       [expr [join $L_used +] ] }
          catch { setMetric {utilization.bigblocks.avail} [expr [join $L_avail +] ] }
        } else {
                  setMetric {utilization.bigblocks.pct}   [format {%.2f} 0 ]
          catch { setMetric {utilization.bigblocks}       [expr [join $L_used +] ] }
          catch { setMetric {utilization.bigblocks.avail} [expr [join $L_avail +] ] }
        }
      }]} {
        setMetric {utilization.bigblocks.pct}   {n/a}
        setMetric {utilization.bigblocks}       {n/a}
        setMetric {utilization.bigblocks.avail} {n/a}
      }

      # If the LUT utilization is below 50%, then do not report the LUT Combining metris
      if {[catch {
        if {[getMetric {utilization.clb.lut.pct}] < 50.0} {
          if {$params(verbose)} { puts " -I- removing LUT Combining metric (design.cells.hlutnm.pct) due to low LUT utilization ([getMetric {utilization.clb.lut.pct}]%)" }
          array unset guidelines design.cells.hlutnm.pct
        }
      }]} {
      }

      set stepStopTime [clock seconds]
      puts " -I- utilization metrics completed in [expr $stepStopTime - $stepStartTime] seconds"
    }

    ########################################################################################
    ##
    ## Control sets metric
    ##
    ########################################################################################

    if {1 && [llength [array names guidelines utilization.*]] && ([lsearch $skipChecks {control_sets}] == -1)} {
      set stepStartTime [clock seconds]
      # Get report
      switch $reportMode {
        pblockAndTop {
          set report [report_control_sets -quiet -return_string]
        }
        pblockAndCell {
          set report [report_control_sets -quiet -cell $leafCells -return_string]
        }
        pblockOnly {
          set report [report_control_sets -quiet -cell $leafCells -return_string]
        }
        regionAndTop {
          set report [report_control_sets -quiet -return_string]
        }
        regionAndCell {
          set report [report_control_sets -quiet -cell $leafCells -return_string]
        }
        regionOnly {
          set report [report_control_sets -quiet -cell $leafCells -return_string]
        }
        slrAndTop {
          set report [report_control_sets -quiet -return_string]
        }
        slrAndCell {
          set report [report_control_sets -quiet -cell $leafCells -return_string]
        }
        slrOnly {
          set report [report_control_sets -quiet -cell $leafCells -return_string]
        }
        default {
          set report [report_control_sets -quiet -return_string]
        }
      }

      addMetric {utilization.ctrlsets.uniq}  {Unique Control Sets}

      extractMetricFromTable report {utilization.ctrlsets.uniq}    -search {{Summary} {Summary}} -row {{Number of unique control sets}} -column {Count} -default {n/a}

      if {![regexp {[0-9]+} $guidelines(utilization.ctrlsets.uniq)]} {
        # If no number is defined inside $guidelines(utilization.ctrlsets.uniq) it means that
        # the number of control sets should be calculated based on the number of available
        # FD resources
        # Formula: 7.5% * (#FD / 8)
        append guidelines(utilization.ctrlsets.uniq) [format {%.0f} [expr [getMetric utilization.clb.ff.avail] / 8.0 * 7.5 / 100.0]]
        if {$params(debug)} { puts " -D- available registers for control sets calculation: [getMetric utilization.clb.ff.avail]" }
        if {$params(verbose)} { puts " -W- setting guideline for control sets to '$guidelines(utilization.ctrlsets.uniq)'" }
      }

      set stepStopTime [clock seconds]
      puts " -I- control set metrics completed in [expr $stepStopTime - $stepStartTime] seconds"
    }

    ########################################################################################
    ##
    ## Methodology checks metrics
    ##
    ########################################################################################

    if {1 && [llength [array names guidelines methodology.*]] && ([lsearch $skipChecks {methodology_check}] == -1)} {
      set stepStartTime [clock seconds]
      addMetric {methodology.timing-6}   {TIMING-6}
      addMetric {methodology.timing-7}   {TIMING-7}
      addMetric {methodology.timing-8}   {TIMING-8}
      addMetric {methodology.timing-14}  {TIMING-14}
      addMetric {methodology.timing-35}  {TIMING-35}
      catch {unset vios}
      foreach idx {6 7 8 14 35} { set vios($idx) 0 }
      # Only run TIMING-* checks
      report_methodology -quiet -checks {TIMING-6 TIMING-7 TIMING-8 TIMING-14 TIMING-35} -return_string
      set violations [get_methodology_violations -quiet]
      foreach vio $violations {
        if {[regexp {TIMING-([0-9]+)#[0-9]+} $vio - num]} {
          if {![info exists vios($num)]} { set vios($num) 0 }
          incr vios($num)
        }
      }
      setMetric {methodology.timing-6}   $vios(6)
      setMetric {methodology.timing-7}   $vios(7)
      setMetric {methodology.timing-8}   $vios(8)
      setMetric {methodology.timing-14}  $vios(14)
      setMetric {methodology.timing-35}  $vios(35)
      set stepStopTime [clock seconds]
      puts " -I- methodology check metrics completed in [expr $stepStopTime - $stepStartTime] seconds"

      if {$detailedReportsPrefix != {}} {
        set empty 1
        catch { file copy ${detailedReportsDir}/${detailedReportsPrefix}.TIMING.rpt ${detailedReportsDir}/${detailedReportsPrefix}.TIMING.rpt.${pid} }
        set FH [open "${detailedReportsDir}/${detailedReportsPrefix}.TIMING.rpt.${pid}" $filemode]
        if {$showFileHeader} {
          puts $FH "# ---------------------------------------------------------------------------"
          puts $FH [format {# Created on %s with report_failfast (%s)} [clock format [clock seconds]] $::tclapp::xilinx::designutils::report_failfast::version ]
          puts $FH "# ---------------------------------------------------------------------------\n"
        }
        foreach idx {6 7 8 14 35} {
          foreach vio [get_methodology_violations -quiet -filter "CHECK==TIMING-$idx"] {
            puts $FH "TIMING-$idx - [get_property -quiet DESCRIPTION [get_methodology_checks -quiet TIMING-$idx]]"
            puts $FH "  => [get_property DESCRIPTION $vio]\n"
            set empty 0
          }
        }
        close $FH
        if {$empty} {
          file delete -force ${detailedReportsDir}/${detailedReportsPrefix}.TIMING.rpt.${pid}
        } else {
          file rename -force ${detailedReportsDir}/${detailedReportsPrefix}.TIMING.rpt.${pid} ${detailedReportsDir}/${detailedReportsPrefix}.TIMING.rpt
          puts " -I- Generated file [file normalize ${detailedReportsDir}/${detailedReportsPrefix}.TIMING.rpt]"
        }
      }

    }

    ########################################################################################
    ##
    ## Average fanout metric
    ##
    ########################################################################################

    if {1 && ([llength [array names guidelines design.cells.maxavgfo*]] == 2) && ([lsearch $skipChecks {average_fanout}] == -1)} {
      set stepStartTime [clock seconds]
      # Make the 100K threshold as a parameter
      set limit $guidelines(design.cells.maxavgfo.limit)
      addMetric {design.cells.maxavgfo}   "Average Fanout for modules > [expr $limit / 1000]k cells"

      catch {unset data}
      # Key '-' holds the list of average fanout for modules > 100K ($limit)
      set data(-) [list 0]
      # Key '@' holds the list of hierarchical cells that have an average fanout for modules > 100K ($limit)
      set data(@) [list]
      switch $reportMode {
        pblockAndTop {
          calculateAvgFanout . $limit
        }
        pblockAndCell {
          calculateAvgFanout $prCell $limit
        }
        pblockOnly {
          # NOT SUPPORTED
        }
        regionAndTop {
          calculateAvgFanout . $limit
        }
        regionAndCell {
          calculateAvgFanout $prCell $limit
        }
        regionOnly {
          # NOT SUPPORTED
        }
        slrAndTop {
          calculateAvgFanout . $limit
        }
        slrAndCell {
          calculateAvgFanout $prCell $limit
        }
        slrOnly {
          # NOT SUPPORTED
        }
        default {
          calculateAvgFanout . $limit
        }
      }
      set maxfo [lindex [lsort -decreasing -real $data(-)] 0]

      setMetric {design.cells.maxavgfo}  $maxfo
      set stepStopTime [clock seconds]
      puts " -I- average fanout metrics completed in [expr $stepStopTime - $stepStartTime] seconds ([expr [llength $data(-)] -1] modules)"

      if {$detailedReportsPrefix != {}} {
        set empty 1
        catch { file copy ${detailedReportsDir}/${detailedReportsPrefix}.AVGFO.rpt ${detailedReportsDir}/${detailedReportsPrefix}.AVGFO.rpt.${pid} }
        set FH [open "${detailedReportsDir}/${detailedReportsPrefix}.AVGFO.rpt.${pid}" $filemode]
        if {$showFileHeader} {
          puts $FH "# ---------------------------------------------------------------------------"
          puts $FH [format {# Created on %s with report_failfast (%s)} [clock format [clock seconds]] $::tclapp::xilinx::designutils::report_failfast::version ]
          puts $FH "# ---------------------------------------------------------------------------\n"
        }
        set tbl [::tclapp::xilinx::designutils::prettyTable create [format "Average Fanout\nMin Module Size: $limit"] ]
        $tbl indent 1
        $tbl header [list {Cell} {Flat Leaf Cells} {Flat Pins} {Flat Average Fanout} ]
        foreach cell [lsort $data(@)] {
          if {[info exists data(${cell}:FLAT_AVG_FANOUT)]} {
            set avgfo $data(${cell}:FLAT_AVG_FANOUT)
          } else {
            set avgfo {n/a}
          }
          if {[info exists data(${cell}:FLAT_PRIMITIVES)]} {
            set numprim $data(${cell}:FLAT_PRIMITIVES)
          } else {
            set numprim {n/a}
          }
          if {[info exists data(${cell}:FLAT_PIN_COUNT)]} {
            set pinco $data(${cell}:FLAT_PIN_COUNT)
          } else {
            set pinco {n/a}
          }
          if {$cell == {.}} {
            set cell {<TOP>}
          }
          $tbl addrow [list $cell $numprim $pinco $avgfo]
          set empty 0
        }
        puts $FH [$tbl print]
        catch {$tbl destroy}
        close $FH
        if {$empty} {
          file delete -force ${detailedReportsDir}/${detailedReportsPrefix}.AVGFO.rpt.${pid}
        } else {
          file rename -force ${detailedReportsDir}/${detailedReportsPrefix}.AVGFO.rpt.${pid} ${detailedReportsDir}/${detailedReportsPrefix}.AVGFO.rpt
          puts " -I- Generated file [file normalize ${detailedReportsDir}/${detailedReportsPrefix}.AVGFO.rpt]"
        }
      }

    }

    ########################################################################################
    ##
    ## Non-FD high fanout nets (fanout) metric
    ##
    ########################################################################################

    if {1 && ([llength [array names guidelines design.nets.nonfdhfn*]] == 2) && ([lsearch $skipChecks {non_fd_hfn}] == -1)} {
      set stepStartTime [clock seconds]
      # Make the 10K threshold as a parameter
      set limit $guidelines(design.nets.nonfdhfn.limit)
      addMetric {design.nets.nonfdhfn}   "Non-FD high fanout nets > [expr $limit / 1000]k loads"

      set nets [get_nets -quiet -top_net_of_hierarchical_group -filter "(FLAT_PIN_COUNT >= $limit) && (TYPE == SIGNAL)" \
                 -of [get_pins -quiet -of $leafCells] ]
      set drivers [get_pins -quiet -of $nets -filter {IS_LEAF && (REF_NAME !~ FD*) && (DIRECTION == OUT)}]
      setMetric {design.nets.nonfdhfn}  [llength $drivers]
      set stepStopTime [clock seconds]
      puts " -I- non-FD high fanout nets completed in [expr $stepStopTime - $stepStartTime] seconds"

      if {$detailedReportsPrefix != {}} {
        set empty 1
        catch { file copy ${detailedReportsDir}/${detailedReportsPrefix}.HFN.rpt ${detailedReportsDir}/${detailedReportsPrefix}.HFN.rpt.${pid} }
        set FH [open "${detailedReportsDir}/${detailedReportsPrefix}.HFN.rpt.${pid}" $filemode]
        if {$showFileHeader} {
          puts $FH "# ---------------------------------------------------------------------------"
          puts $FH [format {# Created on %s with report_failfast (%s)} [clock format [clock seconds]] $::tclapp::xilinx::designutils::report_failfast::version ]
          puts $FH "# ---------------------------------------------------------------------------\n"
        }
        set tbl [::tclapp::xilinx::designutils::prettyTable create [format {Non-FD high fanout nets}] ]
        $tbl indent 1
        $tbl header [list {Driver Type} {Driver Pin} {Net} {Fanout} ]
        foreach pin $drivers {
          set refname [get_property -quiet {REF_NAME} $pin]
          set net [get_nets -quiet -of $pin]
          set fanout [expr [get_property -quiet FLAT_PIN_COUNT $net] -1]
          $tbl addrow [list $refname $pin $net $fanout]
          set empty 0
        }
        puts $FH [$tbl print]
        catch {$tbl destroy}
        close $FH
        if {$empty} {
          file delete -force ${detailedReportsDir}/${detailedReportsPrefix}.HFN.rpt.${pid}
        } else {
          file rename -force ${detailedReportsDir}/${detailedReportsPrefix}.HFN.rpt.${pid} ${detailedReportsDir}/${detailedReportsPrefix}.HFN.rpt
          puts " -I- Generated file [file normalize ${detailedReportsDir}/${detailedReportsPrefix}.HFN.rpt]"
        }
      }

    }

    ########################################################################################
    ##
    ## Number of LUTs in path in critical timing paths
    ##
    ########################################################################################

    # Table generated by Fred:
    #   +----------+----------------------------------+ +------------------------------+ +------------------------------+
    #   |          |       LUT+Net delay budget       | |        Net delay budget      | |       LUT delay budget       |
    #   +----------+----------------------+-----+-----+ +------------------+-----+-----+ +------------------+-----+-----+
    #   |          | -1                   | -2  | -3  | | -1               | -2  | -3  | | -1               | -2  | -3  |
    #   | 7series  | 575                  | 500 | 425 | | 403              | 350 | 298 | | 173              | 150 | 128 |
    #   | US/US+LV | 489                  | 425 | 361 | | 342              | 298 | 253 | | 147              | 128 | 108 |
    #   | US+      | 342                  | 298 | 253 | | 239              | 208 | 177 | | 103              | 89  | 76  |
    #   +----------+----------------------+-----+-----+ +------------------+-----+-----+ +------------------+-----+-----+

    if {1 && ([llength [array names guidelines design.device.maxlvls*]] >= 2) && ([lsearch $skipChecks {path_budgeting}] == -1)} {
      set stepStartTime [clock seconds]

      set emptyLut 1
      set emptyNet 1
      # List of paths that violate the LUT/Net budgeting
      set pathsLut [list]
      set pathsNet [list]
      if {$detailedReportsPrefix != {}} {
        catch { file copy ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_LUT.rpt ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_LUT.rpt.${pid} }
        catch { file copy ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_Net.rpt ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_Net.rpt.${pid} }
        set FHLut [open "${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_LUT.rpt.${pid}" $filemode]
        set FHNet [open "${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_Net.rpt.${pid}" $filemode]
      } else {
        set FHLut {}
        set FHNet {}
      }

      # Timing budget per LUT+NET: 300ps (UltraScale Plus / Speedgrade -2)
      set timBudgetPerLUT 0.300
      set timBudgetPerNet 0.208

      set speedgrade [get_property -quiet SPEED [get_property -quiet PART [current_design]]]
      set architecture [get_property -quiet ARCHITECTURE [get_property -quiet PART [current_design]]]
      switch $architecture {
        artix7 -
        kintex7 -
        virtex7 -
        zynq {
          switch -regexp -- $speedgrade {
            "-1.*" {
              set timBudgetPerLUT 0.575
              set timBudgetPerNet 0.403
            }
            "-2.*" {
              set timBudgetPerLUT 0.500
              set timBudgetPerNet 0.350
            }
            "-3.*" {
              set timBudgetPerLUT 0.425
              set timBudgetPerNet 0.298
            }
            default {
              set timBudgetPerLUT 0.575
              set timBudgetPerNet 0.403
            }
          }
        }
        kintexu -
        kintexum -
        virtexu -
        virtexum {
          switch -regexp -- $speedgrade {
            "-1.*" {
              set timBudgetPerLUT 0.490
              set timBudgetPerNet 0.342
            }
            "-2.*" {
              set timBudgetPerLUT 0.425
              set timBudgetPerNet 0.298
            }
            "-3.*" {
              set timBudgetPerLUT 0.360
              set timBudgetPerNet 0.253
            }
            default {
              set timBudgetPerLUT 0.490
              set timBudgetPerNet 0.342
            }
          }
        }
        zynquplus -
        kintexuplus -
        virtexuplus {
          switch -regexp -- $speedgrade {
            "-1.*" {
              set timBudgetPerLUT 0.350
              set timBudgetPerNet 0.239
            }
            "-2.*" {
              set timBudgetPerLUT 0.300
              set timBudgetPerNet 0.208
            }
            "-3.*" {
              set timBudgetPerLUT 0.250
              set timBudgetPerNet 0.177
            }
            default {
              set timBudgetPerLUT 0.350
              set timBudgetPerNet 0.239
            }
          }
        }
        default {
          puts " -E- architecture $architecture is not supported."
          incr error
        }
      }

      if {$lutBudgeting != 0} {
        set timBudgetPerLUT $lutBudgeting
        puts " -W- LUT budgeting overriden by the user: $lutBudgeting"
      }
      if {$netBudgeting != 0} {
        set timBudgetPerNet $netBudgeting
        puts " -W- Net budgeting overriden by the user: $netBudgeting"
      }

      # Override the LUT+NET budgeting if provided as part as the configuration
      if {$guidelines(design.device.maxlvls.lutbudget) != {}} {
        set timBudgetPerLUT $guidelines(design.device.maxlvls.lutbudget)
      }
      # Override the NET budgeting if provided as part as the configuration
      if {$guidelines(design.device.maxlvls.netbudget) != {}} {
        set timBudgetPerNet $guidelines(design.device.maxlvls.netbudget)
      }

      addMetric {design.device.maxlvls.lut}   "Number of paths above max LUT budgeting (${timBudgetPerLUT}ns)"
      addMetric {design.device.maxlvls.net}   "Number of paths above max Net budgeting (${timBudgetPerNet}ns)"

      # Summary table for LUT/Net budgeting
      set tbl    [::tclapp::xilinx::designutils::prettyTable create [format {Budgeting Summary (lut=%sns/net=%sns)} $timBudgetPerLUT $timBudgetPerNet] ]
      set dbgtbl [::tclapp::xilinx::designutils::prettyTable create [format {Budgeting Summary (lut=%sns/net=%sns)} $timBudgetPerLUT $timBudgetPerNet] ]
      $tbl indent 1
      $dbgtbl indent 1
      $tbl header [list {Group} {Slack} {Requirement} {Skew} {Uncertainty} {Datapath Delay} {Datapath Logic Delay} {Datapath Net Delay} {Logic Levels} {Levels} {Net Budget} {Lut Budget} {Path} {Info} ]
      $dbgtbl header [list {Group} {Slack} {Requirement} {Skew} {Uncertainty} {Datapath Delay} {Datapath Logic Delay} {Datapath Net Delay} {Logic Levels} {Levels} {Net Budget} {Lut Budget} {Path} {Info} ]

      if {$timingPathsBudgeting != {}} {
        # For debug EOU, timnig paths can e passed from the command line
        set spaths $timingPathsBudgeting
        puts " -W- Timing paths provided by the user: [llength $spaths]"
      } else {
        switch $reportMode {
          pblockAndTop {
            set spaths [get_timing_paths -quiet -setup -sort_by group -nworst 1 -max $params(max_paths) -slack_less_than 2.0]
          }
          pblockAndCell {
            set spaths [get_timing_paths -quiet -cell $prCell -setup -sort_by group -nworst 1 -max $params(max_paths) -slack_less_than 2.0]
          }
          pblockOnly {
            # NOT SUPPORTED
          }
          regionAndTop {
            set spaths [get_timing_paths -quiet -setup -sort_by group -nworst 1 -max $params(max_paths) -slack_less_than 2.0]
          }
          regionAndCell {
            set spaths [get_timing_paths -quiet -cell $prCell -setup -sort_by group -nworst 1 -max $params(max_paths) -slack_less_than 2.0]
          }
          regionOnly {
            # NOT SUPPORTED
          }
          slrAndTop {
            set spaths [get_timing_paths -quiet -setup -sort_by group -nworst 1 -max $params(max_paths) -slack_less_than 2.0]
          }
          slrAndCell {
            set spaths [get_timing_paths -quiet -cell $prCell -setup -sort_by group -nworst 1 -max $params(max_paths) -slack_less_than 2.0]
          }
          slrOnly {
            # NOT SUPPORTED
          }
          default {
            set spaths [get_timing_paths -quiet -setup -sort_by group -nworst 1 -max $params(max_paths) -slack_less_than 2.0]
          }
        }
      }

      if {[llength [get_property -quiet CLASS $spaths]] == 1} {
        # Workaround when there is only 1 timing path
        set sps [list [get_property -quiet STARTPOINT_PIN $spaths] ]
        set eps [list [get_property -quiet ENDPOINT_PIN $spaths] ]
        set sprefs [get_property -quiet REF_NAME $sps]
        set eprefs [get_property -quiet REF_NAME $eps]
      } else {
        set sps [get_property -quiet STARTPOINT_PIN $spaths]
        set eps [get_property -quiet ENDPOINT_PIN $spaths]
        set sprefs [get_property -quiet REF_NAME $sps]
        set eprefs [get_property -quiet REF_NAME $eps]
      }
      set numFailedLut 0
      set numFailedNet 0
      set numFailedLutPassNet 0
      set numFailedNetPassLut 0
      set addrow 0
      foreach path $spaths \
              sp $sps \
              spref $sprefs \
              ep $eps \
              epref $eprefs {
        set requirement [get_property -quiet REQUIREMENT $path]
        set logic_levels [get_property -quiet LOGIC_LEVELS $path]
        set group [get_property -quiet GROUP $path]
        set slack [get_property -quiet SLACK $path]
        set skew [get_property -quiet SKEW $path]
        set uncertainty [get_property -quiet UNCERTAINTY $path]
        set datapath_delay [get_property -quiet DATAPATH_DELAY $path]
        set cell_delay [get_property -quiet DATAPATH_LOGIC_DELAY $path]
        set net_delay [get_property -quiet DATAPATH_NET_DELAY $path]
        set addrow 0
        if {$skew == {}} { set skew 0.0 }
        if {$uncertainty == {}} { set uncertainty 0.0 }
        # Number of LUT* in the datapath
        set levels [llength [filter [get_cells -quiet -of $path] {REF_NAME =~ LUT*}]]
        if {![regexp {^FD} $spref] && ![regexp {^LD} $spref]} {
          # If the startpoint is not an FD* or a LD*, then account for it by increasing the number of levels
          incr levels
        }
#         if {!([regexp {^FD} $epref] && ([get_property -quiet REF_PIN_NAME $ep] == {D}))} {
#           # If the endpoint is not an FD*/D, then account for it by increasing the number of levels
#           incr levels
#         }
        # The endpoint needs more processing
        if {[regexp {^[LF]D} $epref]} {
          if {[get_property -quiet REF_PIN_NAME $ep] != {D}} {
            # If the endpoint is not an FD*/D, then account for it by increasing the number of levels
            incr levels
          } else {
            set dnet [get_nets -quiet -of $ep]
            if {[regexp {(INTRASITE|INTRA_SITE)} [get_property -quiet ROUTE_STATUS $dnet]]} {
              # Intra-site net. Do nothing
            } else {
              # If the net connected to the endpoint has a fanout>1 (FLAT_PIN_COUNT>2)
              # then increase the number of levels since there is no shape to force the endpoint
              # and its driver to be placed into the same slice
              if {[get_property -quiet FLAT_PIN_COUNT $dnet] > 2 || ![regexp {LUT*} [get_property -quiet REF_NAME [get_pins -quiet -leaf -filter {DIRECTION==OUT} -of $dnet]]]} {
                incr levels
              }
            }
          }
        } else {
          # If the endpoint is not a register/latch, then increase the number of levels
          incr levels
        }

        # Calculate the maximum number of LUTs based on path requirement, skew and uncertainty
        # int(): truncate (e.g 1.8 => 1)
        # round() : round to the nearest (e.g 1.8 => 2)
        set lut_budget [expr int(($requirement + $skew - $uncertainty) / double($timBudgetPerLUT)) ]
#         set lut_budget [expr round(($requirement + $skew - $uncertainty) / double($timBudgetPerLUT)) ]
        # Calculate the maximum number of Nets based on path requirement, skew, uncertainty and logic cell delay
        set net_budget [expr int(($requirement + $skew - $uncertainty - $cell_delay) / double($timBudgetPerNet)) ]
#         set net_budget [expr round(($requirement + $skew - $uncertainty - $cell_delay) / double($timBudgetPerNet)) ]
        # Calculate the maximum datapath based on path requirement, skew and uncertainty
        set datapath_budget [format {%.3f} [expr double($lut_budget) * double($timBudgetPerLUT)] ]
#         if {$datapath_budget > [expr $requirement + $skew - $uncertainty]} {}

        # Debug table for LUT/Net budgeting
        set row [list $group $slack $requirement $skew $uncertainty $datapath_delay $cell_delay $net_delay $logic_levels $levels]

        if {$levels > $net_budget} {
          # Save the path inside the detailed report file
          if {$FHNet != {}} {
            puts $FHNet [report_timing -quiet -of $path -return_string]
            set emptyNet 0
            # Save the path for the RPX file
            lappend pathsNet $path
          }
          # Debug table for LUT/Net budgeting
          lappend row [format {%s (*)} $net_budget]
          # Path failed => add row to summary table
          incr addrow
          if {$params(debug)} {
#             puts " -D- Net budgeting: $path"
#             puts " -D- net_budget=$net_budget / levels=$levels / slack=$slack / requirement=$requirement / skew=$skew / uncertainty=$uncertainty / dp_budget=$datapath_budget / datapath_delay=$datapath_delay / cell_delay=$cell_delay"
          }
          incr numFailedNet
          if {$levels <= $lut_budget} {
            # Path that fails the net budgeting but passes the lut budgeting
            incr numFailedNetPassLut
          }
        } else {
          # Debug table for LUT/Net budgeting
          lappend row [format {%s} $net_budget]
#             puts " -I- $path"
#             puts " -I- net_budget=$net_budget / levels=$levels / slack=$slack / requirement=$requirement / skew=$skew / uncertainty=$uncertainty / dp_budget=$datapath_budget / datapath_delay=$datapath_delay / cell_delay=$cell_delay"
        }
        if {$levels > $lut_budget} {
          # Save the path inside the detailed report file
          if {$FHLut != {}} {
            puts $FHLut [report_timing -quiet -of $path -return_string]
            set emptyLut 0
            # Save the path for the RPX file
            lappend pathsLut $path
          }
          # Debug table for LUT/Net budgeting
          lappend row [format {%s (*)} $lut_budget]
          # Path failed => add row to summary table
          incr addrow
          if {$params(debug)} {
#             puts " -D- LUT budgeting: $path"
#             puts " -D- lut_budget=$lut_budget / levels=$levels / slack=$slack / requirement=$requirement / skew=$skew / uncertainty=$uncertainty / dp_budget=$datapath_budget / datapath_delay=$datapath_delay"
          }
          incr numFailedLut
          if {$levels <= $net_budget} {
            # Path that fails the lut budgeting but passes the net budgeting
            incr numFailedLutPassNet
          }
        } else {
          # Debug table for LUT/Net budgeting
          lappend row [format {%s} $lut_budget]
#             puts " -I- $path"
#             puts " -I- lut_budget=$lut_budget / levels=$levels / slack=$slack / requirement=$requirement / skew=$skew / uncertainty=$uncertainty / dp_budget=$datapath_budget / datapath_delay=$datapath_delay"
        }
        # Debug table for LUT/Net budgeting
        lappend row [get_property -quiet REF_NAME [get_cells -quiet -of $path]]
        lappend row $path
        if {$addrow} {
          # Add row to the summary table
          $tbl addrow $row
        }
        $dbgtbl addrow $row
      }
      if {$params(debug)} {
        # Debug table for LUT/Net budgeting
        set output [concat $output [split [$dbgtbl print] \n] ]
        catch {$dbgtbl destroy}
        puts [join $output \n]
        set output [list]
        puts " -D- Number of processed paths: [llength $spaths]"
        puts " -D- Number of paths that fail the LUT budgeting but pass the Net budgeting: $numFailedLutPassNet"
        puts " -D- Number of paths that fail the Net budgeting but pass the LUT budgeting: $numFailedNetPassLut"
      }
      setMetric {design.device.maxlvls.lut}  $numFailedLut
      setMetric {design.device.maxlvls.net}  $numFailedNet
      set stepStopTime [clock seconds]
      puts " -I- path budgeting metrics completed in [expr $stepStopTime - $stepStartTime] seconds"
      if {$detailedReportsPrefix != {}} {
        close $FHLut
        close $FHNet
        set FHLut {}
        set FHNet {}
        if {$emptyLut} {
          file delete -force ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_LUT.rpt.${pid}
        } else {
          # Print the summary table at the beginning of the detailed report
          set FHLut [open ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_LUT.rpt {w}]
          set FH [open ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_LUT.rpt.${pid} {r}]
          if {$showFileHeader} {
            puts $FHLut "# ---------------------------------------------------------------------------"
            puts $FHLut [format {# Created on %s with report_failfast (%s)} [clock format [clock seconds]] $::tclapp::xilinx::designutils::report_failfast::version ]
            puts $FHLut "# ---------------------------------------------------------------------------\n"
          }
          foreach line [split [$tbl print] \n] {
            puts $FHLut [format {# %s} $line]
          }
          puts $FHLut "# Note: (*): failed the budgeting\n"
          while {![eof $FH]} {
            gets $FH line
            puts $FHLut $line
          }
          close $FHLut
          close $FH
          file delete -force ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_LUT.rpt.${pid}
#           file rename -force ${detailedReportsPrefix}.timing_budget_LUT.rpt.${pid} ${detailedReportsPrefix}.timing_budget_LUT.rpt
          puts " -I- Generated file [file normalize ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_LUT.rpt]"
          # Save the interactive report (RPX)
          if {[llength $pathsLut]} {
            report_timing -of $pathsLut -rpx ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_LUT.rpx -file ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_LUT.rpx.${pid}
            # Delete temporary file
            catch { file delete -force ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_LUT.rpx.${pid} }
            puts " -I- Generated interactive report [file normalize ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_LUT.rpx]"
          }
        }
        if {$emptyNet} {
          file delete -force ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_Net.rpt.${pid}
        } else {
          # Print the summary table at the beginning of the detailed report
          set FHNet [open ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_Net.rpt {w}]
          set FH [open ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_Net.rpt.${pid} {r}]
          if {$showFileHeader} {
            puts $FHNet "# ---------------------------------------------------------------------------"
            puts $FHNet [format {# Created on %s with report_failfast (%s)} [clock format [clock seconds]] $::tclapp::xilinx::designutils::report_failfast::version ]
            puts $FHNet "# ---------------------------------------------------------------------------\n"
          }
          foreach line [split [$tbl print] \n] {
            puts $FHNet [format {# %s} $line]
          }
          puts $FHNet "# Note: (*): failed the budgeting\n"
          while {![eof $FH]} {
            gets $FH line
            puts $FHNet $line
          }
          close $FHNet
          close $FH
          file delete -force ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_Net.rpt.${pid}
#           file rename -force ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_Net.rpt.${pid} ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_Net.rpt
          puts " -I- Generated file [file normalize ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_Net.rpt]"
          # Save the interactive report (RPX)
          if {[llength $pathsNet]} {
            report_timing -of $pathsNet -rpx ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_Net.rpx -file ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_Net.rpx.${pid}
            # Delete temporary file
            catch { file delete -force ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_Net.rpx.${pid} }
            puts " -I- Generated interactive report [file normalize ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_Net.rpx]"
          }
        }
      }
      # Destroy summary table
      catch {$tbl destroy}

    } else {
      set timBudgetPerLUT {}
      set timBudgetPerNet {}
    }

    ########################################################################################
    ##
    ## Dump all metrics (debug)
    ##
    ########################################################################################

    if {$params(debug)} {
      # Dump the list of metrics categories
      # E.g: metric = 'design.ram.blockram' -> category = 'design'
      set categories [list]
      foreach key [lsort [array names metrics *:def]] {
        lappend categories [lindex [split $key .] 0]
      }
      set categories [lsort -unique $categories]

      set tbl [::tclapp::xilinx::designutils::prettyTable create {Metrics Summary}]
      $tbl indent 1
      $tbl header [list {Id} {Description} {Value}]
      foreach category $categories {
        $tbl separator
        foreach key [regsub -all {:def} [lsort [array names metrics $category.*:def]] {}] {
          # E.g: key = 'design.ram.blockram' -> metric = 'ram.blockram'
          regsub "$category." $key {} metric
          $tbl addrow [list $key $metrics(${key}:description) $metrics(${key}:val)]
        }
      }
      set output [concat $output [split [$tbl print] \n] ]
      catch {$tbl destroy}
      puts [join $output \n]
      set output [list]
    }

    ########################################################################################
    ##
    ##
    ##
    ########################################################################################

  } errorstring]} {
    puts " -E- $errorstring"
  }

  set stopTime [clock seconds]

  ########################################################################################
  ##
  ## Remove any undefined metric:
  ##   Some design do not have any URAM/DSP/CARRY/.... For those ones, remove the
  ##   metrics inside the table instead of showing an ERROR because the metrics
  ##   could not be extracted
  ##
  ########################################################################################

  if {$hideUnextractedMetrics} {
    foreach key [lsort [array names metrics *:def]] {
      set m [regsub {:def} $key {}]
      if {$metrics(${m}:val) == {n/a}} {
        if {[info exists guidelines($m)]} {
          unset guidelines($m)
          if {$params(verbose)} {
            puts " -I- metric '$m' could not be extracted and is hidden"
          }
          dputs " -D- removed reference to $m (n/a)"
        }
      }
    }
  }

  ########################################################################################
  ##
  ## Delete SLR pblocks
  ##
  ########################################################################################

  if {$deletePblocks && (($slrs != {}) || ($regions != {}))} {
    if {$params(debug)} { puts " -D- deleting pblocks: [get_pblocks -quiet failfast_*]" }
    delete_pblocks -quiet [get_pblocks -quiet failfast_*]
  }

  ########################################################################################
  ##
  ## Table generation
  ##
  ########################################################################################

  set title "Design Summary\n[get_property -quiet NAME [current_design]]\n[get_property -quiet PART [current_design]]"
  if {$optionTop} {
    append title "\nCell: <TOP>"
  } elseif {$prCell != {}} {
    append title "\nCell: $prCell"
  }
  if {$excludeCell != {}} {
    append title "\nExcluded cell: $excludeCell"
  }
  if {($prPblock != {}) && ($regions == {})} {
    append title "\nPblock: $prPblock"
  }
  if {$regions != {}} {
    append title "\nRegions: $regions"
  }
  if {$slrs != {}} {
    append title "\nSLR: $slrs"
  }
  set tbl [::tclapp::xilinx::designutils::prettyTable create $title]
  $tbl indent 1
  if {$params(show_resources) || ($params(debug) && ($params(debug_level) >= 2))} {
    # With -show_resources or in debug mode (level >= 2), display the
    # number of elements for the metrics reported as percent as well as
    # the number of available resources.
    # For example:
    #   +-----------------------------------------------------------------------------------------------------------+
    #   | Design Summary                                                                                            |
    #   | checkpoint_stage_9_route_design                                                                           |
    #   | xcku085-flvb1760-2-e                                                                                      |
    #   +-----------------------------------------------------------+-----------+--------+--------+--------+--------+
    #   | Criteria                                                  | Guideline | Actual | Used   | Avail  | Status |
    #   +-----------------------------------------------------------+-----------+--------+--------+--------+--------+
    #   | LUT                                                       | 70%       | 98.77% | 115205 | 116640 | REVIEW |
    #   | FD                                                        | 50%       | 30.03% | 70059  | 233280 | OK     |
    #   | LUTRAM+SRL                                                | 25%       | 0.22%  | 108    | 48960  | OK     |
    #   | CARRY8                                                    | 25%       | 36.62% | 5339   | 14580  | REVIEW |
    #   | MUXF7                                                     | 15%       | 1.58%  | 920    | 58320  | OK     |
    #   | LUT Combining                                             | 20%       | 19.45% | 26049  | -      | OK     |
    #   | DSP48                                                     | 80%       | 24.52% | 253    | 1032   | OK     |
    #   | RAMB/FIFO                                                 | 80%       | 7.20%  | 28.5   | 396    | OK     |
    #   | DSP48+RAMB+URAM (Avg)                                     | 70%       | 15.86% | -      | -      | OK     |
    #   | BUFGCE* + BUFGCTRL                                        | 24        | 5      | 5      | -      | OK     |
    #   | Control Sets                                              | 2187      | 3593   | 3593   | -      | REVIEW |
    #   | Average Fanout for modules > 100k cells                   | 4         | 3.00   | 3.00   | -      | OK     |
    #   | Non-FD high fanout nets > 10k loads                       | 0         | 0      | 0      | -      | OK     |
    #   | ............                                                                                              |
    #   +-----------------------------------------------------------+-----------+--------+--------+--------+--------+
    $tbl header [list {Criteria} {Guideline} {Actual} {Used} {Avail} {Status}]
  } else {
    $tbl header [list {Criteria} {Guideline} {Actual} {Status}]
  }
  generateTableRow tbl {utilization.clb.lut.pct}    {LUT}
  generateTableRow tbl {utilization.clb.ff.pct}     {FD}
  generateTableRow tbl {utilization.clb.ld}         {LD}
  generateTableRow tbl {utilization.clb.lutmem.pct} {LUTRAM+SRL}
  generateTableRow tbl {utilization.clb.carry8.pct} {CARRY8}
  generateTableRow tbl {utilization.clb.f7mux.pct}  {MUXF7}
  generateTableRow tbl {utilization.clb.f8mux.pct}  {MUXF8}
  generateTableRow tbl {design.cells.hlutnm.pct}    {LUT Combining}
  generateTableRow tbl {utilization.dsp.pct}        {DSP48}
  generateTableRow tbl {utilization.ram.tile.pct}   {RAMB/FIFO}
  generateTableRow tbl {utilization.uram.tile.pct}  {URAM}
  generateTableRow tbl {utilization.bigblocks.pct}  {DSP48+RAMB+URAM (Avg)}
  generateTableRow tbl {utilization.clk.all}        {BUFGCE* + BUFGCTRL}
  generateTableRow tbl {design.dont_touch}          {DONT_TOUCH (cells/nets)}
  generateTableRow tbl {utilization.ctrlsets.uniq}  {Control Sets}
  if {[llength [array names guidelines design.cells.maxavgfo*]] == 2} {
#     generateTableRow tbl {design.cells.maxavgfo}      {Average Fanout for modules > 100k cells}
    generateTableRow tbl {design.cells.maxavgfo}      "Average Fanout for modules > [expr $guidelines(design.cells.maxavgfo.limit) / 1000]k cells"
  }
  if {[llength [array names guidelines design.nets.nonfdhfn*]] == 2} {
#     generateTableRow tbl {design.nets.nonfdhfn}       {Non-FD high fanout nets > 10k loads}
    generateTableRow tbl {design.nets.nonfdhfn}       "Non-FD high fanout nets > [expr $guidelines(design.nets.nonfdhfn.limit) / 1000]k loads"
  }
  if {[llength [array names guidelines methodology.*]]} {
    $tbl separator
    generateTableRow tbl {methodology.timing-6}       [format {TIMING-6 (%s)} [get_property -quiet DESCRIPTION [get_methodology_check {TIMING-6}]] ]
    generateTableRow tbl {methodology.timing-7}       [format {TIMING-7 (%s)} [get_property -quiet DESCRIPTION [get_methodology_check {TIMING-7}]] ]
    generateTableRow tbl {methodology.timing-8}       [format {TIMING-8 (%s)} [get_property -quiet DESCRIPTION [get_methodology_check {TIMING-8}]] ]
    generateTableRow tbl {methodology.timing-14}      [format {TIMING-14 (%s)} [get_property -quiet DESCRIPTION [get_methodology_check {TIMING-14}]] ]
    generateTableRow tbl {methodology.timing-35}      [format {TIMING-35 (%s)} [get_property -quiet DESCRIPTION [get_methodology_check {TIMING-35}]] ]
  }
  if {([llength [array names guidelines design.device.maxlvls.lut*]] == 2)
   || ([llength [array names guidelines design.device.maxlvls.net*]] == 2)} {
    $tbl separator
  }
  if {[llength [array names guidelines design.device.maxlvls.lut*]] == 2} {
    generateTableRow tbl {design.device.maxlvls.lut}
  }
  if {[llength [array names guidelines design.device.maxlvls.net*]] == 2} {
    generateTableRow tbl {design.device.maxlvls.net}
  }

  foreach line [split [$tbl print] \n] {
    lappend output [format {# %s} $line]
  }
  catch {$tbl destroy}

  ########################################################################################
  ##
  ## CSV generation
  ##
  ########################################################################################

  set tblcsv [::tclapp::xilinx::designutils::prettyTable create]
  $tblcsv indent 1
  $tblcsv header [list {Id} {Description} {Value}]

  # Example of run directory: /xxx/<suite>/<design>/<rundir>
  set dir [file split [pwd]]
  # E.g: <suite>
  set suite [lindex $dir end-2]
  # E.g: <design>
  set design [lindex $dir end-1]
  if {$SUITE_INTEGRATION} {
    $tblcsv addrow [list {design.suite} {Design Suite} $suite]
    $tblcsv addrow [list {design.name} {Design Name} $design]
  }
  $tblcsv addrow [list {design.part}                {Part}               [getMetric {design.part}] ]
  $tblcsv addrow [list {design.top}                 {Top}                [get_property -quiet TOP [current_design -quiet]] ]
  $tblcsv addrow [list {design.run.pr.cell}         {PR (Cell)}          $prCell ]
  $tblcsv addrow [list {design.run.pr.pblock}       {PR (Pblock)}        $prPblock ]
  $tblcsv addrow [list {design.run.slr}             {SLR-Level Analysis} $slrs ]
  $tblcsv addrow [list {design.run.regions}         {Clock Regions} $regions ]
  $tblcsv addrow [list {utilization.clb.lut}        {LUT(#)}             [getMetric {utilization.clb.lut}] ]
  $tblcsv addrow [list {utilization.clb.ff}         {FD(#)}              [getMetric {utilization.clb.ff}] ]
  $tblcsv addrow [list {utilization.ram.tile}       {RAMB/FIFO(#)}       [getMetric {utilization.ram.tile}] ]
  $tblcsv addrow [list {utilization.uram.tile}      {URAM(#)}            [getMetric {utilization.uram.tile}] ]
  $tblcsv addrow [list {utilization.dsp}            {DSP48(#)}           [getMetric {utilization.dsp}] ]
  $tblcsv addrow [list {design.failure}             {Criteria to review} $params(failed) ]
  $tblcsv addrow [list {utilization.clb.lut.pct}    {LUT(%)}                [getMetric {utilization.clb.lut.pct}] ]
  $tblcsv addrow [list {utilization.clb.ff.pct}     {FD(%)}                 [getMetric {utilization.clb.ff.pct}] ]
  $tblcsv addrow [list {utilization.clb.lutmem.pct} {LUTRAM+SRL(%)}         [getMetric {utilization.clb.lutmem.pct}] ]
  $tblcsv addrow [list {utilization.clb.carry8.pct} {CARRY8(%)}             [getMetric {utilization.clb.carry8.pct}] ]
  $tblcsv addrow [list {utilization.clb.f7mux.pct}  {MUXF7(%)}              [getMetric {utilization.clb.f7mux.pct}] ]
  $tblcsv addrow [list {utilization.clb.f8mux.pct}  {MUXF8(%)}              [getMetric {utilization.clb.f8mux.pct}] ]
  $tblcsv addrow [list {design.cells.hlutnm.pct}    {LUT Combining(%)}      [getMetric {design.cells.hlutnm.pct}] ]
  $tblcsv addrow [list {utilization.dsp.pct}        {DSP48(%)}              [getMetric {utilization.dsp.pct}] ]
  $tblcsv addrow [list {utilization.ram.tile.pct}   {RAMB/FIFO(%)}          [getMetric {utilization.ram.tile.pct}] ]
  $tblcsv addrow [list {utilization.uram.tile.pct}  {URAM(%)}               [getMetric {utilization.ram.tile.pct}] ]
  $tblcsv addrow [list {utilization.bigblocks.pct}  {DSP48+RAMB+URAM (Avg)(%)}       [getMetric {utilization.bigblocks.pct}] ]
  $tblcsv addrow [list {utilization.clk.all}        {BUFGCE* + BUFGCTRL} [getMetric {utilization.clk.all}] ]
  $tblcsv addrow [list {utilization.ctrlsets.uniq}  {Control Sets}       [getMetric {utilization.ctrlsets.uniq}] ]
  $tblcsv addrow [list {design.dont_touch}          {DONT_TOUCH(#)}      [getMetric {design.dont_touch}] ]
  if {[llength [array names guidelines design.cells.maxavgfo*]] == 2} {
    $tblcsv addrow [list {design.cells.maxavgfo}      "Average Fanout for modules > [expr $guidelines(design.cells.maxavgfo.limit) / 1000]k cells" [getMetric {design.cells.maxavgfo}] ]
  }
  if {[llength [array names guidelines design.nets.nonfdhfn*]] == 2} {
    $tblcsv addrow [list {design.nets.nonfdhfn}       "Non-FD high fanout nets > [expr $guidelines(design.nets.nonfdhfn.limit) / 1000]k loads"     [getMetric {design.nets.nonfdhfn}] ]
  }
  $tblcsv addrow [list {methodology.timing-6}       {TIMING-6}           [getMetric {methodology.timing-6}] ]
  $tblcsv addrow [list {methodology.timing-7}       {TIMING-7}           [getMetric {methodology.timing-7}] ]
  $tblcsv addrow [list {methodology.timing-8}       {TIMING-8}           [getMetric {methodology.timing-8}] ]
  $tblcsv addrow [list {methodology.timing-14}      {TIMING-14}          [getMetric {methodology.timing-14}] ]
  $tblcsv addrow [list {methodology.timing-35}      {TIMING-35}          [getMetric {methodology.timing-35}] ]
  $tblcsv addrow [list {design.device.maxlvls.lut}  "Number of paths above max LUT budgeting ${timBudgetPerLUT}ns" [getMetric {design.device.maxlvls.lut}] ]
  $tblcsv addrow [list {design.device.maxlvls.net}  "Number of paths above max Net budgeting ${timBudgetPerNet}ns" [getMetric {design.device.maxlvls.net}] ]
  # puts [$tblcsv print]
  if {$params(transpose)} {
    $tblcsv transpose
  }

  ########################################################################################
  ##
  ##
  ##
  ########################################################################################

  puts [join $output \n]

  if {$filename != {}} {
    set FH [open $filename $filemode]
    if {$showFileHeader} {
      puts $FH "# ---------------------------------------------------------------------------------"
      puts $FH [format {# Created on %s with report_failfast (%s)} [clock format [clock seconds]] $::tclapp::xilinx::designutils::report_failfast::version ]
      puts $FH "# ---------------------------------------------------------------------------------\n"
    }
    puts $FH [join $output \n]
    puts $FH ""
    # Only add the CSV table if requested
    if {$params(format) == {csv}} {
      puts $FH [$tblcsv export -format $params(format)]
    }
#     puts $FH [$tblcsv export -format csv]
    close $FH
    puts " -I- Generated file [file normalize $filename]"
  } else {
#     puts [join $output \n]
  }

  puts " -I- Number of criteria to review: $params(failed)"
  puts " -I- This report should be run before placing the design and uses conservative guidelines beyond which runtime and timing closure will likely be more challenging"
  puts " -I- report_failfast completed in [expr $stopTime - $startTime] seconds"

  # Destroy table
  catch {$tblcsv destroy}

  return $params(failed)
}

########################################################################################
##
## Helper Procs
##
########################################################################################

# Configuration for various guideline thresholds
proc ::tclapp::xilinx::designutils::report_failfast::config {} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  variable guidelines
  # Threshold (PASS) for LUT
  set guidelines(utilization.clb.lut.pct)         {<=70%}

  # Threshold (PASS) for FD
  set guidelines(utilization.clb.ff.pct)          {<=50%}

  # Threshold (PASS) for LD
  # set guidelines(utilization.clb.ld)              {<=10000}

  # Threshold (PASS) for LUTRAM+SRL
  set guidelines(utilization.clb.lutmem.pct)      {<=25%}

  # Threshold (PASS) for CARRY8
  set guidelines(utilization.clb.carry8.pct)      {<=25%}

  # Threshold (PASS) for MUXF7
  set guidelines(utilization.clb.f7mux.pct)       {<=15%}

  # Threshold (PASS) for MUXF8
#   set guidelines(utilization.clb.f8mux.pct)       {<=7%}

  # Threshold (PASS) for LUT Combining (HLUTNM)
  set guidelines(design.cells.hlutnm.pct)         {<=20%}

  # Threshold (PASS) for DSP48
  set guidelines(utilization.dsp.pct)             {<=80%}

  # Threshold (PASS) for RAMB36/FIFO36
  set guidelines(utilization.ram.tile.pct)        {<=80%}

  # Threshold (PASS) for URAM
  set guidelines(utilization.uram.tile.pct)        {<=80%}

  # Threshold (PASS) for DSP48+RAMB38+URAM (average)
  set guidelines(utilization.bigblocks.pct)       {<=70%}

  # Threshold (PASS) for BUFGCE* + BUFGCTRL
  set guidelines(utilization.clk.all)             {<=24}

  # Threshold (PASS) for Control Sets
  #   Do not include any number to let the script calculate the number
  #   of control sets based on the number of available FD resources
#   set guidelines(utilization.ctrlsets.uniq)       {<=10000}
  set guidelines(utilization.ctrlsets.uniq)       {<=}

  # Threshold (PASS) for DONT_TOUCH properties
  set guidelines(design.dont_touch)               "=0"

  # Limit for 'Average Fanout for modules > ...k cells' calculation
  set guidelines(design.cells.maxavgfo.limit)     {100000}

  # Threshold (PASS) for Average Fanout for modules > 100k cells
  set guidelines(design.cells.maxavgfo)           {<=4}

  # Limit for 'Non-FD high fanout nets > ...k loads' calculation
  set guidelines(design.nets.nonfdhfn.limit)      {10000}

  # Threshold (PASS) for Non-FD high fanout nets > 10k loads
  set guidelines(design.nets.nonfdhfn)            {=0}

  # Threshold (PASS) for TIMING-6
  set guidelines(methodology.timing-6)            {=0}

  # Threshold (PASS) for TIMING-7
  set guidelines(methodology.timing-7)            {=0}

  # Threshold (PASS) for TIMING-8
  set guidelines(methodology.timing-8)            {=0}

  # Threshold (PASS) for TIMING-14
  set guidelines(methodology.timing-14)           {=0}

  # Threshold (PASS) for TIMING-35
  set guidelines(methodology.timing-35)           {=0}

  # LUT (LUT+Net) budgeting. If empty, LUT budgeting is based on FPGA family and speedgrade
  set guidelines(design.device.maxlvls.lutbudget) {}

  # Net budgeting. If empty, Net budgeting is based on FPGA family and speedgrade
  set guidelines(design.device.maxlvls.netbudget) {}

  # Threshold (PASS) for LUT (LUT+Net) budgeting
  set guidelines(design.device.maxlvls.lut)       "=0"

  # Threshold (PASS) for Net budgeting
  set guidelines(design.device.maxlvls.net)       "=0"

  return -code ok
}

proc ::tclapp::xilinx::designutils::report_failfast::calculateAvgFanout {cell minCellCount} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  variable data
  set current [current_instance -quiet .]
  current_instance -quiet
  current_instance -quiet $cell
  set hierCells [lsort [get_cells -quiet -filter {!IS_PRIMITIVE}]]
  foreach c $hierCells {
    calculateAvgFanout $c $minCellCount
  }

  set primitives [get_cells -quiet -filter {IS_PRIMITIVE && REF_NAME !~ BUFG* && REF_NAME !~ VCC && REF_NAME !~ GND}]
  set opins [get_pins -quiet -of $primitives -filter {!IS_CLOCK && DIRECTION == OUT && IS_CONNECTED}]
  set nets [get_nets -quiet -of $opins -filter {(FLAT_PIN_COUNT > 1) && (TYPE == SIGNAL)}]
  set avgFanout 0.0
  set totalFlatPinCount 0
  set numPins [llength $opins]
  set numPrimitives [llength $primitives]
  if {[llength $nets] != 0} {
    # Calculate total fanout of the cell
    set totalFlatPinCount [expr [join [get_property -quiet FLAT_PIN_COUNT $nets] +] ]
  }

  # Calculate the average pin fanout of the cell
  if {$numPins != 0} {
    set avgFanout [format {%.2f} [expr ((1.0 * $totalFlatPinCount) - $numPins) / $numPins ] ]
  } else {
    set avgFanout 0.0
  }

  set data(${cell}:PIN_COUNT) $totalFlatPinCount
  set data(${cell}:OPINS) $numPins
  set data(${cell}:PRIMITIVES) $numPrimitives
  set data(${cell}:AVG_FANOUT) $avgFanout

# puts "#primitives: [llength $primitives]"
# puts "#hierCells: [llength $hierCells]"
# puts "#opins: [llength $opins]"
# puts "#totalFlatPinCount: $totalFlatPinCount"

  foreach c $hierCells {
    set totalFlatPinCount [expr $totalFlatPinCount + $data(${c}:FLAT_PIN_COUNT)]
    set numPins [expr $numPins + $data(${c}:FLAT_OPINS)]
    set numPrimitives [expr $numPrimitives + $data(${c}:FLAT_PRIMITIVES)]
  }

  # Calculate the average pin fanout of the cell
  if {$numPins != 0} {
    set avgFanout [format {%.2f} [expr ((1.0 * $totalFlatPinCount) - $numPins) / $numPins ] ]
  } else {
    set avgFanout 0.0
  }

  set data(${cell}:FLAT_PIN_COUNT) $totalFlatPinCount
  set data(${cell}:FLAT_OPINS) $numPins
  set data(${cell}:FLAT_PRIMITIVES) $numPrimitives
  set data(${cell}:FLAT_AVG_FANOUT) $avgFanout

  if {$numPrimitives > $minCellCount} {
    lappend data(-) $avgFanout
    lappend data(@) $cell
#     puts "$cell / numPrimitives=$numPrimitives / avgFanout=$avgFanout"
  }

  current_instance -quiet $current
  # Make sure the memory is released
  set primitives {}
  set opins {}
  set nets {}
  set hierCells {}
  return $avgFanout
}

# Return the average fanout for a module
proc ::tclapp::xilinx::designutils::report_failfast::getAvgFanout {cell} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  set current [current_instance -quiet .]
  current_instance -quiet
  current_instance -quiet $cell
  set primitives [get_cells -quiet -hierarchical -filter {IS_PRIMITIVE && PRIMITIVE_LEVEL != MACRO && REF_NAME !~ BUFG* && REF_NAME !~ VCC && REF_NAME !~ GND}]
  set opins [get_pins -quiet -of $primitives -filter {!IS_CLOCK && DIRECTION == OUT && IS_CONNECTED && IS_LEAF}]
  set nets [get_nets -quiet -of $opins -filter {(FLAT_PIN_COUNT > 1) && (TYPE == SIGNAL)}]
#   set avgFanout {N/A}
  set avgFanout 0.0
  if {[llength $nets] != 0} {
    # Calculate total fanout of the cell
    set totalFlatPinCount [expr [join [get_property -quiet FLAT_PIN_COUNT $nets] +] ]
    # Calculate the average pin fanout of the cell
    set avgFanout [format {%.2f} [expr ((1.0 * $totalFlatPinCount) - [llength $opins]) / [llength $opins] ] ]
  }
# puts "#primitives: [llength $primitives]"
# puts "#opins: [llength $opins]"
# puts "#totalFlatPinCount: $totalFlatPinCount"
  # Make sure the memory is released
  set primitives {}
  set opins {}
  set nets {}
  current_instance -quiet $current
  return $avgFanout
}

# Return the list modules that have a number of primitives more than <min>
# and a number of hierarchical orimitives more than <hmin>
proc ::tclapp::xilinx::designutils::report_failfast::getModules {level min hmin} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  set current [current_instance -quiet .]
  set L [list]
  current_instance -quiet
  current_instance -quiet $level
  set primitives [get_cells -quiet -filter {IS_PRIMITIVE}]
  if {[llength $primitives] < $min} {
    set L {}
  } else {
    set L $level
  }
  set hierPrimitives [get_cells -quiet -hier -filter {IS_PRIMITIVE}]
  if {[llength $hierPrimitives] < $hmin} {
    current_instance -quiet $current
    # Make sure the memory is released
    set primitives {}
    set hierPrimitives {}
    return {}
  }
# puts -nonewline "Entering $level"
# puts " (hier=[llength $hierPrimitives]) (local=[llength $primitives])"
#   set L $level
  set hierCells [lsort [get_cells -quiet -filter {!IS_PRIMITIVE}]]
  foreach cell $hierCells {
    set L [concat $L [getModules $cell $min $hmin]]
  }
  current_instance -quiet $current
  # Make sure the memory is released
  set primitives {}
  set hierPrimitives {}
  set hierCells {}
  return $L
}

# Get the list of PARENT modules for a list of cell(s)
proc ::tclapp::xilinx::designutils::report_failfast::getParentCells {cells} {
  # Summary :
  # Argument Usage:
  # Return Value:
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

proc ::tclapp::xilinx::designutils::report_failfast::generateTableRow {&tbl name {description {}}} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  variable guidelines
  variable metrics
  variable params
  if {![info exists metrics(${name}:def)]} {
    if {$params(debug)} {
      puts " -E- metric '$name' does not exist"
    }
    return -code ok
  }
  if {![info exists guidelines(${name})]} {
    if {$params(debug)} {
      puts " -E- guideline for '$name' does not exist"
    }
    return -code ok
  }
  upvar 1 ${&tbl} tbl
#   set status {PASS}
  set status {OK}
  set suffix {}
  # Get guideline for metric $name
  set guideline $guidelines($name)
  # Is the guideline expressed in %?
  if {[regexp {%$} $guideline]} {
    set suffix {%}
    regsub {%$} $guideline {} guideline
  }
  if {[regexp {^([^0-9]+)([0-9].*)$} $guideline - mode m]} {
    set guideline $m
  } else {
    set mode {<=}
  }
  if {$description == {}} {
    set description $metrics(${name}:description)
  }
  set value [getMetric $name]
  set row [list]
  lappend row $description
#   lappend row ${mode}${guideline}${suffix}
  lappend row ${guideline}${suffix}
  lappend row ${value}${suffix}
  if {$params(show_resources) || ($params(debug) && ($params(debug_level) >= 2))} {
    # With -show_resources or in debug mode (level >= 2), display the number
    # of elements and available resources for a specific metric specified in percent.
    # To find the metric name that represent the number of elements
    # remove the '.pct' string.
    # For example:
    #   utilization.dsp.pct => utilization.dsp
    regsub {.pct} $name {} numeral
    if {[info exists metrics(${numeral}:def)]} {
      lappend row [getMetric $numeral]
    } else {
      lappend row {-}
    }
    # And number of available resources:
    #   utilization.dsp => utilization.dsp.avail
    append numeral ".avail"
    if {[info exists metrics(${numeral}:def)]} {
      lappend row [getMetric $numeral]
    } else {
      lappend row {-}
    }
  }
  switch $mode {
    "<=" {
      if {$value > $guideline} {
        set status {REVIEW}
      }
    }
    "<" {
      if {$value >= $guideline} {
        set status {REVIEW}
      }
    }
    ">=" {
      if {$value < $guideline} {
        set status {REVIEW}
      }
    }
    ">" {
      if {$value <= $guideline} {
        set status {REVIEW}
      }
    }
    "=" -
    "==" {
      if {$value != $guideline} {
        set status {REVIEW}
      }
    }
    "!=" {
      if {$value == $guideline} {
        set status {REVIEW}
      }
    }
  }
  if {$value == {n/a}} { set status {ERROR} }
  lappend row $status
  switch $status {
    REVIEW -
    ERROR {
      incr params(failed)
    }
  }
  # Add row to table
  $tbl addrow $row
  return -code ok
}

proc ::tclapp::xilinx::designutils::report_failfast::reset { {force 0} } {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  variable metrics
  variable params
  variable guidelines
  if {$params(debug) && !$force} {
    # Do not remove arrays in debug mode
    return -code ok
  }
  catch { unset metrics }
  catch { unset guidelines }
  array set reports [list]
  array set metrics [list]
  return -code ok
}

proc ::tclapp::xilinx::designutils::report_failfast::addMetric {name {description {}}} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  variable metrics
  variable params
  if {[info exists metrics(${name}:def)]} {
    if {$params(verbose)} { puts " -W- metric '$name' already exist. Skipping new definition" }
    return -code ok
  }
  if {$description == {}} { set description $name }
  set metrics(${name}:def) 1
  set metrics(${name}:description) $description
  set metrics(${name}:val) {}
  return -code ok
}

proc ::tclapp::xilinx::designutils::report_failfast::getMetric {name} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  variable metrics
  variable params
  if {![info exists metrics(${name}:def)]} {
    if {$params(debug)} {
      puts " -E- metric '$name' does not exist"
    }
    return {}
  }
  return $metrics(${name}:val)
}

proc ::tclapp::xilinx::designutils::report_failfast::setMetric {name value} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  variable metrics
  if {![info exists metrics(${name}:def)]} {
    puts " -E- metric '$name' does not exist"
    return -code ok
  }
  dputs " -D- setting: $name = $value"
  set metrics(${name}:def) 2
  set metrics(${name}:val) $value
  return -code ok
}

# Supports a single pattern
#       extractMetricFromPattern report {utilization.clb.lut}         {\|\s+CLB LUTs[^\|]*\s*\|\s+([0-9\.]+)\s+\|}                                                      {n/a}
#       extractMetricFromPattern report {utilization.clb.lut.pct}     {\|\s+CLB LUTs[^\|]*\s*\|\s+[0-9\.]+\s+\|\s+[0-9\.]+\s+\|\s+[0-9\.]+\s+\|\s+<?([0-9\.]+)\s+\|}    {n/a}
proc ::tclapp::xilinx::designutils::report_failfast::extractMetricFromPattern {&report name exp {notfound {n/a}} {save 1}} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  variable metrics
  upvar ${&report} report
  if {![info exists metrics(${name}:def)]} {
    puts " -E- metric '$name' does not exist"
    return -code ok
  }
  if {![regexp -nocase -- $exp $report -- value]} {
    set value $notfound
    dputs " -D- failed to extract metric '$name' from report"
  }
  if {!$save} {
    return $value
  }
  setMetric $name $value
#   dputs " -D- setting: $name = $value"
#   set metrics(${name}:def) 2
#   set metrics(${name}:val) $value
  return -code ok
}

# Supports a list of patterns
#       extractMetricFromPattern2 report {utilization.clb.lut}     -p [list \
#                                                                   {\|\s+CLB LUTs[^\|]*\s*\|\s+[0-9\.]+\s+\|\s+[0-9\.]+\s+\|\s+([0-9\.]+)\s+\|\s+[0-9\.]+\s+\|\s+[0-9\.]+\s+\|\s+<?[0-9\.]+\s+\|} \
#                                                                 {\|\s+SLICE LUTs[^\|]*\s*\|\s+[0-9\.]+\s+\|\s+[0-9\.]+\s+\|\s+([0-9\.]+)\s+\|\s+[0-9\.]+\s+\|\s+[0-9\.]+\s+\|\s+<?[0-9\.]+\s+\|} \
#                                                                   {\|\s+CLB LUTs[^\|]*\s*\|\s+([0-9\.]+)\s+\|} \
#                                                                 {\|\s+SLICE LUTs[^\|]*\s*\|\s+([0-9\.]+)\s+\|} \
#                                                                     ] \
#                                                                  -default {n/a}
#       extractMetricFromPattern2 report {utilization.clb.lut.pct} -p [list \
#                                                                   {\|\s+CLB LUTs[^\|]*\s*\|\s+[0-9\.]+\s+\|\s+[0-9\.]+\s+\|\s+[0-9\.]+\s+\|\s+[0-9\.]+\s+\|\s+[0-9\.]+\s+\|\s+<?([0-9\.]+)\s+\|} \
#                                                                 {\|\s+SLICE LUTs[^\|]*\s*\|\s+[0-9\.]+\s+\|\s+[0-9\.]+\s+\|\s+[0-9\.]+\s+\|\s+[0-9\.]+\s+\|\s+[0-9\.]+\s+\|\s+<?([0-9\.]+)\s+\|} \
#                                                                   {\|\s+CLB LUTs[^\|]*\s*\|\s+[0-9\.]+\s+\|\s+[0-9\.]+\s+\|\s+[0-9\.]+\s+\|\s+<?([0-9\.]+)\s+\|} \
#                                                                 {\|\s+SLICE LUTs[^\|]*\s*\|\s+[0-9\.]+\s+\|\s+[0-9\.]+\s+\|\s+[0-9\.]+\s+\|\s+<?([0-9\.]+)\s+\|} \
#                                                                     ] \
#                                                                  -default {n/a}
proc ::tclapp::xilinx::designutils::report_failfast::extractMetricFromPattern2 {&report name args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  variable metrics
  upvar ${&report} report
  array set defaults [list \
      -default {n/a} \
      -save 1 \
      -p [list] \
    ]
  array set options [array get defaults]
  array set options $args
  if {![info exists metrics(${name}:def)]} {
    puts " -E- metric '$name' does not exist"
    return -code ok
  }
  # Default value if not found in any pattern
  set value $options(-default)
  set found 0
  foreach exp $options(-p) {
    if {![regexp -nocase -- $exp $report -- value]} {
    } else {
      set found 1
      break
    }
  }
  if {!$found} {
    dputs " -D- failed to extract metric '$name' from report"
  }
  if {!$options(-save)} {
    return $value
  }
  setMetric $name $value
#   dputs " -D- setting: $name = $value"
#   set metrics(${name}:def) 2
#   set metrics(${name}:val) $value
  return -code ok
}

# Supports a list of patterns
#       extractMetricFromTable report {utilization.clb.lut}      -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{CLB LUTs} {SLICE LUTs}} -column {Used} -default {n/a}
#       extractMetricFromTable report {utilization.clb.lut.pct}  -search {{(Slice|CLB) Logic\s*$} {(Slice|CLB) Logic\s*$}} -row {{CLB LUTs} {SLICE LUTs}} -column {Util%} -trim float -default {n/a}
proc ::tclapp::xilinx::designutils::report_failfast::extractMetricFromTable {&report name args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  variable params
  variable metrics
  upvar ${&report} report
  # -nth: if the row appear several times inside the table, then get value from nth row
  array set defaults [list \
      -default {n/a} \
      -search {.*} \
      -row {} \
      -nth 0 \
      -column {} \
      -trim {} \
      -save 1 \
      -debug $params(debug) \
    ]
  array set options [array get defaults]
  array set options $args
  if {![info exists metrics(${name}:def)]} {
    puts " -E- metric '$name' does not exist"
    return -code ok
  }
  set value $options(-default)
  if {[catch {set value [extractTableValue -error_if_not_found 1 -rpt $report -search $options(-search) -trim $options(-trim) -default $options(-default) -nth $options(-nth) -row $options(-row) -column $options(-column) -debug $options(-debug) ]} errorstring]} {
    set value $errorstring
    dputs " -D- failed to extract metric '$name' from report"
  }
  if {!$options(-save)} {
    return $value
  }
  setMetric $name $value
#   dputs " -D- setting: $name = $value"
#   set metrics(${name}:def) 2
#   set metrics(${name}:val) $value
  return -code ok
}

# Return the pblock + its children
proc ::tclapp::xilinx::designutils::report_failfast::getChildPblocks {pblock} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Rebuild the pblock data structure at each call (unoptimal)
  foreach pb [get_pblocks -quiet] {
    set parent [get_property -quiet PARENT $pb]
    lappend db(${parent}:child) $pb
    lappend db(${pb}:parent) $parent
  }
  # Search for children
  if {![info exists db(${pblock}:child)]} {
    return [get_pblocks -quiet $pblock]
  }
  if {$pblock == {ROOT}} {
    set L {}
  } else {
    set L [list $pblock]
  }
  foreach child $db(${pblock}:child) {
    set L [concat $L [getChildPblocks $child]]
  }
  return [get_pblocks -quiet $L]
}

# Return the pblock + its parents
proc ::tclapp::xilinx::designutils::report_failfast::getParentPblocks {pblock} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Rebuild the pblock data structure at each call (unoptimal)
  foreach pb [get_pblocks -quiet] {
    set parent [get_property -quiet PARENT $pb]
    lappend db(${parent}:child) $pb
    lappend db(${pb}:parent) $parent
  }
  # Search for parents
  if {$pblock == {ROOT}} {
    return {}
  }
  if {![info exists db(${pblock}:parent)]} {
    return [get_pblocks -quiet $pblock]
  }
  set L [list $pblock]
  foreach parent $db(${pblock}:parent) {
    set L [concat $L [getParentPblocks $parent]]
  }
  return [get_pblocks -quiet $L]
}

proc ::tclapp::xilinx::designutils::report_failfast::max {x y} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  expr {$x>$y?$x:$y}
}

proc ::tclapp::xilinx::designutils::report_failfast::min {x y} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  expr {$x<$y? $x:$y}
}

# Expand patterns
# Example: X0Y0:X1Y2 => X0Y0 X1Y0 X0Y1 X1Y1 X0Y2 X1Y2
proc ::tclapp::xilinx::designutils::report_failfast::expandPattern { pattern } {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  if {[regexp {^([^\:]*)X(\d*)Y(\d*)$} $pattern]} {
    # Single element (e.g clock region)
    return $pattern
  }
  if {[regexp {^(.*)X(\d*)Y(\d*)\:(.*)X(\d*)Y(\d*)$} $pattern - prefix Xmin Ymin - Xmax Ymax]} {
    # Range of elements (e.g clock regions)
#     puts "$Xmin $Ymin $Xmax $Ymax"
    set regions [list]
    for { set X [min $Xmin $Xmax] } { $X <= [max $Xmin $Xmax] } { incr X } {
      for { set Y [min $Ymin $Ymax] } { $Y <= [max $Ymin $Ymax] } { incr Y } {
        lappend regions "${prefix}X${X}Y${Y}"
      }
    }
    return $regions
  }
  # Unrecognized pattern
  return $pattern
}

# Generate a list of integers
proc ::tclapp::xilinx::designutils::report_failfast::iota {from to} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  set out [list]
  if {$from <= $to} {
    for {set i $from} {$i <= $to} {incr i}    {lappend out $i}
  } else {
    for {set i $from} {$i >= $to} {incr i -1} {lappend out $i}
  }
  return $out
}

proc ::tclapp::xilinx::designutils::report_failfast::dputs {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
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
# ::tclapp::xilinx::designutils::report_failfast::extract_columns
#------------------------------------------------------------------------
# Extract position of columns based on the column separator string
#  str:   string to be used to extract columns
#  match: column separator string
#------------------------------------------------------------------------

# E.g:
#    WNS(ns)      TNS(ns)  TNS Failing Endpoints
#    -------      -------  ---------------------
#     -0.261       -0.261                      1
#
#  extract_columns [string trimright $line] { }
#                ^                          ^^^
#   => {11 24}
#
#  extract_columns2 [string trimright $line] {-} =>
#                ^^                          ^^^
#   => {4 17 26}

# This columns returned by extract_columns are the right-most position of each column
# E.e: extract_columns2 [string trimright $line] { }
# match: separator character between columns
proc ::tclapp::xilinx::designutils::report_failfast::extract_columns { str match } {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  set col 0
  set columns [list]
  set previous -1
  while {[set col [string first $match $str [expr $previous +1]]] != -1} {
    if {[expr $col - $previous] > 1} {
      lappend columns $col
    }
    set previous $col
  }
  return $columns
}

# This columns returned by extract_columns are the left-most position of each column
# E.e: extract_columns2 [string trimright $line] {-}
# match: character that delimit the columns
proc ::tclapp::xilinx::designutils::report_failfast::extract_columns2 { str match } {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  set col 0
  set columns [list]
  set previous -2
  while {[set col [string first $match $str [expr $previous +1]]] != -1} {
    if {[expr $col - $previous] > 1} {
      lappend columns $col
    }
    set previous $col
  }
  return $columns
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::report_failfast::extract_row
#------------------------------------------------------------------------
# Extract all the cells of a row (string) based on the position
# of the columns
#------------------------------------------------------------------------
# To be used with extract_columns
#                               ^
proc ::tclapp::xilinx::designutils::report_failfast::extract_row {str columns} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  lappend columns [string length $str]
  set row [list]
  set pos 0
  foreach col $columns {
    set value [string trim [string range $str $pos $col]]
    lappend row $value
    set pos [incr col 2]
  }
  return $row
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::report_failfast::extract_row2
#------------------------------------------------------------------------
# Extract all the cells of a row (string) based on the position
# of the columns
#------------------------------------------------------------------------
# To be used with extract_columns2
#                               ^^
proc ::tclapp::xilinx::designutils::report_failfast::extract_row2 {str columns} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  set row [list]
  for {set i 0} {$i < [expr [llength $columns] -1]} {incr i} {
    set value [string trim [string range $str [lindex $columns $i] [expr [lindex $columns [expr $i +1]] -1] ] ]
    lappend row $value
# puts "<[lindex $columns $i] -> [expr [lindex $columns [expr $i +1]] -1]><$value>"
  }
  set value [string trim [string range $str [lindex $columns end] end] ]
  lappend row $value
# puts "<columns:$columns><$row>"
  return $row
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::report_failfast::extractTableValue
#------------------------------------------------------------------------
# Extract a value from an extracted table. The value is identified with
# a row/column pair
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::report_failfast::extractTableValue {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  variable params
  # -nth: if the row appear several times inside the table, then get value from nth row
  array set defaults [list \
      -rpt {} \
      -default {n/a} \
      -search {.*} \
      -row {} \
      -nth 0 \
      -column {} \
      -trim {} \
      -num_tables 1 \
      -debug 0 \
      -inline 1 \
      -error_if_not_found 0 \
    ]
  array set options [array get defaults]
  array set options $args

  if {($options(-row) == {}) || ($options(-column) == {})} {
    puts " -E- No row/column specified"
    return {}
  }

  set tables [extractTables $options(-rpt) $options(-num_tables) $options(-search) $options(-debug) $options(-inline) ]
  # Default value
  set value $options(-default)
  set header {}
  set row {}
  set matchrow {}
  set found 0
  set foundValues [list]
  foreach tbl $tables {
    set header [subst $${tbl}::header]
    set rows [subst $${tbl}::table]
    set idx [lsearch -regexp -nocase $header $options(-column)]
    if {$idx == -1} {
      continue
    }
    foreach row $rows {
      foreach el $options(-row) {
        if {[regexp $el [lindex $row 0] ]} {
#           set value [lindex $row $idx]
          lappend foundValues [lindex $row $idx]
          set matchrow $row
          set found 1
        }
#         if {$found} { break }
      }
#       if {$found} { break }
    }
#     if {$found} { break }
  }
  # Delete tables
  foreach tbl $tables {
    catch {$tbl destroy}
  }
  if {$found} {
    if {$options(-nth) > [expr [llength $foundValues] -1]} {
      set value [lindex $foundValues end]
    } else {
      set value [lindex $foundValues $options(-nth)]
    }
  }
  switch $options(-trim) {
    float {
      regexp {([-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?)} $value - value
    }
    int {
      regexp {([-+]?[0-9]+)} $value - value
    }
    default {
    }
  }
  if {$options(-debug) && $found && ($params(debug_level) >= 2)} {
    # In debug mode, print an abstract of the table showing only the row
    # uses to extract the data.
    # For example:
    #   +-------------------+------+-------+-----------+-------+
    #   | Site Type         | Used | Fixed | Available | Util% |
    #   +-------------------+------+-------+-----------+-------+
    #   | Register as Latch | 241  | 0     | 5065920   | <0.01 |
    #   +-------------------+------+-------+-----------+-------+
    set tbl [::tclapp::xilinx::designutils::prettyTable create]
    $tbl header $header
    $tbl addrow $matchrow
    puts [$tbl print]
    catch {$tbl destroy}
  }
  if {!$found && $options(-error_if_not_found)} {
    return -code error $value
  }
  return $value
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::report_failfast::extractTables
#------------------------------------------------------------------------
# Extract table(s) from a report. Each table includes the header and
# rows content
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::report_failfast::extractTables {report {maxnumtables -1} {patterns {}} {debug 0} {inline 0}} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  variable params

  set report [split $report \n]
  set columns [list]
  set table [list]
  set tables [list]
  set pattern {.+}
  if {$patterns == {}} {
    set SM {search_table}
  } else {
    set pattern [lshift patterns]
    set SM {search_pattern}
  }
  set numtables 0
  set indextable -1
  set print 1
  for {set index 0} {$index < [llength $report]} {incr index} {
    set line [lindex $report $index]
    set print 1
    switch $SM {
      search_pattern {
        if {[regexp -nocase -- $pattern $line]} {
          if {$patterns != {}} {
            # Pattern found, now search for the next pattern
            set pattern [lshift patterns]
          } else {
            # Last pattern found, now search for the table
            set SM {search_table}
          }
        }
      }
      search_table {
        if {[regexp {^\s*\+--*\+--*\+} $line]
             && [regexp {^\s*\|.+\|.+\|} [lindex $report [expr $index +1]]]
             && [regexp {^\s*\+--*\+--*\+} [lindex $report [expr $index +2]]]
             && [regexp {^\s*\|.+\|.+\|} [lindex $report [expr $index +3]]]
             && [regexp {^\s*\+--*\+--*\+} [lindex $report [expr $index +4]]]} {
          # Get the list of columns for the 2 lines
          set col1 [extract_columns2 [string trimright $line] {-}]
          set col2 [extract_columns2 [string trimright [lindex $report [expr $index +2]]] {-}]
          # Are the list the same?
          if {$col1 == $col2} {
            # E.g: (report_pipeline_analysis)
            # +----------------------------+---------------+------------------+------------------+------------------+-----------+----------------+----------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------+-------------------------------------------------------------------------------------------------------------------------+
            # | Clock                      | Added Latency | Ideal Fmax (MHz) | Ideal Delay (ns) | Requirement (ns) | WNS (ns)* | Added Pipe Reg | Total Pipe Reg | Pipeline Insertion Startpoint                                                                                                                                         | Pipeline Insertion Endpoint                                                                                             |
            # +----------------------------+---------------+------------------+------------------+------------------+-----------+----------------+----------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------+-------------------------------------------------------------------------------------------------------------------------+
            # | clk_153m6_out_cpri_ref_pll |       0       |      153.58      |       6.511      |       6.500      |   -0.011  |       n/a      |        0       | bb200_top_i/reiska_top/receive_top_0/U0/inst_data_channel_rx_top/inst_equ_coeff_est/inst_rs1808/rs226.inst_rs/inst/axisc_register_slice_0/m_axis_tdata[1139]_INST_0/O | bb200_top_i/reiska_top/receive_top_0/U0/inst_data_channel_rx_top/inst_equ_coeff_est/inst_mift/tmp_25_reg_12573_reg[8]/D |
            # +----------------------------+---------------+------------------+------------------+------------------+-----------+----------------+----------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------+-------------------------------------------------------------------------------------------------------------------------+
            # This match the 'classic' format from prettyTable
            set SM {header_classic}
            # Removing column separator
            regsub -all {\+} $line { } line
            set columns [extract_columns2 [string trimright $line] {-}]
            set print 0
            # Save the line starting the table
            set indextable $index
          } else {
            # E.g: (report_clock_utlization)
            # +-------------------+----------------------+----------------------+----------------------+----------------------+
            # |                   |        HROUTES       |        HDISTRS       |        VROUTES       |        VDISTRS       |
            # +-------------------+------+-------+-------+------+-------+-------+------+-------+-------+------+-------+-------+
            # | Clock Region Name | Used | Avail | Util% | Used | Avail | Util% | Used | Avail | Util% | Used | Avail | Util% |
            # +-------------------+------+-------+-------+------+-------+-------+------+-------+-------+------+-------+-------+
            # Do nothing when top header is found and wait for next header line
            # to be found
          }
        } elseif {[regexp {^\s*--*\+--*\+} $line]
             && [regexp {^\s*[^\|]+\|.+\|} [lindex $report [expr $index +1]]]
             && [regexp {^\s*[^\|]+\|.+\|} [lindex $report [expr $index +2]]]
             && [regexp {^\s*--*\+--*\+} [lindex $report [expr $index +3]]] } {
          # E.g: (report_datasheet)
          # -------------------+-------------+---------+-------------+---------+----------+
          #                    |     Max     | Process |     Min     | Process | Edge     |
          # Pad                |   Delay(ns) | Corner  |   Delay(ns) | Corner  | Skew(ns) |
          # -------------------+-------------+---------+-------------+---------+----------+
          # This match the 'classic' format from prettyTable
          set SM {header_classic}
          # Removing column separator
          regsub -all {\+} $line { } line
          set columns [extract_columns2 [string trimright $line] {-}]
          set print 0
          # Save the line starting the table
          set indextable $index
        } elseif {[regexp {^\s*\+--*\+--*\+} $line]
             && [regexp {^\s*\|.+\|.+\|} [lindex $report [expr $index +1]]]
             && [regexp {^\s*\+--*\+--*\+} [lindex $report [expr $index +2]]] } {
          # E.g:
          # +------------+------+-----------+-----+--------------+--------+
          # | Type       | Used | Available | LOC | Clock Region | Pblock |
          # +------------+------+-----------+-----+--------------+--------+
          # This match the 'classic' format for prettyTable
          set SM {header_classic}
          # Removing column separator
          regsub -all {\+} $line { } line
          set columns [extract_columns2 [string trimright $line] {-}]
          set print 0
          # Save the line starting the table
          set indextable $index
        } elseif {[regexp {^\-+\s+\-+\s+\-+} $line]} {
          # E.g:
          # WNS(ns)  TNS(ns)  TNS Failing Endpoints
          # -------  -------  ---------------------
          # This match the 'lean' format from prettyTable
          set SM {table_lean}
          set columns [extract_columns2 [string trimright $line] {-}]
          set header [extract_row2 [lindex $report [expr $index -1]] $columns]
          set table [list $header ]
          set print 0
          # Save the line starting the table
          set indextable $index
        }
      }
      header_classic {
        if {[regexp {^\s*[^\|]+\|.+\|} $line]
             && [regexp {^\s*[^\|]+\|.+\|} [lindex $report [expr $index +1]]]
             && [regexp {^\s*--*\+--*\+} [lindex $report [expr $index +2]]]} {
          # Multi-lines header with no separator on first column
          # E.g: (report_datasheet)
          # -------------------+-------------+---------+-------------+---------+----------+
          #                    |     Max     | Process |     Min     | Process | Edge     |
          # Pad                |   Delay(ns) | Corner  |   Delay(ns) | Corner  | Skew(ns) |
          # -------------------+-------------+---------+-------------+---------+----------+
          # Removing column separator
          regsub -all {\|} $line { } line1
          regsub -all {\|} [lindex $report [expr $index +1]] { } line2
          set header1 [extract_row2 $line1 $columns]
          set header2 [extract_row2 $line2 $columns]
          set header [list]
          foreach h1 $header1 h2 $header2 {
            lappend header [string trim [format {%s %s} [string trim [format {%s} $h1]] [string trim [format {%s} $h2]]] ]
          }
          lappend table $header
          set SM {table_classic}
          set print 0
          # Skip the next line which is the second header line since
          # it just got included inside the header
          incr index
        } elseif {[regexp {^\s*\|.+\|.+\|} $line]} {
          # E.g: (report_clock_utlization)
          # +------------+------+-----------+-----+--------------+--------+
          # | Type       | Used | Available | LOC | Clock Region | Pblock |
          # +------------+------+-----------+-----+--------------+--------+
          # Removing column separator
          regsub -all {\|} $line { } line
          set header [extract_row2 $line $columns]
          set table [list $header ]
          set SM {table_classic}
          set print 0
        }
      }
      table_classic {
        if {[regexp {^\s*\|.+\|.+\|} $line]} {
          # E.g: (report_clock_utlization)
          # | BUFGCE     |   13 |       576 |   0 |            0 |      0 |
          # | BUFGCE_DIV |    0 |        96 |   0 |            0 |      0 |
          # Removing column separator
          regsub -all {\|} $line { } line
          set row [extract_row2 $line $columns]
          lappend table $row
          set print 0
        } elseif {[regexp {^\s*[^\|]+\|.+\|} $line]} {
          # E.g: (report_datasheet with no separator on first column)
          # led_bus[0]         |   7.491 (r) | SLOW    |   2.938 (r) | FAST    |    0.053 |
          # led_bus[1]         |   7.438 (r) | SLOW    |   2.942 (r) | FAST    |    0.004 |
          # Removing column separator
          regsub -all {\|} $line { } line
          set row [extract_row2 $line $columns]
          lappend table $row
          set print 0
        } elseif {[regexp {^\s*\+--*\+--*\+} $line]
                   && ![regexp {^\s*\|.+\|.+\|} [lindex $report [expr $index +1]]]} {
          # E.g: (report_clock_utlization)
          # | PLL        |    3 |        48 |   0 |            0 |      0 |
          # +------------+------+-----------+-----+--------------+--------+
          # The current line is a row separator and the next line does not
          # match a table row
          set SM {end_table}
        } elseif {[regexp {^\s*--*\+--*\+} $line]
                   && ![regexp {^\s*[^\|]+\|.+\|} [lindex $report [expr $index +1]]]} {
          # E.g: (report_datasheet with no separator on first column)
          # Worst Case Summary |   7.632 (r) | SLOW    |   2.938 (r) | FAST    |    0.195 |
          # -------------------+-------------+---------+-------------+---------+----------+
          # The current line is a row separator and the next line does not
          # match a table row
          set SM {end_table}
        }
      }
      table_lean {
        # E.g:
        #        -0.261       -0.261         1
        # Check for empty line or for line that match '<empty>'
        if {(![regexp {^\s*$} $line]) && (![regexp -nocase {^\s*No clocks found.\s*$} $line])} {
          set row [extract_row2 $line $columns]
          lappend table $row
          set print 0
        } elseif {[regexp {^\s*$} $line]} {
          set SM {end_table}
        }
      }
      end_table {
        incr numtables
        if {$debug && ($params(debug_level) >= 3)} {
          puts ""
          puts "#####################################"
          puts "# Table $numtables (line [expr $indextable +1])"
          puts "#####################################"
        }
        set tbl [::tclapp::xilinx::designutils::prettyTable create]
        $tbl header [lindex $table 0]
        foreach row [lrange $table 1 end] {
          $tbl addrow $row
        }
        if {$debug && ($params(debug_level) >= 3)} {
          puts [$tbl print]
        }
        # Save the current table and create new one
        lappend tables $tbl
#         # Delete table
#         catch {$tbl destroy}
        set table [list]
        set columns [list]
        if {$maxnumtables != -1} {
          if {$numtables >= $maxnumtables} {
            set SM {end}
          } else {
            set SM {search_table}
          }
        } else {
          set SM {search_table}
        }
        # Reset variable
        set indextable -1
      }
      end {
      }
    }
    if {$print && $debug && $inline && ($params(debug_level) >= 4)} {
      puts [format {# %s} $line]
    }
  }

  return $tables
}

# namespace import -force ::tclapp::xilinx::designutils::report_failfast::report_failfast
