package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export report_failfast
}

########################################################################################
## 2023.09.14 - Fixed issue with average fanout
##            - Runtime optimization for average fanout calculation
##            - Added metric "Max Average Fanout for modules > 100k cells"
## 2023.07.26 - Improved support for non-standard Vivado version numbers
## 2021.06.22 - Updated LUT/Net budgeting to add penalty for sequential loops (Versal)
##            - Updated column "Cascaded LUTs" to LUT/Net budgeting detailed tables (Versal)
## 2021.05.07 - Added CSV files for LUT/Net budgeting detailed reports
##            - Added column "Cascaded LUTs" to LUT/Net budgeting detailed tables (Versal)
##            - Added support for -return_paths
##            - Fixed misc issues
## 2021.02.05 - Added support for local clock nets to non-FD HFN
## 2021.02.02 - Fixed URAM utilization inside CSV
## 2021.01.06 - Added DONT_TOUCH/MARK_DEBUG/Slack/Load Pins columns inside the non-FD HFN table
##            - Added new detailed report for the used BUFGCE* (<prefix>.BUFG.rpt)
##            - Misc improvements
## 2020.12.07 - Fixed issue with some non-FD HFN that were not reported
##            - Added ordering of the non-FD HFN table (high to low)
## 2020.09.29 - Added support for custom metrics (-custom_metrics/-only_custom_metrics,
##              -no_custom_metrics,FAILFAST_CUSTOM_METRICS)
##            - Added support for -only_fails to only show failing metrics
## 2020.09.09 - Suppressed details from the nets summary tables for DONT_TOUCH/MARK_DEBUG
##              when there are too many nets
## 2020.08.28 - Added support for metrics LUT4/5/6 and LUT5/6
##              Disabled by default. Enabled through config file
##            - Added support for top-level rent metric (report_design_analysis)
##              Disabled by default. Enabled through config file
##            - Added support for -rent/-no_rent/-rda
##            - Added support for environment variable FAILFAST_CONFIG to point to a config file
## 2020.08.17 - Improved support for multiple Vivado patches applied at the same time
## 2020.07.31 - Improved support for multiple Vivado patches applied at the same time
## 2020.07.12 - Improved support for special Vivado branches
## 2020.06.29 - Improved handling when the architecture is not supported (LUT/Net budgeting)
##            - Silenced some get_nets warning when no object is found
## 2020.06.09 - Added support for MARK_DEBUG metric
##            - Added support for -hide_slacks for the DONT_TOUCH/MARK_DEBUG detailed reports
##            - Improved the DONT_TOUCH detailed report to include the net fanout, setup slack
##              and driver/load pins. Duplicated nets are filtered out
##            - Filtered out the power/ground from the list of DONT_TOUCH nets
## 2020.05.27 - Fixed major issue with average fanout calculation (incorrect value could be reported)
##            - Improved debug messages for average fanout calculation
##            - Updated help (-no_utilization)
## 2020.04.09 - Fixed uncommon issue with average fanout calculation that failed
##              restoring the current_instance
## 2020.04.06 - Minor formatting "RAMB/FIFO" -> "RAMB" (Versal)
## 2020.03.06 - Added support for LOOKAHEAD8 (Versal)
## 2020.03.05 - Fixed DSP utilization (report_utilization / Versal)
##            - Replaced "DSP48" with "DSP" inside the report
##            - Added debug messages
## 2019.08.23 - Added the LUT/Net Adjusted Slack (LUT/Net budgeting)
##            - Fixed issue with paths starting and ending on the same cell
## 2019.08.12 - Updated the LUT/Net budgeting calculation to improve pre-place
##              and post-place correlation to better estimate intra-site nets (Versal)
## 2019.08.08 - Updated the LUT/Net budgeting table header names for clarity
##            - Improved pre-placement level calculation for LUT/Net budgeting (Versal)
## 2019.08.06 - Adjusted Net/Delay values + fixed speedgrade names (Versal)
##            - Adjusted Net/Delay values for -1LV/-2LV (US+)
##            - Improved support for LUTCY* during LUT/Net budgeting (Versal)
##            - Removed LUTCY* from LUT Combinining metric (Versal)
## 2019.07.30 - Improved runtime for -by_slr by running report_utilization
##              only once (Vivado 2019.1 and above)
##            - Added support for updated format for report_control_sets
##            - Added support for Versal (report_utilization)
##            - Added initial support for Versal (LUT/Net budgeting)
##            - Misc enhancements
## 2019.02.13 - Added support for Vivado patches
## 2019.01.10 - Added support for US+ -1LV/-2LV
## 2018.11.16 - Added support for spartan7, zynquplusRFSOC, virtexuplus58g
##              and virtexuplusHBM
## 2018.05.11 - Fixed check for empty name for -cell/-pblock/-slr
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
#      | DSP                                                       | 80%       | 40.02% | OK     |
#      | RAMB/FIFO                                                 | 80%       | 62.50% | OK     |
#      | URAM                                                      | 80%       | 50.00% | OK     |
#      | DSP+RAMB+URAM (Avg)                                       | 70%       | 41.09% | OK     |
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
#      | DSP                                                       | 80%       | 39.04%  | 253    | 648    | OK     |
#      | RAMB/FIFO                                                 | 80%       | 13.19%  | 28.5   | 216    | OK     |
#      | DSP+RAMB+URAM (Avg)                                       | 70%       | 26.11%  | 281.5  | 864    | OK     |
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

# User custom metrics
# ===================
# 1) Specify the file that includes the custom metrics with -custom_metrics <filename>
#    To skip custom metrics, use -no_custom_metrics
#    To only report custom metrics, use -only_custom_metrics
# 2) Example of custom metric file
#    addMetric custom.<metricName> <description> <guideline>
#    setMetric custom.<metricName> <value> [<availableResources>]
#    -- For example --
#    addMetric custom.mymetric1 {Description for mymetric1} {<=50%}
#    setMetric custom.mymetric1 60 123
#    addMetric custom.mymetric2 {Description for mymetric2} {>=60%}
#    setMetric custom.mymetric2 60
# 3) Example of report with custom metrics (-only_custom_metrics)
#    +------------------------------------------------------------------------+
#    | Design Summary                                                         |
#    | checkpoint_post_synth                                                  |
#    | xc7k70tfbg484-3                                                        |
#    +---------------------------+-----------+--------+------+-------+--------+
#    | Criteria                  | Guideline | Actual | Used | Avail | Status |
#    +---------------------------+-----------+--------+------+-------+--------+
#    | Description for mymetric1 | 50%       | 60%    | 60   | 123   | REVIEW |
#    | Description for mymetric2 | 60%       | 60%    | 60   | -     | OK     |
#    +---------------------------+-----------+--------+------+-------+--------+


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
  # [-no_utilization]: Skip utilization checks
  # [-no_methodology_checks]: Skip methodology checks
  # [-no_path_budgeting]: Skip LUT/Net budgeting
  # [-no_fanout]: Skip average fanout calculation
  # [-no_dont_touch]: Skip DONT_TOUCH check
  # [-no_mark_debug]: Skip MARK_DEBUG check
  # [-no_hfn]: Skip Non-FD high fanout nets metric
  # [-no_control_sets]: Skip control sets metric
  # [-rent]: Force rent metric (when not enabled inside the config file)
  # [-no_rent]: Skip rent metric (when enabled inside the config file)
  # [-max_paths <arg>]: max number of paths per clock group for LUT/Net budgeting. Default is 100
  # [-post_ooc_synth]: Post OOC Synthesis - only run LUT/Net budgeting
  # [-ignore_pr]: Disable auto-detection of Partial Reconfigurable designs
  # [-show_resources]: Show Used/Available resources count in the summary table
  # [-show_not_found]: Show metrics that could not be extracted
  # [-show_all_paths]: Show all paths analyzed by LUT/Net budgeting
  # [-hide_slacks]: Hide the setup slack of the nets inside the DONT_TOUCH/MARK_DEBUG detailed reports
  # [-return_paths <arg>]: Return timing paths. Valid values: none|path_budgeting|lut_pair_missed|lut_pair_found|lut_pair_candidate
  # [-custom_metrics <arg>]: Optional user custom metrics file(s)
  # [-no_custom_metrics]: Skip user custom metrics
  # [-only_custom_metrics]: Only report user custom metrics
  # [-only_fails]: Only report failing metrics
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
  variable version {2023.09.14}
  variable script [info script]
  variable SUITE_INTEGRATION 0
  variable params
  variable output {}
  variable metrics
  variable reports
  variable guidelines
  variable data
  variable dbgtbl
  array set params [list failed 0 format {table} max_paths 100 max_dont_touch 2000 max_mark_debug 2000 show_resources 0 show_fail_only 0 transpose 0 verbose 0 debug 0 debug_level 1 vivado_version [version -short] ]
  array set params [list return_paths {none} paths [list] ]
  # Versal-specific params
  array set params [list lutPairCASCMissed 0 lutPairCASCCandidate 0 lutPairCASCMissedPaths [list] lutPairCASCFoundPaths [list] lutPairCASCPaths [list] ]
#   catch { unset reports }
  array set reports [list]
  catch { unset metrics }
  array set metrics [list]
  catch { unset data }
  catch { unset guidelines }
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
  variable reports
  variable metrics
  variable params
  variable dbgtbl
  variable guidelines
  variable output
  variable data
  catch { unset guidelines }
  catch { unset metrics }
  array set metrics [list]
#   catch { unset reports }
#   array set reports [list]
  set params(failed) 0
  set params(verbose) 0
  set params(debug) 0
  set params(debug_level) 1
  set params(format) {table}
  set params(transpose) 0
  set params(show_resources) 0
  set params(show_fail_only) 0
  set params(max_paths) 100
  set params(max_dont_touch) 2000
  set params(max_mark_debug) 2000
  set params(return_paths) {none}
  set params(paths) [list]
#   set params(vivado_version) [version -short]
  # Remove from the Vivado version any letter that would fail 'package vcompare' + remove reference to
  # any patched version (_ARxxxxx) or special branches (2020.2_SAM)
  # Other alternatives seen in the field: v2020.1_(AR75369_AR75386)
#   set params(vivado_version) [regsub -all {[a-zA-Z]} [regsub {_AR[0-9]+$} [version -short] {}] {0}]
#   set params(vivado_version) [regsub -all {[a-zA-Z]} [regsub {_[A-Za-z]+$} [regsub -all {(_AR[0-9]+)} [version -short] {}] {}] {0}]
#   set params(vivado_version) [regsub -all {[a-zA-Z]} [regsub {_[A-Za-z]+$} [regsub -all {([_\(\)]*AR[0-9\(\)]+)} [version -short] {}] {}] {0}]
  set params(vivado_version) [regsub -all {[a-zA-Z]} [regsub {_[A-Za-z]+$} [regsub -all {([_\(\)]*[a-zA-Z]+[0-9\(\)]+)} [version -short] {}] {}] {0}]
  # Versal
  set params(lutPairCASCMissed) 0
  set params(lutPairCASCCandidate) 0
  set params(lutPairCASCMissedPaths) [list]
  set params(lutPairCASCFoundPaths) [list]
  set params(lutPairCASCPaths) [list]

  set pid {tmp}
  catch { set pid [pid] }
  set filename {}
  set filemode {w}
  set detailedReportsPrefix {}
  set detailedReportsDir [file normalize .] ; # Current directory
  set userConfigFilename {}
  set userCustomMetricsFiles [list]
  set time [clock seconds]
  set date [clock format $time]
  # -top/-cell/-pblock/-region/-slr
  set optionTop 0
  set optionCell 0
  set optionPblock 0
  set optionRegion 0
  set optionSlr 0
  set optionRent 0
  # For Partial Reconfigurable designs: both the cell and pblock must be specified
  set prDetect 1
  set prCell {}
  set prPblock {}
  set excludeCell {}
  set leafCells [list]
  set slrs {}
  set slrPblock {}
  # extractUtilizationFromSLRTable: 2019.1 and above, set variable to 1 to leverage the
  # table "SLR CLB Logic and Dedicated Block Utilization" from report_utilization when
  # reporting the utilization per SLR
  # $extractUtilizationFromSLRTable should only be set to 1 when -by_slr has been specified
  set extractUtilizationFromSLRTable 0
  set reportUtilizationFile {}
  set reportControlSetsFile {}
  set reportDesignAnalysisFile {}
  set reportBySLR 0
# dpefour
set reportBySLRNew 0
  # List of clock regions (-region)
  set regions {}
  # Pblock created for the clock regions (-region)
  set regionPblock {}
  set skipChecks [list]
  # Default: remove the cached reports
  set resetReports 1
  set hideUnextractedMetrics 1
  # Report mode
  set reportMode {default}
  # Timing paths to be considered for LUT/Net budgeting
  set timingPathsBudgeting [list]
  set showAllBudgetingPaths 0
  set showSlackInsideDetailedReports 1
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
      {^-file$} -
      {^-f(i(le?)?)?$} {
        set filename [lshift args]
        # The detailed reports should be saved inside the same directory as the output report
        set detailedReportsDir [file dirname [file normalize $filename]]
      }
      {^-append$} -
      {^-ap(p(e(nd?)?)?)?$} {
        set filemode {a}
      }
      {^-detailed_reports$} -
      {^-de(t(a(i(l(e(d(_(r(e(p(o(r(ts?)?)?)?)?)?)?)?)?)?)?)?)?)?$} {
        set detailedReportsPrefix [lshift args]
      }
      {^-config_file$} -
      {^-co(n(f(i(g(_(f(i(le?)?)?)?)?)?)?)?)?$} {
        set userConfigFilename [lshift args]
      }
      {^-custom_metrics$} -
      {^-cus(t(o(m(_(m(e(t(r(i(cs?)?)?)?)?)?)?)?)?)?)?$} {
        set files [lshift args]
        if {[file exists $files]} {
          # Single file
          lappend userCustomMetricsFiles $files
        } else {
          # List of files
          foreach file $files {
            if {![file exists $file]} {
              puts " -E- custom metric file '$file' does not exist"
              incr error
            } else {
              lappend userCustomMetricsFiles $file
            }
          }
        }
      }
      {^-export_config$} -
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
      {^-ignore_pr$} -
      {^-ig(n(o(r(e(_(pr?)?)?)?)?)?)?$} {
        # Do not try to auto detect PR designs
        set prDetect 0
      }
      {^-no_methodology_checks$} -
      {^-no_m(e(t(h(o(d(o(l(o(g(y(_(c(h(e(c(ks?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?$} {
        lappend skipChecks {methodology_check}
      }
      {^-no_path_budgeting$} -
      {^-no_pa(t(h(_(b(u(d(g(e(t(i(ng?)?)?)?)?)?)?)?)?)?)?)?$} {
        lappend skipChecks {path_budgeting}
      }
      {^-no_fanout$} -
      {^-no_fa(n(o(ut?)?)?)?$} {
        lappend skipChecks {average_fanout}
      }
      {^-no_dont_touch$} -
      {^-no_do(n(t(_(t(o(u(ch?)?)?)?)?)?)?)?$} {
        lappend skipChecks {dont_touch}
      }
      {^-no_mark_debug$} -
      {^-no_ma(r(k(_(d(e(b(ug?)?)?)?)?)?)?)?$} {
        lappend skipChecks {mark_debug}
      }
      {^-no_hfn$} -
      {^-no_fd_hfn$} -
      {^-no_h(fn?)?$} -
      {^-no_fd(_(h(fn?)?)?)?$} {
        lappend skipChecks {non_fd_hfn}
      }
      {^-no_control_sets$} -
      {^-no_co(n(t(r(o(l(_(s(e(ts?)?)?)?)?)?)?)?)?)?$} {
        lappend skipChecks {control_sets}
      }
      {^-no_utilization$} -
      {^-no_u(t(i(l(i(z(a(t(i(on?)?)?)?)?)?)?)?)?)?$} {
        # Hidden command line option
        lappend skipChecks {utilization}
      }
      {^-no_rent$} -
      {^-no_r(e(nt?)?)?$} {
        lappend skipChecks {rent}
      }
      {^-no_custom_metrics$} -
      {^-no_cu(s(t(o(m(_(m(e(t(r(i(cs?)?)?)?)?)?)?)?)?)?)?)?$} {
        lappend skipChecks {custom_metrics}
      }
      {^-only_custom_metrics$} -
      {^-only_cu(s(t(o(m(_(m(e(t(r(i(cs?)?)?)?)?)?)?)?)?)?)?)?$} {
        set skipChecks [concat $skipChecks {utilization path_budgeting dont_touch mark_debug control_sets non_fd_hfn average_fanout methodology_check rent}]
      }
      {^-only_fails$} -
      {^-only_f(a(i(ls?)?)?)?$} -
      {^-show_only_fails$} -
      {^-show_o(n(l(y(_(f(a(i(ls?)?)?)?)?)?)?)?)?$} {
        set params(show_fail_only) 1
      }
      {^-rent$} -
      {^-re(nt?)?$} {
        # Force the rent metric if not included in the config file
        set optionRent 1
      }
      {^-post_ooc_synth$} -
      {^-path_budgeting_only$} -
      {^-po(s(t(_(o(o(c(_(s(y(n(th?)?)?)?)?)?)?)?)?)?)?)?$} -
      {^-pa(t(h(_(b(u(d(g(e(t(i(n(g(_(o(n(ly?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?$} {
        set skipChecks [concat $skipChecks {utilization dont_touch mark_debug control_sets non_fd_hfn average_fanout methodology_check rent}]
      }
      {^-cell$} -
      {^-ce(ll?)?$} {
        set prCell [lshift args]
        set optionCell 1
      }
      {^-exclude_cell$} -
      {^-ex(c(l(u(d(e(_(c(e(ll?)?)?)?)?)?)?)?)?)?$} {
        set excludeCell [lshift args]
      }
      {^-top?$} {
        set optionTop 1
      }
      {^-by_slr$} {
        set reportBySLR 1
      }
{^-by_slr_new$} {
  set reportBySLR 1
  set reportBySLRNew 1
}
{^--keep_reports$} -
{^--keep_r(e(p(o(r(ts?)?)?)?)?)?$} -
{^--keep-reports$} -
{^--keep-r(e(p(o(r(ts?)?)?)?)?)?$} {
  set resetReports 0
}
{^--use_slr_table$} -
{^--use_s(l(r(_(t(a(b(le?)?)?)?)?)?)?)?$} -
{^--use_util_slr_table$} -
{^--use_u(t(i(l(_(s(l(r(_(t(a(b(le?)?)?)?)?)?)?)?)?)?)?)?)?$} {
# dpefour
  if {[package vcompare $params(vivado_version) 2019.1.0] >= 0} {
    # Only for Vivado 2019.1 and above
    set extractUtilizationFromSLRTable 1
  } else {
    puts " -W- option --use_util_slr_table is not compatible with Vivado $params(vivado_version) (2019.1 and below)"
    set extractUtilizationFromSLRTable 0
  }
}
      {^-slrs?$} {
        set slrs [lshift args]
        set optionSlr 1
      }
      {^-pblock$} -
      {^-pb(l(o(ck?)?)?)?$} {
        set prPblock [lshift args]
        set optionPblock 1
      }
      {^-regions$} -
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
      {^-show_not_found$} -
      {^-show_n(o(t(_(f(o(u(nd?)?)?)?)?)?)?)?$} {
        set hideUnextractedMetrics 0
      }
      {^-show_resources$} -
      {^-show_r(e(s(o(u(r(c(es?)?)?)?)?)?)?)?$} {
        set params(show_resources) 1
      }
      {^-show_all_paths$} -
      {^-show_a(l(l(_(p(a(t(hs?)?)?)?)?)?)?)?$} {
        set showAllBudgetingPaths 1
      }
      {^-hide_slacks$} -
      {^-hi(d(e(_(s(l(a(c(ks?)?)?)?)?)?)?)?)?$} {
        set showSlackInsideDetailedReports 0
      }
      {^-max_paths$} -
      {^-ma(x(_(p(a(t(hs?)?)?)?)?)?)?$} {
        set params(max_paths) [lshift args]
      }
      {^-c(sv?)?$} -
      {^-csv$} {
        set params(format) {csv}
      }
      {^-transpose$} -
      {^-tr(a(n(s(p(o(se?)?)?)?)?)?)?$} {
        set params(transpose) 1
      }
      {^-no_header$} -
      {^-no_h(e(a(d(er?)?)?)?)?$} {
        set showFileHeader 0
      }
      {^--ru$} -
      {^--report_utilization$} {
        set reportUtilizationFile [lshift args]
      }
      {^--rcs$} -
      {^--report_control_sets$} {
        set reportControlSetsFile [lshift args]
      }
      {^--rda$} -
      {^--report_design_analysis$} {
        set reportDesignAnalysisFile [lshift args]
      }
      {^-verbose$} -
      {^-v(e(r(b(o(se?)?)?)?)?)?$} {
        set params(verbose) 1
      }
      {^-return_paths$} -
      {^-ret(u(r(n(_(p(a(t(hs?)?)?)?)?)?)?)?)?$} {
        set params(return_paths) [lshift args]
      }
      {^-debug$} -
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
      {^--debug-max-dont-touch?$} -
      {^--debug-max-d(o(n(t(-(t(o(u(ch?)?)?)?)?)?)?)?)?$} -
      {^--max-dont-touch?$} -
      {^--max-d(o(n(t(-(t(o(u(ch?)?)?)?)?)?)?)?)?$} {
        set params(max_dont_touch) [lshift args]
      }
      {^--debug-max-mark-debug?$} -
      {^--debug-max-m(a(r(k(-(d(e(b(ug?)?)?)?)?)?)?)?)?$} -
      {^--max-mark-debug?$} -
      {^--max-m(a(r(k(-(d(e(b(ug?)?)?)?)?)?)?)?)?$} {
        set params(max_mark_debug) [lshift args]
      }
      {^-help$} -
      {^-h(e(lp?)?)?$} {
        set help 1
      }
      {^-longhelp$} -
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
              [-custom_metrics <filename>]
              [-cell <cell>][-top]
              [-pblock <pblock>]
              [-slr <slr>][-by_slr]
              [-regions <pattern>]
              [-no_utilization]
              [-no_methodology_checks]
              [-no_path_budgeting]
              [-no_hfn]
              [-no_fanout]
              [-no_dont_touch]
              [-no_mark_debug]
              [-no_control_sets]
              [-rent][-no_rent]
              [-post_ooc_synth]
              [-ignore_pr]
              [-exclude_cell <cell>]
              [-max_paths <num>]
              [-show_resources]
              [-show_not_found]
              [-show_all_paths]
              [-hide_slacks]
              [-only_fails]
              [-csv][-transpose]
              [-return_paths <enum>]
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
    Use -no_mark_debug to prevent calculation of MARK_DEBUG metric
    Use -no_control_sets to prevent extraction of control sets metric
    Use -rent to force the extraction of rent metric (when not enabled in config file)
      Rent is extracted through report_timing_summary and can require very long runtime
    Use -no_rent to prevent extraction of rent metric (when enabled in config file)
    Use -ignore_pr to prevent auto detection of Partial Reconfigurable designs and always runs the analysis from top-level
    Use -show_resources to report the detailed number of used and available resources in the summary table
    Use -show_not_found to report metrics that have not been extracted (hidden by default)
    Use -show_all_paths to report all the paths analyzed in the LUT/Net budgeting. Default it to only report paths with budgeting violation
    Use -hide_slacks to reduce runtime and not report the setup slack of the nets inside the DONT_TOUCH/MARK_DEBUG/HFN detailed reports
    Use -post_ooc_synth to only run the LUT/Net path budgeting
    Use -exclude_cell to exclude a hierarchical module from consideration. Only utilization metrics are reported
    Use -max_paths to define the max number of paths per clock group for LUT/Net budgeting. Default is 100
    Use -no_header to suppress the files header
    Use -only_fails to only report metrics that are failing and that need to be reviewed
    Use -custom_metrics/-no_custom_metrics/-only_custom_metrics to control user custom metrics
    Use -return_paths to return timing paths:
      none: no timing path is return (default)
      path_budgeting: return the paths that have net/lut budgeting violations
      lut_pair_missed: return the paths that missed at least one lut-pair placement (Versal)
      lut_pair_found: return the paths that have at least one lut-pair placement (Versal)
      lut_pair_candidate: return the paths that are candidate for one or more lut-pair placement (Versal)

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
     ::xilinx::designutils::report_failfast -file failfast.rpt -post_ooc_synth -show_all_paths
} $version ]
    # HELP -->

#     if {$show_long_help} { print_help }

    return -code ok
  }

  if {$show_long_help} {
    print_help
    return -code ok
  }

  switch $params(return_paths) {
    path_budgeting -
    lut_pair_missed -
    lut_pair_found -
    lut_pair_candidate -
    none {
    }
    default {
      puts " -E- -return_paths unknown value '$params(return_paths)'. The valid values are: none|path_budgeting|lut_pair_missed|lut_pair_found|lut_pair_candidate"
      incr error
    }
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

  if {$optionPblock} {
    if {$prPblock != {}} {
      set pblock [get_pblocks -quiet $prPblock]
      if {$pblock == {}} {
        puts " -E- Pblock '$prPblock' does not exists (-pblock)"
        incr error
      } else {
        set prPblock $pblock
      }
    } else {
      incr error
      puts " -E- empty Pblock (-pblock)"
      incr error
    }
  }

  if {$optionSlr} {
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
    } else {
      puts " -E- empty SLR (-slr)"
      incr error
    }
  }

  if {$optionCell} {
    if {$prCell != {}} {
      set cell [get_cells -quiet $prCell]
      if {$cell == {}} {
        puts " -E- cell '$prCell' does not exists (-cell)"
        incr error
      } else {
        set prCell $cell
      }
    } else {
      puts " -E- empty cell (-cell)"
      incr error
    }
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

# dpefour
  if {$reportBySLRNew} {
    # Remove -by_slr from original command line
    set cmd [lsearch -all -inline -not -exact $cmdLine {-by_slr}]
# dpefour
set cmd [lsearch -all -inline -not -exact $cmdLine {-by_slr_new}]
    set res 0
    set failures 0
    # Remove the cached reports
    catch { unset reports }
    array set reports [list]
    # Iterate through the SLRs
    foreach slr [get_slrs -quiet] {
      # Calling the command with the original (but modified) command line
      # Adding -append to make sure that all SLR data are being saved into the file
      if {[catch {
# dpefour
#         set res [tclapp::xilinx::designutils::report_failfast -append -slr $slr {*}$cmd]
        if {[package vcompare $params(vivado_version) 2019.1.0] >= 0} {
          # 2019.1 and above: the utilization by SLR is extracted from "SLR CLB Logic and Dedicated Block Utilization".
          set res [tclapp::xilinx::designutils::report_failfast --keep_reports --use_util_slr_table -append -slr $slr {*}$cmd]
        } else {
          set res [tclapp::xilinx::designutils::report_failfast -append -slr $slr {*}$cmd]
        }
#         set res [tclapp::xilinx::designutils::report_failfast -append -slr $slr {*}$cmd]
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

  if {$reportBySLR} {
    # Remove -by_slr from original command line
    set cmd [lsearch -all -inline -not -exact $cmdLine {-by_slr}]
    set res 0
    set failures 0
    # Remove the potentially saved reports
    catch { unset reports }
    array set reports [list]
    # Iterate through the SLRs
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
#       set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != MACRO)"]
      # Filter out DSP atoms to only keep the DSP macros: this fixes an issue with report_utilization
      set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != INTERNAL) && (LIB_CELL != GND) && (LIB_CELL != VCC)"]
    }
    {^.11..$} {
      set reportMode {pblockAndCell}
#       set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != MACRO) && NAME =~ $prCell/*"]
      # Filter out DSP atoms to only keep the DSP macros: this fixes an issue with report_utilization
      set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != INTERNAL) && (LIB_CELL != GND) && (LIB_CELL != VCC) && NAME =~ $prCell/*"]
    }
    {^..1..$} {
      set reportMode {pblockOnly}
      dputs " -D- parent pblock: $pblock"
      # Get pblock + all nested pblocks
      set allPblocks [getChildPblocks $prPblock]
      dputs " -D- parent+nested pblocks: $allPblocks"
      set leafCells [list]
      foreach pblock $allPblocks {
#         set cells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != MACRO) && PBLOCK == $pblock"]
        # Filter out DSP atoms to only keep the DSP macros: this fixes an issue with report_utilization
        set cells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != INTERNAL) && (LIB_CELL != GND) && (LIB_CELL != VCC) && PBLOCK == $pblock"]
        dputs " -D- pblock $pblock: [llength $cells] cells"
        set leafCells [concat $leafCells $cells]
      }
      set leafCells [get_cells -quiet $leafCells]
      # The following checks are not supported in this mode
      set skipChecks [concat $skipChecks {average_fanout path_budgeting methodology_check}]
    }
    {^1..1.$} {
      set reportMode {regionAndTop}
#       set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != MACRO)"]
     # Filter out DSP atoms to only keep the DSP macros: this fixes an issue with report_utilization
     set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != INTERNAL) && (LIB_CELL != GND) && (LIB_CELL != VCC)"]
    }
    {^.1.1.$} {
      set reportMode {regionAndCell}
#       set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != MACRO) && NAME =~ $prCell/*"]
     # Filter out DSP atoms to only keep the DSP macros: this fixes an issue with report_utilization
      set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != INTERNAL) && (LIB_CELL != GND) && (LIB_CELL != VCC) && NAME =~ $prCell/*"]
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
#       set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != MACRO)"]
      # Filter out DSP atoms to only keep the DSP macros: this fixes an issue with report_utilization
      set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != INTERNAL) && (LIB_CELL != GND) && (LIB_CELL != VCC)"]
    }
    {^.1..1$} {
      set reportMode {slrAndCell}
#       set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != MACRO) && NAME =~ $prCell/*"]
      # Filter out DSP atoms to only keep the DSP macros: this fixes an issue with report_utilization
      set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != INTERNAL) && (LIB_CELL != GND) && (LIB_CELL != VCC) && NAME =~ $prCell/*"]
    }
    {^....1$} {
      set reportMode {slrOnly}
      set leafCells [get_cells -quiet -of [get_slrs -quiet $slrs]]
      # The following checks are not supported in this mode
      set skipChecks [concat $skipChecks {average_fanout path_budgeting methodology_check}]
      # dont_touch is not supported in this mode as it would flag DONT_TOUCH on shell/static
      # logic contained in some of the SLRs
      set skipChecks [concat $skipChecks {dont_touch mark_debug}]
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
#           set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != MACRO) && NAME =~ $prCell/*"]
          # Filter out DSP atoms to only keep the DSP macros: this fixes an issue with report_utilization
          set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != INTERNAL) && (LIB_CELL != GND) && (LIB_CELL != VCC) && NAME =~ $prCell/*"]
          puts " -I- Partial Reconfigurable design detected (cell:$prCell / pblock:$prPblock)"
        } else {
          set reportMode {default}
#           set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != MACRO)"]
          # Filter out DSP atoms to only keep the DSP macros: this fixes an issue with report_utilization
          set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != INTERNAL) && (LIB_CELL != GND) && (LIB_CELL != VCC)"]
        }
      } else {
        set reportMode {default}
#         set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != MACRO)"]
        # Filter out DSP atoms to only keep the DSP macros: this fixes an issue with report_utilization
        set leafCells [get_cells -quiet -hier -filter "IS_PRIMITIVE && (PRIMITIVE_LEVEL != INTERNAL) && (LIB_CELL != GND) && (LIB_CELL != VCC)"]
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
    set skipChecks [concat $skipChecks {average_fanout path_budgeting methodology_check dont_touch mark_debug control_sets non_fd_hfn}]
#     set skipChecks [concat $skipChecks {average_fanout path_budgeting methodology_check dont_touch control_sets}]
    puts " -W- Disabled checks (-exclude_cell): control sets / non-FD HFN / average fanout / path budgeting / methodology checks / DONT_TOUCH / MARK_DEBUG attributes"
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

  if {$extractUtilizationFromSLRTable} {
    # 2019.1 and above: when the utilization by SLR is extracted from "SLR CLB Logic and Dedicated Block Utilization"
    # then do not clear the reports since the same report is used for each SLR (runtime advantage)
    switch $reportMode {
      slrAndTop -
      slrAndCell {
        puts " -W- --use_util_slr_table is not compatible with -top/-cell. Skipping command line option"
        set extractUtilizationFromSLRTable 0
      }
      slrOnly {
        # Only valid use case
        if {$params(verbose)} {
          puts " -I- utilization metrics extracted from SLR Utilization table"
        }
      }
      default {
        puts " -W- --use_util_slr_table is only valid with -slr/-by_slr. Skipping command line option"
        set extractUtilizationFromSLRTable 0
      }
    }
  }

  if {$resetReports} {
    catch { unset reports }
    array set reports [list]
  }

  if {$reportUtilizationFile != {}} {
    importReport report_utilization $reportUtilizationFile
  }

  if {$reportControlSetsFile != {}} {
    importReport report_control_sets $reportControlSetsFile
  }

  if {$reportDesignAnalysisFile != {}} {
    importReport report_design_analysis $reportDesignAnalysisFile
  }

  # Reset internal data structures
  reset

  # Force the rent metric if not included in the config file
  if {$optionRent} {
    # Threshold (PASS) for top-level rent
    set guidelines(design.rent) {<=0.85}
  }

  if {($userConfigFilename == {}) && [info exists ::env(FAILFAST_CONFIG)] && ($::env(FAILFAST_CONFIG) != {})} {
    if {[file exists $::env(FAILFAST_CONFIG)]} {
      set userConfigFilename $::env(FAILFAST_CONFIG)
      if {$params(verbose)} {
        puts " -I- found config file '$::env(FAILFAST_CONFIG)' (FAILFAST_CONFIG)"
      }
    } else {
      puts " -W- config file '$::env(FAILFAST_CONFIG)' does not exists (FAILFAST_CONFIG)"
    }
  }

  if {($userCustomMetricsFiles == {}) && [info exists ::env(FAILFAST_CUSTOM_METRICS)] && ($::env(FAILFAST_CUSTOM_METRICS) != {})} {
    foreach file [split $::env(FAILFAST_CUSTOM_METRICS) {:}] {
      if {![file exists $file]} {
        puts " -W- custom metric file '$file' does not exist (FAILFAST_CUSTOM_METRICS)"
      } else {
        lappend userCustomMetricsFiles $file
      }
    }
  }

  if {$userConfigFilename != {}} {
    # Read the user config file
    puts " -I- reading user config file [file normalize $userConfigFilename]"
    source $userConfigFilename
  } else {
    # Set the default config guidelines
    config
  }

  if {$slrs != {}} {
# dpefour
    if {$extractUtilizationFromSLRTable} {
      # 2019.1 and above: the utilization by SLR is extracted from "SLR CLB Logic and Dedicated Block Utilization".
      # No pblock needs to be created
      set slrPblock $slrs
    } else {
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

  if {[lsearch $skipChecks {mark_debug}] != -1} {
    catch { array unset guidelines design.mark_debug }
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
    catch { array unset guidelines design.cells.avgfo* }
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

  # Necessary to avoid the long list of cells to be truncated when calling getReport
  set collectionResultDisplayLimit [get_param tcl.collectionResultDisplayLimit]
  set_param tcl.collectionResultDisplayLimit  -1

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
      addMetric {design.cells.lut1}             {Number of LUT1 cells}
      addMetric {design.cells.lut1.pct}         {Number of LUT1 cells (%)}
      addMetric {design.cells.lut2}             {Number of LUT2 cells}
      addMetric {design.cells.lut2.pct}         {Number of LUT2 cells (%)}
      addMetric {design.cells.lut3}             {Number of LUT3 cells}
      addMetric {design.cells.lut3.pct}         {Number of LUT3 cells (%)}
      addMetric {design.cells.lut4}             {Number of LUT4 cells}
      addMetric {design.cells.lut4.pct}         {Number of LUT4 cells (%)}
      addMetric {design.cells.lut5}             {Number of LUT5 cells}
      addMetric {design.cells.lut5.pct}         {Number of LUT5 cells (%)}
      addMetric {design.cells.lut6}             {Number of LUT6 cells}
      addMetric {design.cells.lut6.pct}         {Number of LUT6 cells (%)}
      addMetric {design.cells.lut56}            {Number of LUT5/LUT6 cells}
      addMetric {design.cells.lut56.pct}        {Number of LUT5/LUT6 cells (%)}
      addMetric {design.cells.lut456}           {Number of LUT4/LUT5/LUT6 cells}
      addMetric {design.cells.lut456.pct}       {Number of LUT4/LUT5/LUT6 cells (%)}
      addMetric {design.cells.hlutnm}           {Number of HLUTNM cells}
      addMetric {design.cells.hlutnm.pct}       {Number of HLUTNM cells (%)}
      addMetric {design.ports}                  {Number of ports}
      addMetric {design.slrs}                   {Number of SLRs}
      addMetric {design.dont_touch}             {Number of DONT_TOUCH (cells/nets)}
      addMetric {design.mark_debug}             {Number of MARK_DEBUG (nets)}

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
#       setMetric {design.nets}                   [llength [get_nets -quiet -hier -top_net_of_hierarchical_group -segments -filter {TYPE == SIGNAL}]]

      set luts [filter -quiet $leafCells {REF_NAME =~ LUT*}]
      # Versal: filter out the LUTCY* cells
      set luts [filter -quiet $luts {REF_NAME !~ LUTCY*}]

      set lut1 [llength [filter -quiet $luts {REF_NAME == LUT1}] ]
      set lut2 [llength [filter -quiet $luts {REF_NAME == LUT2}] ]
      set lut3 [llength [filter -quiet $luts {REF_NAME == LUT3}] ]
      set lut4 [llength [filter -quiet $luts {REF_NAME == LUT4}] ]
      set lut5 [llength [filter -quiet $luts {REF_NAME == LUT5}] ]
      set lut6 [llength [filter -quiet $luts {REF_NAME == LUT6}] ]
      set lut456 [expr $lut4 + $lut5 + $lut6]
      set lut56 [expr $lut5 + $lut6]
      setMetric {design.cells.lut1} $lut1
      setMetric {design.cells.lut2} $lut2
      setMetric {design.cells.lut3} $lut3
      setMetric {design.cells.lut4} $lut4
      setMetric {design.cells.lut5} $lut5
      setMetric {design.cells.lut6} $lut6
      setMetric {design.cells.lut456} $lut456
      setMetric {design.cells.lut56} $lut56
      # Percent of each LUT type in the total number of LUTs
      foreach el {lut1 lut2 lut3 lut4 lut5 lut6 lut456 lut56} {
        if {[llength $luts] != 0} {
          setMetric "design.cells.${el}.pct" [format {%.2f} [expr {100.0 * double([subst $$el]) / double([llength $luts])}] ]
        } else {
          setMetric "design.cells.${el}.pct" {n/a}
        }
      }

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
      # Filter out the power/ground nets and use the top-level net names to avoid redundancies
#       set dontTouchNets [get_nets -quiet -segments -top_net_of_hierarchical_group [filter -quiet $dontTouchNets {TYPE!=GROUND && TYPE!= POWER}]]
      set dontTouchNets [get_nets -quiet -segments -top_net_of_hierarchical_group [filter -quiet $dontTouchNets {FLAT_PIN_COUNT>=2 && TYPE!=GROUND && TYPE!= POWER}]]
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
        foreach el [lsort -dictionary $dontTouchHierCells] {
          $tbl addrow [list $el]
          set empty 0
        }
        puts $FH [$tbl print]
        catch {$tbl destroy}
        # Leaf cells
        set tbl [::tclapp::xilinx::designutils::prettyTable create [format "DONT_TOUCH (Leaf Cells)\n[llength $dontTouchLeafCells] cell(s)"] ]
        $tbl indent 1
        $tbl header [list {Cell} ]
        foreach el [lsort -dictionary $dontTouchLeafCells] {
          $tbl addrow [list $el]
          set empty 0
        }
        puts $FH [$tbl print]
        catch {$tbl destroy}
        # Nets
        set tbl [::tclapp::xilinx::designutils::prettyTable create [format "DONT_TOUCH (Nets)\n[llength $dontTouchNets] net(s)"] ]
        $tbl indent 1
        if {$showSlackInsideDetailedReports} {
          $tbl header [list {Net} {Fanout} {Slack} {Driver Pin} {Load Pins}]
        } else {
          $tbl header [list {Net} {Fanout} {Driver Pin} {Load Pins}]
        }
        set dontTouchNets [lsort -dictionary $dontTouchNets]
        if {[llength $dontTouchNets] <= $params(max_dont_touch)} {
          foreach net $dontTouchNets prop [get_property -quiet FLAT_PIN_COUNT $dontTouchNets] {
            set driver [get_pins -quiet -of_objects $net -leaf -filter {DIRECTION==OUT}]
            set loads [get_pins -quiet -of_objects $net -leaf -filter {DIRECTION==IN}]
            catch {unset tmp}
            # Column "Load Pins" should report a distribution of the load pins:
            # E.g: FDCE/C (204730) FDPE/C (26) FDRE/C (130873) FDSE/C (5218) HARD_SYNC/CLK (1) RAMB36E2/CLKARDCLK (196)
            set uniqueLoads [list]
            foreach pin $loads \
                    refname [get_property -quiet REF_NAME $loads] \
                    refpinname [get_property -quiet REF_PIN_NAME $loads] {
              incr tmp([format {%s/%s} $refname $refpinname])
            }
            foreach el [lsort -dictionary [array names tmp]] {
              lappend uniqueLoads [format {%s (%s)} $el $tmp($el)]
            }
            set uniqueLoads [join $uniqueLoads { }]
            if {$showSlackInsideDetailedReports} {
              set driver [get_pins -quiet -of_objects $net -leaf -filter {DIRECTION==OUT}]
              set slack [get_property -quiet SETUP_SLACK $driver]
              if {$slack == {}} { set slack {N/A} }
              $tbl addrow [list $net [expr $prop -1] $slack [format {%s/%s} [get_property -quiet REF_NAME $driver] [get_property -quiet REF_PIN_NAME $driver]] $uniqueLoads ]
            } else {
              $tbl addrow [list $net [expr $prop -1]        [format {%s/%s} [get_property -quiet REF_NAME $driver] [get_property -quiet REF_PIN_NAME $driver]] $uniqueLoads ]
            }
            set empty 0
          }
          # Sort the list of nets, higest fanout first
          if {!$empty} { $tbl sort -Fanout +Net }
          puts $FH [$tbl print]
        } else {
          # When there are too many nets, just generate a simple table
          $tbl header [list {Net} ]
          foreach el [lsort $dontTouchNets] {
            $tbl addrow [list $el]
            set empty 0
          }
          puts $FH [$tbl print]
          puts $FH " -W- More than $params(max_dont_touch) nets have the property DONT_TOUCH=1. For runtime reduction, the net details are not reported in the above table"
        }
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
    ## MARK_DEBUG metric
    ##
    ########################################################################################

    if {1 && [llength [array names guidelines design.mark_debug]] && ([lsearch $skipChecks {mark_debug}] == -1)} {
      set stepStartTime [clock seconds]
      set numMarkDebug 0
      set markDebugNets [list]
      switch $reportMode {
        pblockAndTop {
          # Number of nets with MARK_DEBUG.
          set markDebugNets [get_nets -quiet -hier -filter {MARK_DEBUG}]
        }
        pblockAndCell {
          # Number of nets with MARK_DEBUG.
          set markDebugNets [filter -quiet [get_nets -quiet -of $leafCells] {MARK_DEBUG}]
        }
        pblockOnly {
          # Number of nets with MARK_DEBUG.
          set parents [getParentCells $leafCells]
          set markDebugNets [filter -quiet [get_nets -quiet -of $leafCells] {MARK_DEBUG}]
        }
        regionAndTop {
          # Number of nets with MARK_DEBUG.
          set markDebugNets [get_nets -quiet -hier -filter {MARK_DEBUG}]
        }
        regionAndCell {
           # Number of nets with MARK_DEBUG.
          set markDebugNets [filter -quiet [get_nets -quiet -of $leafCells] {MARK_DEBUG}]
       }
        regionOnly {
          # Number of nets with MARK_DEBUG.
          set parents [getParentCells $leafCells]
          set markDebugNets [filter -quiet [get_nets -quiet -of $leafCells] {MARK_DEBUG}]
       }
        slrAndTop {
          # Number of nets with MARK_DEBUG.
          set markDebugNets [get_nets -quiet -hier -filter {MARK_DEBUG}]
        }
        slrAndCell {
          # Number of nets with MARK_DEBUG.
          set markDebugNets [filter -quiet [get_nets -quiet -of $leafCells] {MARK_DEBUG}]
        }
        slrOnly {
          # Number of nets with MARK_DEBUG.
#           set parents [getParentCells $leafCells]
#           set markDebugNets [filter -quiet [get_nets -quiet -of $leafCells] {MARK_DEBUG}]
          # mark_debug is not supported in this mode as it would flag MARK_DEBUG on shell/static
          # logic contained in some of the SLRs
          array unset guidelines design.mark_debug
        }
        default {
          # Number of nets with MARK_DEBUG.
          set markDebugNets [get_nets -quiet -hier -filter {MARK_DEBUG}]
        }
      }
      # Filter out the power/ground nets and use the top-level net names to avoid redundancies
      set markDebugNets [lsort -dictionary [get_nets -quiet -segments -top_net_of_hierarchical_group [filter -quiet $markDebugNets {TYPE!=GROUND && TYPE!= POWER}]]]
      set numMarkDebug [llength $markDebugNets]
      setMetric {design.mark_debug} $numMarkDebug

      if {$detailedReportsPrefix != {}} {
        set empty 1
        catch { file copy ${detailedReportsDir}/${detailedReportsPrefix}.MARK_DEBUG.rpt ${detailedReportsDir}/${detailedReportsPrefix}.MARK_DEBUG.rpt.${pid} }
        set FH [open "${detailedReportsDir}/${detailedReportsPrefix}.MARK_DEBUG.rpt.${pid}" $filemode]
        if {$showFileHeader} {
          puts $FH "# ---------------------------------------------------------------------------"
          puts $FH [format {# Created on %s with report_failfast (%s)} [clock format [clock seconds]] $::tclapp::xilinx::designutils::report_failfast::version ]
          puts $FH "# ---------------------------------------------------------------------------\n"
        }
        # Nets
        set tbl [::tclapp::xilinx::designutils::prettyTable create [format "MARK_DEBUG (Nets)\n[llength $markDebugNets] net(s)"] ]
        $tbl indent 1
        if {$showSlackInsideDetailedReports} {
          $tbl header [list {Net} {Fanout} {Slack} {Driver Pin} {Load Pins}]
        } else {
          $tbl header [list {Net} {Fanout} {Driver Pin} {Load Pins}]
        }
        if {[llength $markDebugNets] <= $params(max_mark_debug)} {
          foreach net $markDebugNets prop [get_property -quiet FLAT_PIN_COUNT $markDebugNets] {
            set driver [get_pins -quiet -of_objects $net -leaf -filter {DIRECTION==OUT}]
            set loads [get_pins -quiet -of_objects $net -leaf -filter {DIRECTION==IN}]
            catch {unset tmp}
            # Column "Load Pins" should report a distribution of the load pins:
            # E.g: FDCE/C (204730) FDPE/C (26) FDRE/C (130873) FDSE/C (5218) HARD_SYNC/CLK (1) RAMB36E2/CLKARDCLK (196)
            set uniqueLoads [list]
            foreach pin $loads \
                    refname [get_property -quiet REF_NAME $loads] \
                    refpinname [get_property -quiet REF_PIN_NAME $loads] {
              incr tmp([format {%s/%s} $refname $refpinname])
            }
            foreach el [lsort -dictionary [array names tmp]] {
              lappend uniqueLoads [format {%s (%s)} $el $tmp($el)]
            }
            set uniqueLoads [join $uniqueLoads { }]
            if {$showSlackInsideDetailedReports} {
              set slack [get_property -quiet SETUP_SLACK $driver]
              if {$slack == {}} { set slack {N/A} }
              $tbl addrow [list $net [expr $prop -1] $slack [format {%s/%s} [get_property -quiet REF_NAME $driver] [get_property -quiet REF_PIN_NAME $driver]] $uniqueLoads ]
            } else {
              $tbl addrow [list $net [expr $prop -1]        [format {%s/%s} [get_property -quiet REF_NAME $driver] [get_property -quiet REF_PIN_NAME $driver]] $uniqueLoads ]
            }
            set empty 0
          }
          # Sort the list of nets, higest fanout first
          if {!$empty} { $tbl sort -Fanout +Net }
          puts $FH [$tbl print]
        } else {
          # When there are too many nets, just generate a simple table
          $tbl header [list {Net} ]
          foreach el [lsort $markDebugNets] {
            $tbl addrow [list $el]
            set empty 0
          }
          puts $FH [$tbl print]
          puts $FH " -W- More than $params(max_mark_debug) nets have the property MARK_DEBUG=1. For runtime reduction, the net details are not reported in the above table"
        }
        catch {$tbl destroy}
        close $FH
        if {$empty} {
          file delete -force ${detailedReportsDir}/${detailedReportsPrefix}.MARK_DEBUG.rpt.${pid}
        } else {
          file rename -force ${detailedReportsDir}/${detailedReportsPrefix}.MARK_DEBUG.rpt.${pid} ${detailedReportsDir}/${detailedReportsPrefix}.MARK_DEBUG.rpt
          puts " -I- Generated file [file normalize ${detailedReportsDir}/${detailedReportsPrefix}.MARK_DEBUG.rpt]"
        }
      }
      set stepStopTime [clock seconds]
      puts " -I- MARK_DEBUG metric completed in [expr $stepStopTime - $stepStartTime] seconds"
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
        }
        regionAndTop -
        regionAndCell -
        regionOnly {
          set rptUtilOpts [list -pblock $regionPblock -evaluate_pblock]
        }
        slrAndTop -
        slrAndCell -
        slrOnly {
          set rptUtilOpts [list -pblock $slrPblock -evaluate_pblock]
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
          if {$params(debug)} { if {$rptUtilOpts != {}} { puts " -D- utilization report run with '-pblock $slrPblock -evaluate_pblock'" } }
          set report [getReport report_utilization {*}$rptUtilOpts -quiet -cells $leafCells -return_string]
        }
        pblockAndCell {
          if {$params(debug)} { if {$rptUtilOpts != {}} { puts " -D- utilization report run with '-pblock $slrPblock -evaluate_pblock'" } }
          set report [getReport report_utilization -quiet {*}$rptUtilOpts -cells $leafCells -return_string]
        }
        pblockOnly {
          if {$params(debug)} { if {$rptUtilOpts != {}} { puts " -D- utilization report run with '-pblock $slrPblock -evaluate_pblock'" } }
          set report [getReport report_utilization -quiet {*}$rptUtilOpts -cells $leafCells -return_string]
        }
        regionAndTop {
          if {$params(debug)} { if {$rptUtilOpts != {}} { puts " -D- utilization report run with '-pblock $slrPblock -evaluate_pblock'" } }
          set report [getReport report_utilization -quiet {*}$rptUtilOpts -cells $leafCells -return_string]
        }
        regionAndCell {
          if {$params(debug)} { if {$rptUtilOpts != {}} { puts " -D- utilization report run with '-pblock $slrPblock -evaluate_pblock'" } }
          set report [getReport report_utilization -quiet {*}$rptUtilOpts -cells $leafCells -return_string]
        }
        regionOnly {
          if {$params(debug)} { if {$rptUtilOpts != {}} { puts " -D- utilization report run with '-pblock $slrPblock -evaluate_pblock'" } }
          set report [getReport report_utilization -quiet {*}$rptUtilOpts -cells $leafCells -return_string]
        }
        slrAndTop {
          if {$params(debug)} { if {$rptUtilOpts != {}} { puts " -D- utilization report run with '-pblock $slrPblock -evaluate_pblock'" } }
          set report [getReport report_utilization -quiet {*}$rptUtilOpts -cells $leafCells -return_string]
        }
        slrAndCell {
          if {$params(debug)} { if {$rptUtilOpts != {}} { puts " -D- utilization report run with '-pblock $slrPblock -evaluate_pblock'" } }
          set report [getReport report_utilization -quiet {*}$rptUtilOpts -cells $leafCells -return_string]
        }
        slrOnly {
          if {$extractUtilizationFromSLRTable} {
            # 2019.1 and above: when the utilization by SLR is extracted from "SLR CLB Logic and Dedicated Block Utilization".
            # In this mode, the utilization report should not be done for a specific SLR but for the entire device
            # since the same report is used for extracting the utilization metrics for each SLR
            set report [getReport report_utilization -quiet -return_string]
          } else {
            if {$params(debug)} { if {$rptUtilOpts != {}} { puts " -D- utilization report run with '-pblock $slrPblock -evaluate_pblock'" } }
            set report [getReport report_utilization -quiet {*}$rptUtilOpts -cells $leafCells -return_string]
          }
        }
        default {
          set report [getReport report_utilization -quiet -cells $leafCells -return_string]
        }
      }

      # +-------------------------+------+-------+-----------+-------+
      # |        Site Type        | Used | Fixed | Available | Util% |
      # +-------------------------+------+-------+-----------+-------+
      # | Registers               |  631 |     0 |   1799680 |  0.04 |
      # |   Register as Flip Flop |  631 |     0 |   1799680 |  0.04 |
      # |   Register as Latch     |    0 |     0 |   1799680 |  0.00 |
      # | CLB LUTs*               |  582 |     0 |    899840 |  0.06 |
      # |   LUT as Logic          |  582 |     0 |    899840 |  0.06 |
      # |   LUT as Memory         |    0 |     0 |    449920 |  0.00 |
      # | LOOKAHEAD8              |    0 |     0 |    112480 |  0.00 |
      # +-------------------------+------+-------+-----------+-------+
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

      addMetric {utilization.clb.lut}              {CLB LUTs}
      addMetric {utilization.clb.lut.pct}          {CLB LUTs (%)}
      addMetric {utilization.clb.lut.avail}        {CLB LUTs (Avail)}
      addMetric {utilization.clb.ff}               {CLB Registers}
      addMetric {utilization.clb.ff.pct}           {CLB Registers (%)}
      addMetric {utilization.clb.ff.avail}         {CLB Registers (Avail)}
      addMetric {utilization.clb.ld}               {CLB Latches}
      addMetric {utilization.clb.ld.pct}           {CLB Latches (%)}
      addMetric {utilization.clb.ld.avail}         {CLB Latches (Avail)}
      addMetric {utilization.clb.carry8}           {CARRY8}
      addMetric {utilization.clb.carry8.pct}       {CARRY8 (%)}
      addMetric {utilization.clb.carry8.avail}     {CARRY8 (Avail)}
      addMetric {utilization.clb.lookahead8}       {LOOKAHEAD8}
      addMetric {utilization.clb.lookahead8.pct}   {LOOKAHEAD8 (%)}
      addMetric {utilization.clb.lookahead8.avail} {LOOKAHEAD8 (Avail)}
      addMetric {utilization.clb.f7mux}            {F7 Muxes}
      addMetric {utilization.clb.f7mux.pct}        {F7 Muxes (%)}
      addMetric {utilization.clb.f7mux.avail}      {F7 Muxes (Avail)}
      addMetric {utilization.clb.f8mux}            {F8 Muxes}
      addMetric {utilization.clb.f8mux.pct}        {F8 Muxes (%)}
      addMetric {utilization.clb.f8mux.avail}      {F8 Muxes (Avail)}
      addMetric {utilization.clb.f9mux}            {F9 Muxes}
      addMetric {utilization.clb.f9mux.pct}        {F9 Muxes (%)}
      addMetric {utilization.clb.f9mux.avail}      {F9 Muxes (Avail)}
      addMetric {utilization.clb.lutmem}           {LUT as Memory}
      addMetric {utilization.clb.lutmem.pct}       {LUT as Memory (%)}
      addMetric {utilization.clb.lutmem.avail}     {LUT as Memory (Avail)}
#       addMetric {utilization.ctrlsets.uniq}      {Unique Control Sets}
#       addMetric {utilization.ctrlsets.lost}      {Registers Lost due to Control Sets}

      extractMetricFromTable report {utilization.clb.lut}              -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{CLB LUTs} {Slice LUTs}} -column {Used} -default {n/a}
      extractMetricFromTable report {utilization.clb.lut.pct}          -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{CLB LUTs} {Slice LUTs}} -column {Util%} -trim float -default {n/a}

      extractMetricFromTable report {utilization.clb.ff}               -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{CLB Registers} {Slice Registers} {^Registers$}} -column {Used} -default {n/a}
      extractMetricFromTable report {utilization.clb.ff.pct}           -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{CLB Registers} {Slice Registers} {^Registers$}} -column {Util%} -trim float -default {n/a}

      extractMetricFromTable report {utilization.clb.ld}               -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{Register as Latch}} -column {Used} -default {n/a}
      extractMetricFromTable report {utilization.clb.ld.pct}           -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{Register as Latch}} -column {Util%} -trim float -default {n/a}

      extractMetricFromTable report {utilization.clb.carry8}           -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{CARRY8}} -column {Used} -default {n/a}
      extractMetricFromTable report {utilization.clb.carry8.pct}       -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{CARRY8}} -column {Util%} -trim float -default {n/a}

      extractMetricFromTable report {utilization.clb.lookahead8}       -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{LOOKAHEAD8}} -column {Used} -default {n/a}
      extractMetricFromTable report {utilization.clb.lookahead8.pct}   -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{LOOKAHEAD8}} -column {Util%} -trim float -default {n/a}

      extractMetricFromTable report {utilization.clb.f7mux}            -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{F7 Muxes}} -column {Used} -default {n/a}
      extractMetricFromTable report {utilization.clb.f7mux.pct}        -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{F7 Muxes}} -column {Util%} -trim float -default {n/a}

      extractMetricFromTable report {utilization.clb.f8mux}            -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{F8 Muxes}} -column {Used} -default {n/a}
      extractMetricFromTable report {utilization.clb.f8mux.pct}        -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{F8 Muxes}} -column {Util%} -trim float -default {n/a}

      extractMetricFromTable report {utilization.clb.f9mux}            -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{F9 Muxes}} -column {Used} -default {n/a}
      extractMetricFromTable report {utilization.clb.f9mux.pct}        -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{F9 Muxes}} -column {Util%} -trim float -default {n/a}

      extractMetricFromTable report {utilization.clb.lutmem}           -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{LUT as Memory}} -column {Used} -default {n/a}
      extractMetricFromTable report {utilization.clb.lutmem.pct}       -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{LUT as Memory}} -column {Util%} -trim float -default {n/a}

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
      # +--------------------+------+-------+-----------+-------+
      # |      Site Type     | Used | Fixed | Available | Util% |
      # +--------------------+------+-------+-----------+-------+
      # | DSP Slices         |  202 |     0 |      1968 | 10.26 |
      # |   DSP58            |  182 |     0 |           |       |
      # |   DSPCPLX          |    0 |     0 |           |       |
      # |   DSPFP32          |    0 |     0 |           |       |
      # |   DSP48E5          |   20 |     0 |           |       |
      # | DSP Imux registers |    0 |     0 |           |       |
      # |   Pipelining       |    0 |       |           |       |
      # |   Hold fixing      |    0 |       |           |       |
      # +--------------------+------+-------+-----------+-------+

      addMetric {utilization.dsp}       {DSPs}
      addMetric {utilization.dsp.pct}   {DSPs (%)}
      addMetric {utilization.dsp.avail} {DSPs (Avail)}

      extractMetricFromTable report {utilization.dsp}              -search {{(ARITHMETIC|DSP)\s*$} {(ARITHMETIC|DSP)\s*$}} -row {{DSPs} {DSP Slices}} -column {Used} -default {n/a}
      extractMetricFromTable report {utilization.dsp.pct}          -search {{(ARITHMETIC|DSP)\s*$} {(ARITHMETIC|DSP)\s*$}} -row {{DSPs} {DSP Slices}} -column {Util%} -trim float -default {n/a}

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

      extractMetricFromTable report {utilization.clb.lut.avail}        -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{CLB LUTs} {Slice LUTs}} -column {Available} -default {n/a}
      extractMetricFromTable report {utilization.clb.ff.avail}         -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{CLB Registers} {Slice Registers} {^Registers$}} -column {Available} -default {n/a}
      extractMetricFromTable report {utilization.clb.ld.avail}         -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{Register as Latch}} -column {Available} -default {n/a}
      extractMetricFromTable report {utilization.clb.carry8.avail}     -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{CARRY8}} -column {Available} -default {n/a}
      extractMetricFromTable report {utilization.clb.lookahead8.avail} -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{LOOKAHEAD8}} -column {Available} -default {n/a}
      extractMetricFromTable report {utilization.clb.f7mux.avail}      -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{F7 Muxes}} -column {Available} -default {n/a}
      extractMetricFromTable report {utilization.clb.f8mux.avail}      -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{F8 Muxes}} -column {Available} -default {n/a}
      extractMetricFromTable report {utilization.clb.f9mux.avail}      -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{F9 Muxes}} -column {Available} -default {n/a}
      extractMetricFromTable report {utilization.clb.lutmem.avail}     -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{LUT as Memory}} -column {Available} -default {n/a}
      extractMetricFromTable report {utilization.ram.tile.avail}       -search {{(BLOCKRAM|Memory)\s*$} {(BLOCKRAM|Memory)\s*$}} -row {{Block RAM Tile}} -column {Available} -default {n/a}
      extractMetricFromTable report {utilization.uram.tile.avail}      -search {{(BLOCKRAM|Memory)\s*$} {(BLOCKRAM|Memory)\s*$}} -row {{URAM}} -column {Available} -default {n/a}
      extractMetricFromTable report {utilization.dsp.avail}            -search {{(ARITHMETIC|DSP)\s*$}  {(ARITHMETIC|DSP)\s*$}}  -row {{DSPs} {DSP Slices}} -column {Available} -default {n/a}

      # Calculate the utilization (%) based on the available and used resources
      foreach var [list \
        {utilization.clb.lut}        \
        {utilization.clb.ff}         \
        {utilization.clb.carry8}     \
        {utilization.clb.lookahead8} \
        {utilization.clb.f7mux}      \
        {utilization.clb.f8mux}      \
        {utilization.clb.f9mux}      \
        {utilization.clb.lutmem}     \
        {utilization.ram.tile}       \
        {utilization.uram.tile}      \
        {utilization.dsp}            \
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

      if {$extractUtilizationFromSLRTable && ([package vcompare $params(vivado_version) 2019.1.0] >= 0)} {
        # 2019.1 and above: the utilization by SLR is extracted from "SLR CLB Logic and Dedicated Block Utilization".
        # To reduce the overall impact on the structure of the script, the utilization metrics have already been extracted
        # from the above Tcl code, but from the wrong table inside the utilization report. This section of code extract the
        # correct metrics for the selected SLR

        # +----------------------------+--------+--------+--------+--------+--------+--------+
        # |          Site Type         |  SLR0  |  SLR1  |  SLR2  | SLR0 % | SLR1 % | SLR2 % |
        # +----------------------------+--------+--------+--------+--------+--------+--------+
        # | CLB                        |  48707 |  28059 |  48813 |  98.88 |  56.96 |  99.09 |
        # |   CLBL                     |  24314 |  13822 |  24378 |  98.84 |  56.19 |  99.10 |
        # |   CLBM                     |  24393 |  14237 |  24435 |  98.92 |  57.73 |  99.09 |
        # | CLB LUTs                   | 307516 | 102021 | 306638 |  78.03 |  25.89 |  77.81 |
        # |   LUT as Logic             | 290312 |  95985 | 289513 |  73.67 |  24.36 |  73.47 |
        # |     using O5 output only   |   4277 |   1326 |   4302 |   1.09 |   0.34 |   1.09 |
        # |     using O6 output only   | 226496 |  70821 | 225876 |  57.47 |  17.97 |  57.32 |
        # |     using O5 and O6        |  59539 |  23838 |  59335 |  15.11 |   6.05 |  15.06 |
        # |   LUT as Memory            |  17204 |   6036 |  17125 |   8.72 |   3.06 |   8.68 |
        # |     LUT as Distributed RAM |  12474 |   4380 |  12394 |   6.32 |   2.22 |   6.28 |
        # |       using O5 output only |      0 |      0 |      0 |   0.00 |   0.00 |   0.00 |
        # |       using O6 output only |  10362 |   1400 |  10282 |   5.25 |   0.71 |   5.21 |
        # |       using O5 and O6      |   2112 |   2980 |   2112 |   1.07 |   1.51 |   1.07 |
        # |     LUT as Shift Register  |   4730 |   1656 |   4731 |   2.40 |   0.84 |   2.40 |
        # |       using O5 output only |      0 |      0 |      0 |   0.00 |   0.00 |   0.00 |
        # |       using O6 output only |   2227 |    264 |   2232 |   1.13 |   0.13 |   1.13 |
        # |       using O5 and O6      |   2503 |   1392 |   2499 |   1.27 |   0.71 |   1.27 |
        # | CLB Registers              | 260292 | 173618 | 258852 |  33.03 |  22.03 |  32.84 |
        # | CARRY8                     |   7240 |   1557 |   7240 |  14.70 |   3.16 |  14.70 |
        # | F7 Muxes                   |  12221 |   2542 |  12216 |   6.20 |   1.29 |   6.20 |
        # | F8 Muxes                   |   3144 |    663 |   3142 |   3.19 |   0.67 |   3.19 |
        # | F9 Muxes                   |      0 |      0 |      0 |   0.00 |   0.00 |   0.00 |
        # | Block RAM Tile             |    453 |     69 |  452.5 |  62.92 |   9.58 |  62.85 |
        # |   RAMB36/FIFO              |    302 |     68 |    302 |  41.94 |   9.44 |  41.94 |
        # |     RAMB36E2 only          |    302 |     68 |    302 |  41.94 |   9.44 |  41.94 |
        # |   RAMB18                   |    302 |      2 |    301 |  20.97 |   0.14 |  20.90 |
        # |     RAMB18E2 only          |    302 |      2 |    301 |  20.97 |   0.14 |  20.90 |
        # | URAM                       |     32 |      0 |     32 |  10.00 |   0.00 |  10.00 |
        # | DSPs                       |    323 |      1 |    323 |  14.17 |   0.04 |  14.17 |
        # | PLL                        |      0 |      0 |      0 |   0.00 |   0.00 |   0.00 |
        # | MMCM                       |      0 |      0 |      0 |   0.00 |   0.00 |   0.00 |
        # | Unique Control Sets        |   7635 |   3925 |   7577 |   7.75 |   3.98 |   7.69 |
        # +----------------------------+--------+--------+--------+--------+--------+--------+

        extractMetricFromTable report {utilization.clb.lut}              -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{CLB LUTs} {Slice LUTs}} -column $slrs -default {n/a}
        extractMetricFromTable report {utilization.clb.lut.pct}          -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{CLB LUTs} {Slice LUTs}} -column "$slrs %" -trim float -default {n/a}

        extractMetricFromTable report {utilization.clb.ff}               -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{CLB Registers} {Slice Registers} {^Registers$}} -column $slrs -default {n/a}
        extractMetricFromTable report {utilization.clb.ff.pct}           -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{CLB Registers} {Slice Registers} {^Registers$}} -column "$slrs %" -trim float -default {n/a}

        extractMetricFromTable report {utilization.clb.ld}               -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{Register as Latch}} -column $slrs -default {n/a}
        extractMetricFromTable report {utilization.clb.ld.pct}           -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{Register as Latch}} -column "$slrs %" -trim float -default {n/a}

        extractMetricFromTable report {utilization.clb.carry8}           -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{CARRY8}} -column $slrs -default {n/a}
        extractMetricFromTable report {utilization.clb.carry8.pct}       -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{CARRY8}} -column "$slrs %" -trim float -default {n/a}

        extractMetricFromTable report {utilization.clb.lookahead8}       -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{LOOKAHEAD8}} -column $slrs -default {n/a}
        extractMetricFromTable report {utilization.clb.lookahead8.pct}   -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{LOOKAHEAD8}} -column "$slrs %" -trim float -default {n/a}

        extractMetricFromTable report {utilization.clb.f7mux}            -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{F7 Muxes}} -column $slrs -default {n/a}
        extractMetricFromTable report {utilization.clb.f7mux.pct}        -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{F7 Muxes}} -column "$slrs %" -trim float -default {n/a}

        extractMetricFromTable report {utilization.clb.f8mux}            -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{F8 Muxes}} -column $slrs -default {n/a}
        extractMetricFromTable report {utilization.clb.f8mux.pct}        -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{F8 Muxes}} -column "$slrs %" -trim float -default {n/a}

        extractMetricFromTable report {utilization.clb.f9mux}            -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{F9 Muxes}} -column $slrs -default {n/a}
        extractMetricFromTable report {utilization.clb.f9mux.pct}        -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{F9 Muxes}} -column "$slrs %" -trim float -default {n/a}

        extractMetricFromTable report {utilization.clb.lutmem}           -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{LUT as Memory}} -column $slrs -default {n/a}
        extractMetricFromTable report {utilization.clb.lutmem.pct}       -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{LUT as Memory}} -column "$slrs %" -trim float -default {n/a}

        extractMetricFromTable report {utilization.ram.tile}             -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{Block RAM Tile}} -column $slrs -default {n/a}
        extractMetricFromTable report {utilization.ram.tile.pct}         -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{Block RAM Tile}} -column "$slrs %" -trim float -default {n/a}

        extractMetricFromTable report {utilization.uram.tile}            -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{URAM}} -column $slrs -default {n/a}
        extractMetricFromTable report {utilization.uram.tile.pct}        -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{URAM}} -column "$slrs %" -trim float -default {n/a}

        extractMetricFromTable report {utilization.dsp}                  -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{DSPs} {DSP Slices}} -column $slrs -default {n/a}
        extractMetricFromTable report {utilization.dsp.pct}              -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{DSPs} {DSP Slices}} -column "$slrs %" -trim float -default {n/a}

        # BUFG* stats are not inside the "SLR CLB Logic and Dedicated Block Utilization" table, therefore
        # they should not be reported
        array unset guidelines utilization.clk.all

        # Calculate the guidelines for the max number of control sets if it is not provided
        if {![regexp {[0-9]+} $guidelines(utilization.ctrlsets.uniq)]} {
          # If no number is defined inside $guidelines(utilization.ctrlsets.uniq) it means that
          # the number of control sets should be calculated based on the number of available
          # FD resources inside the SLR. Since report_utilization has not been scoped and has been
          # run from the top, the available resources are for the entire device. Need to divide by the
          # number of SLRs.
          # The metric $guidelines(utilization.ctrlsets.uniq) is calculated here since the metric
          # utilization.clb.ff.avail is reset afterward
          # Formula: 7.5% * (#FD / 8) / #SLRs
          append guidelines(utilization.ctrlsets.uniq) [format {%.0f} [expr [getMetric utilization.clb.ff.avail] / 8.0 * 7.5 / 100.0 / [llength [get_slrs -quiet]]]]
          if {$params(debug)} { puts " -D- available registers for control sets calculation: [getMetric utilization.clb.ff.avail]" }
          if {$params(verbose)} { puts " -W- setting guideline for control sets to '$guidelines(utilization.ctrlsets.uniq)'" }
        }

        if {$params(debug)} { puts " -D- calculating available resources for $slrPblock" }
        foreach var [list \
          {utilization.clb.lut}        \
          {utilization.clb.ff}         \
          {utilization.clb.carry8}     \
          {utilization.clb.lookahead8} \
          {utilization.clb.f7mux}      \
          {utilization.clb.f8mux}      \
          {utilization.clb.f9mux}      \
          {utilization.clb.lutmem}     \
          {utilization.ram.tile}       \
          {utilization.uram.tile}      \
          {utilization.dsp}            \
          ] {
            # Clear the metrics related to the available resources
            # Re-calculate the available resources by dividing the number extracted from the main table by the number of SLRs.
            # This means that the estimation assumes that each SLR has the same number of available resources.
            if {[catch {setMetric ${var}.avail [format {%.0f} [expr [getMetric ${var}.avail] / [llength [get_slrs -quiet]]]]} errorstring]} {
              setMetric ${var}.avail {n/a}
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
          if {$params(verbose)} { puts " -I- removing LUT Combining metric (design.cells.hlutnm.pct) due to low LUT utilization ([getMetric {utilization.clb.lut.pct}]% < 50%)" }
          array unset guidelines design.cells.hlutnm.pct
        }
      }]} {
      }

      set stepStopTime [clock seconds]
      puts " -I- utilization metrics completed in [expr $stepStopTime - $stepStartTime] seconds"
    }

    ########################################################################################
    ##
    ## Detailed summary table for the BUFG* clock buffers
    ##
    ########################################################################################

    #   +----------------------------------------------------------------------------------------------------------------+
    #   | Clock Buffers (BUFGCE / BUFGCE_DIV / BUFGCTRL)                                                                 |
    #   +-------------+-------------------------+------------------------------+-------+--------+------------------------+
    #   | Driver Type | Driver Pin              | Net                          | Slack | Fanout | Load Pins              |
    #   +-------------+-------------------------+------------------------------+-------+--------+------------------------+
    #   | BUFG        | mmcm_inst/clkout2_buf/O | mmcm_inst/CLK_200i           | N/A   | 4      | FDCE/C (3) LUT3/I0 (1) |
    #   | BUFG        | mmcm_inst/clkout1_buf/O | mmcm_inst/CLK_100i           | N/A   | 2      | FDCE/C (2)             |
    #   | BUFG        | mmcm_inst/clkout3_buf/O | mmcm_inst/CLK_166i           | N/A   | 1      | LUT3/I2 (1)            |
    #   | BUFG        | mmcm_inst/clkf_buf/O    | mmcm_inst/clkfbout_buf_mmcm0 | N/A   | 1      | MMCME2_ADV/CLKFBIN (1) |
    #   +-------------+-------------------------+------------------------------+-------+--------+------------------------+

    if {1 && [llength [array names guidelines utilization.*]] && ([lsearch $skipChecks {utilization}] == -1)} {
      if {$detailedReportsPrefix != {}} {
        set empty 1
        catch { file copy ${detailedReportsDir}/${detailedReportsPrefix}.BUFG.rpt ${detailedReportsDir}/${detailedReportsPrefix}.BUFG.rpt.${pid} }
        set FH [open "${detailedReportsDir}/${detailedReportsPrefix}.BUFG.rpt.${pid}" $filemode]
        if {$showFileHeader} {
          puts $FH "# ---------------------------------------------------------------------------"
          puts $FH [format {# Created on %s with report_failfast (%s)} [clock format [clock seconds]] $::tclapp::xilinx::designutils::report_failfast::version ]
          puts $FH "# ---------------------------------------------------------------------------\n"
        }
        set tbl [::tclapp::xilinx::designutils::prettyTable create [format {Clock Buffers (BUFGCE / BUFGCE_DIV / BUFGCTRL)}] ]
        $tbl indent 1
#         $tbl header [list {Driver Type} {Driver Pin} {Net} {DONT_TOUCH} {MARK_DEBUG} {Fanout} ]
        if {$showSlackInsideDetailedReports} {
          $tbl header [list {Driver Type} {Driver Pin} {Net} {Slack} {Fanout} {Load Pins} ]
        } else {
          $tbl header [list {Driver Type} {Driver Pin} {Net} {Fanout} {Load Pins} ]
        }
        set drivers [get_cells -quiet -hier -filter {REF_NAME==BUFG || REF_NAME==BUFGCE || REF_NAME==BUFGCE_DIV || REF_NAME==BUFGCTRL}]
        foreach driver $drivers {
          set pin [get_pins -quiet -of $driver -filter {DIRECTION==OUT}]
          set refname [get_property -quiet {REF_NAME} $pin]
          set net [get_nets -quiet -of $pin]
          set fanout [expr [get_property -quiet FLAT_PIN_COUNT $net] -1]
          # Extract the list of unique load pins
          set loads [get_pins -quiet -of_objects $net -leaf -filter {DIRECTION==IN}]
          catch {unset tmp}
          # Column "Load Pins" should report a distribution of the load pins:
          # E.g: FDCE/C (204730) FDPE/C (26) FDRE/C (130873) FDSE/C (5218) HARD_SYNC/CLK (1) RAMB36E2/CLKARDCLK (196)
          set uniqueLoads [list]
          foreach _pin $loads \
                  _refname [get_property -quiet REF_NAME $loads] \
                  _refpinname [get_property -quiet REF_PIN_NAME $loads] {
            incr tmp([format {%s/%s} $_refname $_refpinname])
          }
          foreach el [lsort -dictionary [array names tmp]] {
            lappend uniqueLoads [format {%s (%s)} $el $tmp($el)]
          }
          set uniqueLoads [join $uniqueLoads { }]
          if {$showSlackInsideDetailedReports} {
            set driver [get_pins -quiet -of_objects $net -leaf -filter {DIRECTION==OUT}]
            set slack [get_property -quiet SETUP_SLACK $driver]
            if {$slack == {}} { set slack {N/A} }
            $tbl addrow [list $refname $pin $net $slack $fanout $uniqueLoads ]
          } else {
            $tbl addrow [list $refname $pin $net $fanout $uniqueLoads ]
          }

          set empty 0
        }
        if {!$empty} { $tbl sort -Fanout +Net }
        puts $FH [$tbl print]
        catch {$tbl destroy}
        close $FH
        if {$empty} {
          file delete -force ${detailedReportsDir}/${detailedReportsPrefix}.BUFG.rpt.${pid}
        } else {
          file rename -force ${detailedReportsDir}/${detailedReportsPrefix}.BUFG.rpt.${pid} ${detailedReportsDir}/${detailedReportsPrefix}.BUFG.rpt
          puts " -I- Generated file [file normalize ${detailedReportsDir}/${detailedReportsPrefix}.BUFG.rpt]"
        }
      }

    }

    ########################################################################################
    ##
    ## Control sets metric
    ##
    ########################################################################################

    if {1 && $extractUtilizationFromSLRTable && [llength [array names guidelines utilization.*]] && ([lsearch $skipChecks {control_sets}] == -1)} {
      switch $reportMode {
        pblockAndTop -
        pblockAndCell -
        pblockOnly -
        regionAndTop -
        regionAndCell -
        regionOnly -
        slrAndTop -
        slrAndCell {
          # Should never come here. In any of those modes, $extractUtilizationFromSLRTable = 0
        }
        slrOnly {
          # Retreive the previous report_utilization. Extract the number of control sets
          # from the table "SLR CLB Logic and Dedicated Block Utilization"
          set report [getReport report_utilization]
          set stepStartTime [clock seconds]
          addMetric {utilization.ctrlsets.uniq}    {Unique Control Sets}
          extractMetricFromTable report {utilization.ctrlsets.uniq}    -search {{SLR CLB Logic} {SLR CLB Logic}} -row {{Unique Control Sets}} -column $slrs -trim float -default {n/a}
          set stepStopTime [clock seconds]
          puts " -I- control set metrics completed in [expr $stepStopTime - $stepStartTime] seconds"
        }
        default {
        }
      }

    }

    if {1 && !$extractUtilizationFromSLRTable && [llength [array names guidelines utilization.*]] && ([lsearch $skipChecks {control_sets}] == -1)} {
      set stepStartTime [clock seconds]
      # Get report
      switch $reportMode {
        pblockAndTop {
          set report [getReport report_control_sets -quiet -return_string]
        }
        pblockAndCell {
          set report [getReport report_control_sets -quiet -cell $leafCells -return_string]
        }
        pblockOnly {
          set report [getReport report_control_sets -quiet -cell $leafCells -return_string]
        }
        regionAndTop {
          set report [getReport report_control_sets -quiet -return_string]
        }
        regionAndCell {
          set report [getReport report_control_sets -quiet -cell $leafCells -return_string]
        }
        regionOnly {
          set report [getReport report_control_sets -quiet -cell $leafCells -return_string]
        }
        slrAndTop {
          set report [getReport report_control_sets -quiet -return_string]
        }
        slrAndCell {
          set report [getReport report_control_sets -quiet -cell $leafCells -return_string]
        }
        slrOnly {
          set report [getReport report_control_sets -quiet -cell $leafCells -return_string]
        }
        default {
          set report [getReport report_control_sets -quiet -return_string]
        }
      }

      addMetric {utilization.ctrlsets.uniq}  {Unique Control Sets}

      extractMetricFromTable report {utilization.ctrlsets.uniq}    -search {{Summary} {Summary}} -row {{Number of unique control sets} {Total control sets}} -column {Count} -default {n/a}

      if {(![regexp {[0-9]+} $guidelines(utilization.ctrlsets.uniq)]) && ([getMetric utilization.clb.ff.avail] != {})} {
        # If no number is defined inside $guidelines(utilization.ctrlsets.uniq) it means that
        # the number of control sets should be calculated based on the number of available
        # FD resources
        # Formula: 7.5% * (#FD / 8)
        append guidelines(utilization.ctrlsets.uniq) [format {%.0f} [expr [getMetric utilization.clb.ff.avail] / 8.0 * 7.5 / 100.0]]
        if {$params(debug)} { puts " -D- available registers for control sets calculation: [getMetric utilization.clb.ff.avail]" }
        if {$params(verbose)} { puts " -W- setting guideline for control sets to '$guidelines(utilization.ctrlsets.uniq)'" }
      } else {
        # If this cannot be calculated (e.g the utilization metrics have not been run or else)
        # Then unset the guideline
        puts " -W- unsetting guideline for control sets due to some missing data for the computation"
        if {$params(debug)} { puts " -D- unique registers for control sets calculation: $guidelines(utilization.ctrlsets.uniq)" }
        if {$params(debug)} { puts " -D- available registers for control sets calculation: [getMetric utilization.clb.ff.avail]" }
        unset guidelines(utilization.ctrlsets.uniq)
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
      addMetric {design.cells.maxavgfo}   "Max Average Fanout for modules > [expr $limit / 1000]k cells"
      addMetric {design.cells.avgfo}      "Average Fanout for modules > [expr $limit / 1000]k cells"

      catch {unset data}
      # Key '-' holds the list of average fanout for modules > 100K ($limit)
      set data(-) [list 0]
      # Key '@' holds the list of hierarchical cells that have an average fanout for modules > 100K ($limit)
      set data(@) [list]
      set avgFO {n/a}
      switch $reportMode {
        pblockAndTop {
          set avgFO [calculateAvgFanoutTop . $limit]
        }
        pblockAndCell {
          set avgFO [calculateAvgFanoutTop $prCell $limit]
        }
        pblockOnly {
          # NOT SUPPORTED
        }
        regionAndTop {
          set avgFO [calculateAvgFanoutTop . $limit]
        }
        regionAndCell {
          set avgFO [calculateAvgFanoutTop $prCell $limit]
        }
        regionOnly {
          # NOT SUPPORTED
        }
        slrAndTop {
          set avgFO [calculateAvgFanoutTop . $limit]
        }
        slrAndCell {
          set avgFO [calculateAvgFanoutTop $prCell $limit]
        }
        slrOnly {
          # NOT SUPPORTED
        }
        default {
          set avgFO [calculateAvgFanoutTop . $limit]
        }
      }
      set maxfo [lindex [lsort -decreasing -real $data(-)] 0]

      setMetric {design.cells.maxavgfo}  $maxfo
      setMetric {design.cells.avgfo}     $avgFO
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

        if {$params(debug) && ($params(debug_level) >= 2)} {
          foreach line [split [$dbgtbl print] \n] {
            puts $FH "# $line"
          }
          puts $FH ""
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

      # Signal + local clock nets
      set nets [get_nets -quiet -top_net_of_hierarchical_group -segments -filter "(FLAT_PIN_COUNT >= $limit) && ((TYPE == SIGNAL) || (TYPE == LOCAL_CLOCK))" \
                 -of [get_pins -quiet -of $leafCells] ]
#       set drivers [get_pins -quiet -of $nets -filter {IS_LEAF && (REF_NAME !~ FD*) && (DIRECTION == OUT)}]
      set drivers [get_pins -quiet -leaf -of $nets -filter {(REF_NAME !~ FD*) && (DIRECTION == OUT)}]
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
#         $tbl header [list {Driver Type} {Driver Pin} {Net} {DONT_TOUCH} {MARK_DEBUG} {Fanout} ]
        if {$showSlackInsideDetailedReports} {
          $tbl header [list {Driver Type} {Driver Pin} {Net} {Type} {Slack} {DONT_TOUCH} {MARK_DEBUG} {Fanout} {Load Pins} ]
        } else {
          $tbl header [list {Driver Type} {Driver Pin} {Net} {Type} {DONT_TOUCH} {MARK_DEBUG} {Fanout} {Load Pins} ]
        }
        foreach pin $drivers {
          set refname [get_property -quiet {REF_NAME} $pin]
          set net [get_nets -quiet -of $pin]
          set fanout [expr [get_property -quiet FLAT_PIN_COUNT $net] -1]
          set type [get_property -quiet TYPE $net]
          set dt [get_property -quiet DONT_TOUCH $net]
          if {$dt == {}} { set dt 0 }
          set md [get_property -quiet MARK_DEBUG $net]
          if {$md == {}} { set md 0 }
#           $tbl addrow [list $refname $pin $net $dt $md $fanout ]
          # Extract the list of unique load pins
          set loads [get_pins -quiet -of_objects $net -leaf -filter {DIRECTION==IN}]
          catch {unset tmp}
          # Column "Load Pins" should report a distribution of the load pins:
          # E.g: FDCE/C (204730) FDPE/C (26) FDRE/C (130873) FDSE/C (5218) HARD_SYNC/CLK (1) RAMB36E2/CLKARDCLK (196)
          set uniqueLoads [list]
          foreach _pin $loads \
                  _refname [get_property -quiet REF_NAME $loads] \
                  _refpinname [get_property -quiet REF_PIN_NAME $loads] {
            incr tmp([format {%s/%s} $_refname $_refpinname])
          }
          foreach el [lsort -dictionary [array names tmp]] {
            lappend uniqueLoads [format {%s (%s)} $el $tmp($el)]
          }
          set uniqueLoads [join $uniqueLoads { }]
          if {$showSlackInsideDetailedReports} {
            set driver [get_pins -quiet -of_objects $net -leaf -filter {DIRECTION==OUT}]
            set slack [get_property -quiet SETUP_SLACK $driver]
            if {$slack == {}} { set slack {N/A} }
            $tbl addrow [list $refname $pin $net $type $slack $dt $md $fanout $uniqueLoads ]
          } else {
            $tbl addrow [list $refname $pin $net $type $dt $md $fanout $uniqueLoads ]
          }

          set empty 0
        }
        if {!$empty} { $tbl sort -Fanout +Net }
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
      set error 0
      switch $architecture {
        artix7 -
        kintex7 -
        virtex7 -
        spartan7 -
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
              puts " -W- speedgrade $speedgrade is not matching any expected value. Using default speedgrade values (LUT=$timBudgetPerLUT / Net=$timBudgetPerNet)."
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
              puts " -W- speedgrade $speedgrade is not matching any expected value. Using default speedgrade values (LUT=$timBudgetPerLUT / Net=$timBudgetPerNet)."
            }
          }
        }
        zynquplus -
        kintexuplus -
        virtexuplus -
        virtexuplus58g -
        virtexuplusHBM -
        zynquplusRFSOC {
          switch -regexp -- $speedgrade {
            "-1.*LV.*" {
              # US+ -1LV == US -1
              # Note: adjusted values from US -1 to match latest recommendations
              set timBudgetPerLUT 0.449
              set timBudgetPerNet 0.302
            }
            "-1.*" {
              set timBudgetPerLUT 0.350
              set timBudgetPerNet 0.239
            }
            "-2.*LV.*" {
              # US+ -2LV == US -2
              # Note: adjusted values from US -2 to match latest recommendations
              set timBudgetPerLUT 0.391
              set timBudgetPerNet 0.263
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
              puts " -W- speedgrade $speedgrade is not matching any expected value. Using default speedgrade values (LUT=$timBudgetPerLUT / Net=$timBudgetPerNet)."
            }
          }
        }
        versal {
          # Initial estimations: same values as for US+
          switch -regexp -- $speedgrade {
            "-1.*LP.*" {
              # Versal -1LP == US+ -1LV
              set timBudgetPerLUT 0.449
              set timBudgetPerNet 0.302
            }
            "-1.*MP.*" {
              set timBudgetPerLUT 0.350
              set timBudgetPerNet 0.239
            }
            "-2.*LP.*" {
              # Versal -2LP == US+ -2LV
              set timBudgetPerLUT 0.391
              set timBudgetPerNet 0.263
            }
            "-2.*MP.*" {
              set timBudgetPerLUT 0.300
              set timBudgetPerNet 0.208
            }
            "-3.*HP.*" {
              set timBudgetPerLUT 0.250
              set timBudgetPerNet 0.177
            }
            default {
              set timBudgetPerLUT 0.350
              set timBudgetPerNet 0.239
              puts " -W- speedgrade $speedgrade is not matching any expected value. Using default speedgrade values (LUT=$timBudgetPerLUT / Net=$timBudgetPerNet)."
            }
          }
        }
        default {
          puts " -E- architecture $architecture is not supported for LUT/Net budgeting. Skipped."
          incr error
        }
      }

      # Only run if the architecture is supported
      if {!$error} {
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
        $tbl header [list {Group} {Slack} {Requirement} {Skew} {Uncertainty} {Datapath Delay} {Datapath Logic Delay} {Datapath Net Delay} {Logic Levels} {Adj Levels} {Net Budget} {Lut Budget} {Net Adj Slack} {Lut Adj Slack} {Path} {Info} ]
        $dbgtbl header [list {Group} {Slack} {Requirement} {Skew} {Uncertainty} {Datapath Delay} {Datapath Logic Delay} {Datapath Net Delay} {Logic Levels} {Adj Levels} {Net Budget} {Lut Budget} {Net Adj Slack} {Lut Adj Slack} {Path} {Info} ]

        if {$architecture == {versal}} {
          # Add the column 'Cascaded LUTs'
          $tbl header [list {Group} {Slack} {Requirement} {Skew} {Uncertainty} {Datapath Delay} {Datapath Logic Delay} {Datapath Net Delay} {Cascaded LUTs} {Logic Levels} {Adj Levels} {Net Budget} {Lut Budget} {Net Adj Slack} {Lut Adj Slack} {Path} {Info} ]
          $dbgtbl header [list {Group} {Slack} {Requirement} {Skew} {Uncertainty} {Datapath Delay} {Datapath Logic Delay} {Datapath Net Delay} {Cascaded LUTs} {Logic Levels} {Adj Levels} {Net Budget} {Lut Budget} {Net Adj Slack} {Lut Adj Slack} {Path} {Info} ]
        }

        if {$timingPathsBudgeting != {}} {
          # For debug EOU, timnig paths can be passed from the command line
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
        set lutNetBudgetingPaths [list]
        # <== For Versal
        set numLutPairCASCMiss 0
        set numLutPairCASCCandidate 0
        set lutPairCASCMissPaths [list]
        set lutPairCASCFoundPaths [list]
        set lutPairCASCPaths [list]
        # ==>
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
          # E.g: FDRE(34) LUT5(2) LUT3(1) LUT6(1) FDRE
          set pathDescription [format {%s} [get_property -quiet REF_NAME $sp] ]
          # Number of LUT* in the datapath
#         set levels [llength [filter [get_cells -quiet -of $path] {REF_NAME =~ LUT*}]]
          # Versal improvement for LUTCY* support: to count the number of levels, count the number of LUT*
          # that are NOT driven by an intra-site net
          set levels 0
          # Cells/nets/pins: get_cells/get_nets/get_pins preserve the order in the timing path
          set cells [get_cells -quiet -of $path]
          set ref_names [get_property -quiet REF_NAME $cells]
          set nets [get_nets -quiet -of $path]
          # To construct the list of pins:
          #   - get_pins return both input and output pins of the timing path => filter to only keep output pins
          #   - only the output pin is needed for each cell, unless this is the destination cell which then requires the ENDPOINT_PIN ($ep)
          set pins [get_property -quiet {REF_PIN_NAME} [get_pins -quiet [list [get_pins -quiet -of $path -filter {direction == OUT}] $ep]] ]
          if {[llength $cells] != [llength $pins]} {
            if {[get_cells -quiet -of $sp] == [get_cells -quiet -of $ep]} {
              # If the startpoint and endpoint cells are the same, then 'get_cells -quiet -of $path' only returns
              # the cell for the startpoint. The cell for the endpoint needs to be added.
              lappend cells [lindex $cells 0]
            } else {
              # Something wrong happened ...
              puts " -W- LUT/Net budgeting - the number of pins ([llength $pins]) and cells ([llength $cells]) differ. Skipping path ($path)"
              continue
            }
          }
          # To iterate through $cells/$nets/$pins, we need to assiciate:
          #   - each net of the datapath => $nets
          #   - with its driver pin => lrange $pins 0 end-1
          #   - and its load => lrange $cells 1 end
          set prev1refname {}
          set prev2refname {}
          # lutPairStatus = 0 : the previous LUT was not part of a cascade
          #                     The current LUT can still be part of a LUT cascade
          # lutPairStatus = 1 : the previous LUT was part of a cascade
          #                     The current LUT CANNOT be part of a LUT cascade
          # lutPairStatus = 2 : the previous LUT could have been part of a cascade but was not.
          #                     The current LUT can still be part of a LUT cascade
          set lutPairStatus 0
          # Number of LUT cascades that have been missed in the timing path
          set lutPairCASCMiss 0
          # Number of candidates for LUT cascades found in the timing path
          set lutPairCASCCandidate 0
          if {$params(debug) && ($params(debug_level) >= 2)} {
            puts " -D- processing path $path"
            puts " -D- datapath: $ref_names"
          }
          foreach net $nets \
                  flat_pin_count [get_property -quiet FLAT_PIN_COUNT $nets] \
                  cell [lrange $cells 1 end] \
                  refname [get_property -quiet REF_NAME [lrange $cells 1 end]] \
                  pin [lrange $pins 0 end-1] {
#             set refname [get_property -quiet REF_NAME $cell]
            set fanout [expr $flat_pin_count -1]

            # Append pathDescription [format {(%s) %s} $fanout $refname]
            if {$architecture == {versal}} {
              # Cascaded LUTs are only for Versal
              set casc_mux {}
              if {[regexp {^LUT[1-6]$} $refname] && [regexp {^LUT[1-6]$} $prev1refname] && ($fanout == 1) && ($lutPairStatus == 0)} {
                set bel [get_bels -quiet -of $cell]
                set casc_mux [get_property -quiet CONFIG.CASC_MUX $bel]
                if {$casc_mux == {CASC}} {
                  # The LUT is cascaded with the previous LUT on the path
                  set lutPairStatus 1
                  set cascade {CASC}
                  incr lutPairCASCCandidate
                  incr numLutPairCASCCandidate
                } else {
                  # The LUT is NOT cascaded with the previous LUT on the path but
                  # could be still cascaded with the next LUT if the conditions are met.
                  # We are not tracking the LUT as a candidate for LUT cascade yet.
                  # This will be done when next cell on the timing path is analyzed.
                  set lutPairStatus 2
#                   incr lutPairCASCCandidate
#                   incr numLutPairCASCCandidate
#                   incr lutPairCASCMiss
#                   incr numLutPairCASCMiss
                }
              } elseif {[regexp {^LUT[1-6]$} $refname] && [regexp {^LUT[1-6]$} $prev1refname] && ($fanout == 1) && ($lutPairStatus == 2)} {
                set bel [get_bels -quiet -of $cell]
                set casc_mux [get_property -quiet CONFIG.CASC_MUX $bel]
                if {$casc_mux == {CASC}} {
                  # The LUT is cascaded with the previous LUT on the path
                  set lutPairStatus 1
                  incr lutPairCASCCandidate
                  incr numLutPairCASCCandidate
                } else {
                  # The LUT is NOT cascaded with the previous LUT on the path. Since lutPairStatus==2
                  # we need to track now that there was a candidate for cascaded LUT that was missed.
                  set lutPairStatus 0
                  incr lutPairCASCCandidate
                  incr numLutPairCASCCandidate
                  incr lutPairCASCMiss
                  incr numLutPairCASCMiss
                }
              } elseif {$lutPairStatus == 2} {
                # The previous LUT was NOT cascaded. Since lutPairStatus==2
                # we need to track now that there was a candidate for cascaded LUT that was missed.
                incr lutPairCASCCandidate
                incr numLutPairCASCCandidate
                incr lutPairCASCMiss
                incr numLutPairCASCMiss
                set lutPairStatus 0
              } elseif {![regexp {^LUT[1-6]$} $refname]} {
                set lutPairStatus 0
              } else {
                set lutPairStatus 0
              }

              if {$casc_mux == {CASC}} {
                # Cascaded LUT with the previous LUT on the path
                # E.g: FDRE(34) LUT5(2) LUT3(1) -CASC- LUT6(1) FDRE
                append pathDescription [format {(%s) -CASC- %s} $fanout $refname]
              } else {
                append pathDescription [format {(%s) %s} $fanout $refname]
              }
            } else {
              append pathDescription [format {(%s) %s} $fanout $refname]
            }

            if {[regexp {^LUT.*$} $refname]} {

#             if {[regexp -nocase {^(PROP|GE|COUTB|COUTD|COUTF|COUTH)$} $pin]} {}
              if {[regexp -nocase {^(PROP|GE|COUTB|COUTD|COUTF)$} $pin]} {
                # Versal: Attempt to detect which nets will be reported as intra-site after placement.
                # If the output LUT pin is PROP or GE, then the driving net should be intra-site.
                # If the LUTCY* is driven by LOOKAHEAD/COUT* then it is also an intra-site.
                # Note: LOOKAHEAD/COUTH always connects to a routing resource going outside of the slice => removed from the list
                if {$params(debug) && ($params(debug_level) >= 2)} {
                  puts " -D- net $net driving $refname: * -> INTRASITE (driver pin $pin)"
                }
                # Intra-site net. Do nothing
                # Keep track of the REF_NAME from the previous 2 stages
                set prev2refname $prev1refname
                set prev1refname $refname
                continue
              }

              switch -nocase [get_property -quiet ROUTE_STATUS $net] {
                INTRA_SITE -
                INTRASITE {
                  # Intra-site net. Do nothing
                  if {$params(debug) && ($params(debug_level) >= 2)} {
                    puts " -D- net $net driving $refname: INTRASITE"
                  }
                }
                UNPLACED {
                  # After opt_design, intra-site nets are reported as UNPLACED instead of INTRASITE
#                 if {[regexp -nocase {^(PROP|GE|COUTB|COUTD|COUTF|COUTH)$} $pin]} {}
                  if {[regexp -nocase {^(PROP|GE|COUTB|COUTD|COUTF)$} $pin]} {
                    # Versal: Attempt to detect which nets will be reported as intra-site after placement.
                    # If the output LUT pin is PROP or GE, then the driving net should be intra-site.
                    # If the LUTCY* is driven by LOOKAHEAD/COUT* then it is also an intra-site.
                    if {$params(debug) && ($params(debug_level) >= 2)} {
                      puts " -D- net $net driving $refname: UNPLACED -> INTRASITE (driver pin $pin)"
                    }
                    # Intra-site net. Do nothing
                  } elseif {[regexp -nocase {^LUTCY.*$} $refname] && [regexp -nocase {^LUTCY.*$} $prev1refname] && [regexp -nocase {^LUTCY.*$} $prev2refname]} {
                    # Versal: when 3 LUTCY* are cascaded, the assumption is that they will be placed in to 2 different slices
                    # and therefore the net being processed should not be considered as intra-site.
                    # If the net connected to the cell is not intra-site, then increase the level number
                    if {$params(debug) && ($params(debug_level) >= 2)} {
                      puts " -D- net $net driving $refname: UNPLACED"
                    }
                    incr levels
                  } elseif {[regexp -nocase {^LUTCY.*$} $refname] && [regexp -nocase {^LUTCY.*$} $prev1refname] && ![regexp -nocase {^LUTCY.*$} $prev2refname]} {
                    # Versal: nets between 2 cascaded LUTCY* are considered intra-site. Beyond 2, the net is not
                    # considered anymore intra-site.
                    if {$params(debug) && ($params(debug_level) >= 2)} {
                      puts " -D- net $net driving $refname: UNPLACED -> INTRASITE (cascaded LUTCY)"
                    }
                  } else {
                    # If the net connected to the cell is not intra-site, then increase the level number
                    if {$params(debug) && ($params(debug_level) >= 2)} {
                      puts " -D- net $net driving $refname: UNPLACED"
                    }
                    incr levels
                  }
                }
                UNROUTED {
                  # If the net connected to the cell is not intra-site, then increase the level number
                  if {$params(debug) && ($params(debug_level) >= 2)} {
                    puts " -D- net $net driving $refname: UNROUTED"
                  }
                  incr levels
                }
                ROUTED {
                  # If the net connected to the cell is not intra-site, then increase the level number
                  if {$params(debug) && ($params(debug_level) >= 2)} {
                    puts " -D- net $net driving $refname: ROUTED"
                  }
                  incr levels
                }
                default {
                  # If the net connected to the cell is not intra-site, then increase the level number
                  if {$params(debug) && ($params(debug_level) >= 2)} {
                    puts " -D- net $net driving $refname: UNKNOWN"
                  }
                  incr levels
                }
              }
#             if {[regexp {(INTRASITE|INTRA_SITE)} [get_property -quiet ROUTE_STATUS $net]]} {
#               # Intra-site net. Do nothing
#             } else {
#               # If the net connected to the cell is not intra-site, then increase the level number
#               incr levels
#            }
            }
            # Keep track of the REF_NAME from the previous 2 stages
            set prev2refname $prev1refname
            set prev1refname $refname
          }
          if {$params(debug) && ($params(debug_level) >= 2)} {
            puts " -D- level calculation based on LUTs/Nets: $levels"
          }

          if {![regexp {^FD} $spref] && ![regexp {^LD} $spref]} {
            # If the startpoint is not an FD* or a LD*, then account for it by increasing the number of levels
            incr levels
            if {$params(debug) && ($params(debug_level) >= 2)} {
              puts " -D- level increase: startpoint not a FD or LD"
            }
          }
#         if {!([regexp {^FD} $epref] && ([get_property -quiet REF_PIN_NAME $ep] == {D}))} {
#           # If the endpoint is not an FD*/D, then account for it by increasing the number of levels
#           incr levels
#         }
          # The endpoint needs more processing
          if {[regexp {^[LF]D} $epref]} {
            if {[get_property -quiet REF_PIN_NAME $ep] != {D}} {
              # If the endpoint is not an FD*/D, then account for it by increasing the number of levels
              if {$params(debug) && ($params(debug_level) >= 2)} {
                puts " -D- level increase: endpoint pin not D"
              }
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
                  if {$params(debug) && ($params(debug_level) >= 2)} {
                    puts " -D- level increase: fanout before endpoint"
                  }
                  incr levels
                }
              }
            }
          } else {
            # If the endpoint is not a register/latch, then increase the number of levels
            if {$params(debug) && ($params(debug_level) >= 2)} {
              puts " -D- level increase: endpoint not a FD or LD"
            }
            incr levels
          }

          if {$architecture == {versal}} {
            # Sequential loop when the startpoint and endpoints share the same clock pin: skew optimization
            # is not possible => 1 logic level penalty
            if {$spref == $epref} {
              if {[get_property -quiet PARENT_CELL $sp] == [get_property -quiet PARENT_CELL $ep]} {
                if {[get_property -quiet STARTPOINT_CLOCK $path] == [get_property -quiet ENDPOINT_CLOCK $path]} {
                  if {$params(debug) && ($params(debug_level) >= 2)} {
                    puts " -D- level increase: sequential loop"
                  }
                  incr levels
                }
              }
            }
          }

          if {$params(debug) && ($params(debug_level) >= 2)} {
            puts " -D- level calculation after startpoint/endpoint adjustment: $levels"
          }

          # Calculate the maximum number of LUTs based on path requirement, skew and uncertainty
          # int(): truncate (e.g 1.8 => 1)
          # round() : round to the nearest (e.g 1.8 => 2)
          set lut_budget [expr int(($requirement + $skew - $uncertainty) / double($timBudgetPerLUT)) ]
#         set lut_budget [expr round(($requirement + $skew - $uncertainty) / double($timBudgetPerLUT)) ]
          set lut_adjSlack [expr $slack + $datapath_delay - ($levels * $timBudgetPerLUT)]
          # Calculate the maximum number of Nets based on path requirement, skew, uncertainty and logic cell delay
          set net_budget [expr int(($requirement + $skew - $uncertainty - $cell_delay) / double($timBudgetPerNet)) ]
#         set net_budget [expr round(($requirement + $skew - $uncertainty - $cell_delay) / double($timBudgetPerNet)) ]
          set net_adjSlack [expr $slack + $net_delay - ($levels * $timBudgetPerNet)]
          # Calculate the maximum datapath based on path requirement, skew and uncertainty
          set datapath_budget [format {%.3f} [expr double($lut_budget) * double($timBudgetPerLUT)] ]
#         if {$datapath_budget > [expr $requirement + $skew - $uncertainty]} {}

          # Debug table for LUT/Net budgeting
          set row [list $group $slack $requirement $skew $uncertainty $datapath_delay $cell_delay $net_delay $logic_levels $levels]
          if {$architecture == {versal}} {
            # Number of used cascaded LUTs: expr $lutPairCASCCandidate - $lutPairCASCMiss
            set row [list $group $slack $requirement $skew $uncertainty $datapath_delay $cell_delay $net_delay [format {%s / %s} [expr $lutPairCASCCandidate - $lutPairCASCMiss] $lutPairCASCCandidate ] $logic_levels $levels]
          } else {
            set row [list $group $slack $requirement $skew $uncertainty $datapath_delay $cell_delay $net_delay $logic_levels $levels]
          }

          # Save the timing path to the corresponding lists
          if {$showAllBudgetingPaths} {
            if {$lutPairCASCMiss > 0} {
              lappend lutPairCASCMissPaths $path
            }
            if {$lutPairCASCCandidate > 0} {
              lappend lutPairCASCPaths $path
            }
            if {[expr $lutPairCASCCandidate - $lutPairCASCMiss] > 0} {
              lappend lutPairCASCFoundPaths $path
            }
            lappend lutNetBudgetingPaths $path
          } else {
            if {($levels > $net_budget && $net_adjSlack < 0) ||
                ($levels > $lut_budget && $lut_adjSlack < 0)} {
              # Only save the paths when the LUT or NET budgeting is violated
              if {$lutPairCASCMiss > 0} {
                lappend lutPairCASCMissPaths $path
              }
              if {$lutPairCASCCandidate > 0} {
                lappend lutPairCASCPaths $path
              }
              if {[expr $lutPairCASCCandidate - $lutPairCASCMiss] > 0} {
                lappend lutPairCASCFoundPaths $path
              }
              lappend lutNetBudgetingPaths $path
            }
          }

          # Adding condition "$net_adjSlack < 0" in the test below
          if {$levels > $net_budget && $net_adjSlack < 0} {
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
          # Adding condition "$lut_adjSlack < 0" in the test below
          if {$levels > $lut_budget && $lut_adjSlack < 0} {
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
          lappend row [format %.3f $net_adjSlack]
          lappend row [format %.3f $lut_adjSlack]
          # Debug table for LUT/Net budgeting
#           lappend row [get_property -quiet REF_NAME [get_cells -quiet -of $path]]
          lappend row $pathDescription
          lappend row $path
          if {$addrow} {
            # Add row to the summary table
            $tbl addrow $row
          }
          $dbgtbl addrow $row
        }

        set params(lutPairCASCMissedPaths) $lutPairCASCMissPaths
        set params(lutPairCASCFoundPaths) $lutPairCASCFoundPaths
        set params(lutPairCASCPaths) $lutPairCASCPaths
#         if {$params(verbose)} {
#           if {[llength $lutPairCASCMissPaths]} { catch { report_timing -quiet -of $lutPairCASCMissPaths -name lutPairCASCMissPaths } }
#           if {[llength $lutPairCASCFoundPaths]} { catch { report_timing -quiet -of $lutPairCASCFoundPaths -name lutPairCASCFoundPaths } }
#           if {[llength $lutPairCASCPaths]} { catch { report_timing -quiet -of $lutPairCASCPaths -name lutPairCASCPaths } }
#         }
        switch $params(return_paths) {
          path_budgeting {
            set params(paths) $lutNetBudgetingPaths
          }
          lut_pair_missed {
            set params(paths) $lutPairCASCMissPaths
          }
          lut_pair_found {
            set params(paths) $lutPairCASCFoundPaths
          }
          lut_pair_candidate {
            set params(paths) $lutPairCASCPaths
          }
          none {

          }
          default {

          }
        }

        if {$params(debug)} {
          # Debug table for LUT/Net budgeting
          set output [concat $output [split [$dbgtbl print] \n] ]
#           catch {$dbgtbl destroy}
          puts [join $output \n]
          set output [list]
          puts " -D- Number of processed paths: [llength $spaths]"
          puts " -D- Number of paths that fail the LUT budgeting but pass the Net budgeting: $numFailedLutPassNet"
          puts " -D- Number of paths that fail the Net budgeting but pass the LUT budgeting: $numFailedNetPassLut"
        }
        if {$showAllBudgetingPaths} {
          # Show all paths analyzed for the LUT/Net budgeting. Replace the table with debug table
          set tbl $dbgtbl
          set emptyLut 0
          set emptyNet 0
        }
        setMetric {design.device.maxlvls.lut}  $numFailedLut
        setMetric {design.device.maxlvls.net}  $numFailedNet
        set stepStopTime [clock seconds]
        puts " -I- path budgeting metrics completed in [expr $stepStopTime - $stepStartTime] seconds"
        if {$detailedReportsPrefix != {}} {
          if {$FHLut != {}} { close $FHLut }
          if {$FHNet != {}} { close $FHNet }
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
            puts $FHLut "# Note: (*): failed the budgeting"
            if {$architecture == {versal}} {
              puts $FHLut "# Note: Cascaded LUTs: Used / Available"
            }
            puts $FHLut ""
            while {![eof $FH]} {
              gets $FH line
              puts $FHLut $line
            }
            close $FHLut
            close $FH
            file delete -force ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_LUT.rpt.${pid}
#           file rename -force ${detailedReportsPrefix}.timing_budget_LUT.rpt.${pid} ${detailedReportsPrefix}.timing_budget_LUT.rpt
            puts " -I- Generated file [file normalize ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_LUT.rpt]"
            $tbl export -format csv -file ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_LUT.csv
            puts " -I- Generated file [file normalize ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_LUT.csv]"
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
            puts $FHNet "# Note: (*): failed the budgeting"
            if {$architecture == {versal}} {
              puts $FHNet "# Note: Cascaded LUTs: Used / Available"
            }
            puts $FHNet ""
            while {![eof $FH]} {
              gets $FH line
              puts $FHNet $line
            }
            close $FHNet
            close $FH
            file delete -force ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_Net.rpt.${pid}
#           file rename -force ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_Net.rpt.${pid} ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_Net.rpt
            puts " -I- Generated file [file normalize ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_Net.rpt]"
            $tbl export -format csv -file ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_Net.csv
            puts " -I- Generated file [file normalize ${detailedReportsDir}/${detailedReportsPrefix}.timing_budget_Net.csv]"
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
        catch {$dbgtbl destroy}
      }

    } else {
      set timBudgetPerLUT {}
      set timBudgetPerNet {}
    }

    ########################################################################################
    ##
    ## Rent metric
    ##
    ########################################################################################

    if {1 && ([llength [array names guidelines design.rent]] == 1) && ([lsearch $skipChecks {rent}] == -1)} {
      set stepStartTime [clock seconds]
      addMetric {design.rent}   "Top-level rent"

      switch $reportMode {
        pblockAndTop {
        }
        pblockAndCell {
        }
        pblockOnly {
          # NOT SUPPORTED
        }
        regionAndTop {
        }
        regionAndCell {
        }
        regionOnly {
          # NOT SUPPORTED
        }
        slrAndTop {
        }
        slrAndCell {
        }
        slrOnly {
          # NOT SUPPORTED
        }
        default {
        }
      }

      set report [getReport report_design_analysis -quiet -complexity -hierarchical_depth 0 -return_string]

      set tbl [extractTables $report]
      if {[llength $tbl] == 1} {
        # There should be only 1 table:
        #   +---------------+------------------------+------+----------------+-----------------+-----------+-----------+------------+-----------+-----------+-----------+------------+------------+-----+------+------+------+
        #   | Instance      | Module                 | Rent | Average Fanout | Total Instances | Registers | LUT1      | LUT2       | LUT3      | LUT4      | LUT5      | LUT6       | Memory LUT | DSP | RAMB | MUXF | URAM |
        #   +---------------+------------------------+------+----------------+-----------------+-----------+-----------+------------+-----------+-----------+-----------+------------+------------+-----+------+------+------+
        #   | (top)         | my_ip_exdes            | 0.77 | 1.37           | 5971            | 5094      | 51(7.2%)  | 201(28.6%) | 60(8.5%)  | 69(9.8%)  | 65(9.2%)  | 258(36.6%) | 128        | 0   | 0    | 0    | 0    |
        #   | DUT           | my_ip                  | 0.98 | 1.21           | 3830            | 3608      | 34(17.4%) | 38(19.5%)  | 36(18.5%) | 25(12.8%) | 22(11.3%) | 40(20.5%)  | 0          | 0   | 0    | 0    | 0    |
        #   | i_pkt_gen_mon | my_ip_lbus_pkt_gen_mon | 0.18 | 1.82           | 2130            | 1486      | 17(3.3%)  | 163(32.0%) | 24(4.7%)  | 44(8.6%)  | 43(8.4%)  | 218(42.8%) | 128        | 0   | 0    | 0    | 0    |
        #   +---------------+------------------------+------+----------------+-----------------+-----------+-----------+------------+-----------+-----------+-----------+------------+------------+-----+------+------+------+
        set header [$tbl header]
        set idx [lsearch -nocase $header {Rent}]
        if {$idx != -1} {
          set rent [lindex [lsort -real -decreasing [$tbl getcolumns $idx]] 0]
        } else {
          set rent {n/a}
        }

      } else {
        set rent {n/a}
      }

      setMetric {design.rent}  $rent
      set stepStopTime [clock seconds]
      puts " -I- rent metric completed in [expr $stepStopTime - $stepStartTime] seconds"
    }

    ########################################################################################
    ##
    ## User custom metrics
    ##
    ########################################################################################

    if {[llength $userCustomMetricsFiles] && ([lsearch $skipChecks {custom_metrics}] == -1)} {
      # Rename procs for user EoU
      rename addMetric addMetric_ORG
      rename setMetric setMetric_ORG
      rename addCustomMetric addMetric
      rename setCustomMetric setMetric
      foreach file $userCustomMetricsFiles {
        if {$params(verbose)} {
          puts " -I- sourcing custom metrics file '[file normalize $file]"
        }
        if {[catch "source $file" errorstring]} {
          puts " -E- the following error happened by sourcing '[file normalize $file']. Some custom metrics might not be extracted."
          puts " -E- $errorstring"
        }
      }
      rename addMetric addCustomMetric
      rename setMetric setCustomMetric
      rename addMetric_ORG addMetric
      rename setMetric_ORG setMetric
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
    #   | DSP                                                       | 80%       | 24.52% | 253    | 1032   | OK     |
    #   | RAMB/FIFO                                                 | 80%       | 7.20%  | 28.5   | 396    | OK     |
    #   | DSP+RAMB+URAM (Avg)                                       | 70%       | 15.86% | -      | -      | OK     |
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
  generateTableRow tbl {utilization.clb.lut.pct}        {LUT}
  generateTableRow tbl {design.cells.lut456.pct}        {LUT4/5/6}
  generateTableRow tbl {design.cells.lut56.pct}         {LUT5/6}
  generateTableRow tbl {utilization.clb.ff.pct}         {FD}
  generateTableRow tbl {utilization.clb.ld}             {LD}
  generateTableRow tbl {utilization.clb.lutmem.pct}     {LUTRAM+SRL}
  generateTableRow tbl {utilization.clb.carry8.pct}     {CARRY8}
  generateTableRow tbl {utilization.clb.lookahead8.pct} {LOOKAHEAD8}
  generateTableRow tbl {utilization.clb.f7mux.pct}      {MUXF7}
  generateTableRow tbl {utilization.clb.f8mux.pct}      {MUXF8}
  generateTableRow tbl {design.cells.hlutnm.pct}        {LUT Combining}
  generateTableRow tbl {utilization.dsp.pct}            {DSP}
#   generateTableRow tbl {utilization.ram.tile.pct}       {RAMB/FIFO}
  set architecture [get_property -quiet ARCHITECTURE [get_property -quiet PART [current_design]]]
  switch $architecture {
    versal {
      generateTableRow tbl {utilization.ram.tile.pct}       {RAMB}
    }
    default {
      generateTableRow tbl {utilization.ram.tile.pct}       {RAMB/FIFO}
    }
  }
  generateTableRow tbl {utilization.uram.tile.pct}      {URAM}
  generateTableRow tbl {utilization.bigblocks.pct}      {DSP+RAMB+URAM (Avg)}
  generateTableRow tbl {utilization.clk.all}            {BUFGCE* + BUFGCTRL}
  generateTableRow tbl {design.dont_touch}              {DONT_TOUCH (cells/nets)}
  generateTableRow tbl {design.mark_debug}              {MARK_DEBUG (nets)}
  generateTableRow tbl {utilization.ctrlsets.uniq}      {Control Sets}
  if {[llength [array names guidelines design.cells.avgfo]] == 1} {
#     generateTableRow tbl {design.cells.avgfo}      {Average Fanout for modules > 100k cells}
    generateTableRow tbl {design.cells.avgfo}         "Average Fanout for modules > [expr $guidelines(design.cells.maxavgfo.limit) / 1000]k cells"
  }
  if {[llength [array names guidelines design.cells.maxavgfo*]] == 2} {
#     generateTableRow tbl {design.cells.maxavgfo}      {Max Average Fanout for modules > 100k cells}
    generateTableRow tbl {design.cells.maxavgfo}      "Max Average Fanout for modules > [expr $guidelines(design.cells.maxavgfo.limit) / 1000]k cells"
  }
  if {[llength [array names guidelines design.nets.nonfdhfn*]] == 2} {
#     generateTableRow tbl {design.nets.nonfdhfn}       {Non-FD high fanout nets > 10k loads}
    generateTableRow tbl {design.nets.nonfdhfn}       "Non-FD high fanout nets > [expr $guidelines(design.nets.nonfdhfn.limit) / 1000]k loads"
  }
  if {[llength [array names guidelines design.rent]] == 1} {
    generateTableRow tbl {design.rent}                "Rent"
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

  # User custom metrics
  if {[llength [array names guidelines custom*.*]]} {
    $tbl separator
    set prevSuffix {UNSET}
    foreach metric [lsort -dictionary [array names guidelines custom*.*]] {
      if {[regexp {\.avail} $metric]} {
        # Skip xxx.avail metrics since they only hold the available resources for that metric
        continue
      }
      regexp {^custom([0-9]*)\.} $metric - suffix
      if {($prevSuffix != {UNSET}) && ($prevSuffix != $suffix)} {
        # Add a row separator when changing section of custum metrics (e.g custom1.* -> custom2.*)
        $tbl separator
      }
      set prevSuffix $suffix
      generateTableRow tbl $metric $metrics(${metric}:description)
    }
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
  $tblcsv addrow [list {design.part}                    {Part}               [getMetric {design.part}] ]
  $tblcsv addrow [list {design.top}                     {Top}                [get_property -quiet TOP [current_design -quiet]] ]
  $tblcsv addrow [list {design.run.pr.cell}             {PR (Cell)}          $prCell ]
  $tblcsv addrow [list {design.run.pr.pblock}           {PR (Pblock)}        $prPblock ]
  $tblcsv addrow [list {design.run.slr}                 {SLR-Level Analysis} $slrs ]
  $tblcsv addrow [list {design.run.regions}             {Clock Regions} $regions ]
  $tblcsv addrow [list {utilization.clb.lut}            {LUT(#)}             [getMetric {utilization.clb.lut}] ]
  $tblcsv addrow [list {utilization.clb.ff}             {FD(#)}              [getMetric {utilization.clb.ff}] ]
  $tblcsv addrow [list {utilization.ram.tile}           {RAMB/FIFO(#)}       [getMetric {utilization.ram.tile}] ]
  $tblcsv addrow [list {utilization.uram.tile}          {URAM(#)}            [getMetric {utilization.uram.tile}] ]
  $tblcsv addrow [list {utilization.dsp}                {DSP(#)}           [getMetric {utilization.dsp}] ]
  $tblcsv addrow [list {design.failure}                 {Criteria to review} $params(failed) ]
  $tblcsv addrow [list {utilization.clb.lut.pct}        {LUT(%)}                [getMetric {utilization.clb.lut.pct}] ]
  $tblcsv addrow [list {utilization.clb.ff.pct}         {FD(%)}                 [getMetric {utilization.clb.ff.pct}] ]
  $tblcsv addrow [list {utilization.clb.lutmem.pct}     {LUTRAM+SRL(%)}         [getMetric {utilization.clb.lutmem.pct}] ]
  $tblcsv addrow [list {utilization.clb.carry8.pct}     {CARRY8(%)}             [getMetric {utilization.clb.carry8.pct}] ]
  $tblcsv addrow [list {utilization.clb.lookahead8.pct} {LOOKAHEAD8(%)}         [getMetric {utilization.clb.lookahead8.pct}] ]
  $tblcsv addrow [list {utilization.clb.f7mux.pct}      {MUXF7(%)}              [getMetric {utilization.clb.f7mux.pct}] ]
  $tblcsv addrow [list {utilization.clb.f8mux.pct}      {MUXF8(%)}              [getMetric {utilization.clb.f8mux.pct}] ]
  $tblcsv addrow [list {design.cells.hlutnm.pct}        {LUT Combining(%)}      [getMetric {design.cells.hlutnm.pct}] ]
  $tblcsv addrow [list {utilization.dsp.pct}            {DSP(%)}                [getMetric {utilization.dsp.pct}] ]
  $tblcsv addrow [list {utilization.ram.tile.pct}       {RAMB/FIFO(%)}          [getMetric {utilization.ram.tile.pct}] ]
  $tblcsv addrow [list {utilization.uram.tile.pct}      {URAM(%)}               [getMetric {utilization.uram.tile.pct}] ]
  $tblcsv addrow [list {utilization.bigblocks.pct}      {DSP+RAMB+URAM (Avg)(%)}       [getMetric {utilization.bigblocks.pct}] ]
  $tblcsv addrow [list {utilization.clk.all}            {BUFGCE* + BUFGCTRL} [getMetric {utilization.clk.all}] ]
  $tblcsv addrow [list {utilization.ctrlsets.uniq}      {Control Sets}       [getMetric {utilization.ctrlsets.uniq}] ]
  $tblcsv addrow [list {design.dont_touch}              {DONT_TOUCH(#)}      [getMetric {design.dont_touch}] ]
  $tblcsv addrow [list {design.mark_debug}              {MARK_DEBUG(#)}      [getMetric {design.mark_debug}] ]
  if {[llength [array names guidelines design.cells.avgfo]] == 1} {
    $tblcsv addrow [list {design.cells.avgfo}         "Average Fanout for modules > [expr $guidelines(design.cells.maxavgfo.limit) / 1000]k cells" [getMetric {design.cells.avgfo}] ]
  }
  if {[llength [array names guidelines design.cells.maxavgfo*]] == 2} {
    $tblcsv addrow [list {design.cells.maxavgfo}      "Max Average Fanout for modules > [expr $guidelines(design.cells.maxavgfo.limit) / 1000]k cells" [getMetric {design.cells.maxavgfo}] ]
  }
  if {[llength [array names guidelines design.nets.nonfdhfn*]] == 2} {
    $tblcsv addrow [list {design.nets.nonfdhfn}       "Non-FD high fanout nets > [expr $guidelines(design.nets.nonfdhfn.limit) / 1000]k loads"     [getMetric {design.nets.nonfdhfn}] ]
  }
  if {[llength [array names guidelines design.rent]] == 1} {
    $tblcsv addrow [list {design.rent}                "Rent"   [getMetric {design.rent}] ]
  }
  $tblcsv addrow [list {methodology.timing-6}       {TIMING-6}           [getMetric {methodology.timing-6}] ]
  $tblcsv addrow [list {methodology.timing-7}       {TIMING-7}           [getMetric {methodology.timing-7}] ]
  $tblcsv addrow [list {methodology.timing-8}       {TIMING-8}           [getMetric {methodology.timing-8}] ]
  $tblcsv addrow [list {methodology.timing-14}      {TIMING-14}          [getMetric {methodology.timing-14}] ]
  $tblcsv addrow [list {methodology.timing-35}      {TIMING-35}          [getMetric {methodology.timing-35}] ]
  $tblcsv addrow [list {design.device.maxlvls.lut}  "Number of paths above max LUT budgeting ${timBudgetPerLUT}ns" [getMetric {design.device.maxlvls.lut}] ]
  $tblcsv addrow [list {design.device.maxlvls.net}  "Number of paths above max Net budgeting ${timBudgetPerNet}ns" [getMetric {design.device.maxlvls.net}] ]

  # User custom metrics
  if {[llength [array names guidelines custom*.*]]} {
    foreach metric [lsort -dictionary [array names guidelines custom*.*]] {
      if {[regexp {\.avail} $metric]} {
        # Skip xxx.avail metrics since they only hold the available resources for that metric
        continue
      }
      $tblcsv addrow [list $metric $metrics(${metric}:description) [getMetric $metric] ]
    }
  }

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

  # Restore tcl.collectionResultDisplayLimit
  set_param tcl.collectionResultDisplayLimit $collectionResultDisplayLimit

  # Timing paths to be returned?
  switch $params(return_paths) {
    lut_pair_missed -
    lut_pair_found -
    lut_pair_candidate -
    path_budgeting {
      return $params(paths)
    }
    none {
    }
    default {
    }
  }

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

  # Threshold (PASS) for LOOKAHEAD8
  set guidelines(utilization.clb.lookahead8.pct)  {<=25%}

  # Threshold (PASS) for MUXF7
  set guidelines(utilization.clb.f7mux.pct)       {<=15%}

  # Threshold (PASS) for MUXF8
#   set guidelines(utilization.clb.f8mux.pct)       {<=7%}

  # Threshold (PASS) for LUT Combining (HLUTNM)
  set guidelines(design.cells.hlutnm.pct)         {<=20%}

  # Threshold (PASS) for DSP
  set guidelines(utilization.dsp.pct)             {<=80%}

  # Threshold (PASS) for RAMB36/FIFO36
  set guidelines(utilization.ram.tile.pct)        {<=80%}

  # Threshold (PASS) for URAM
  set guidelines(utilization.uram.tile.pct)        {<=80%}

  # Threshold (PASS) for DSP+RAMB38+URAM (average)
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

  # Threshold (PASS) for MARK_DEBUG properties
  set guidelines(design.mark_debug)               "=0"

  # Limit for 'Max Average Fanout for modules > ...k cells' calculation
  set guidelines(design.cells.maxavgfo.limit)     {100000}

  # Threshold (PASS) for Max Average Fanout for modules > 100k cells
  set guidelines(design.cells.maxavgfo)           {<=4}

  # Threshold (PASS) for Average Fanout for modules > 100k cells
  set guidelines(design.cells.avgfo)              {<=4}

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

  # Threshold (PASS) for LUT4 + LUT5 + LUT6
#   set guidelines(design.cells.lut456.pct)         {<=80%}

  # Threshold (PASS) for LUT5 + LUT6
#   set guidelines(design.cells.lut56.pct)          {<=70%}

  # Threshold (PASS) for top-level rent
#   set guidelines(design.rent)                     {<=0.85}

  return -code ok
}

proc ::tclapp::xilinx::designutils::report_failfast::calculateAvgFanoutTop {cell minCellCount} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  variable params
  variable dbgtbl
  set dbgtbl [::tclapp::xilinx::designutils::prettyTable create]
  $dbgtbl indent 1
  $dbgtbl header [list {Cell} {Primitives} {Pins} {Flat Pin Count} {Avg Fanout} ]
  set avgFO [calculateAvgFanout $cell $minCellCount]
  $dbgtbl title [format "Cell: %s\nAvg Fanout: %s\nMin Cell Count: %s" $cell $avgFO $minCellCount]
  if {$params(debug) && ($params(debug_level) >= 2)} {
    puts [$dbgtbl print]
  }
  # Do not clear the table as it can be saved inside the detailed report
#   $dbgtbl cleartable
  return $avgFO
}

proc ::tclapp::xilinx::designutils::report_failfast::calculateAvgFanout {cell minCellCount} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

# puts "entering calculateAvgFanout ([clock format [clock seconds]]): $cell"
  variable data
  variable dbgtbl
  variable params
  set current [current_instance -quiet .]
  set avgFanout 0.0
  # Catch any potential TCL_ERROR from too many nested loops
  if {[catch {
    current_instance -quiet
    current_instance -quiet $cell
    set hierCells [lsort [get_cells -quiet -filter {!IS_PRIMITIVE}]]
    # All the primitives from this level down
    set hierPrimitives [get_cells -quiet -hier -filter "(IS_PRIMITIVE && REF_NAME !~ BUFG* && REF_NAME !~ VCC && REF_NAME !~ GND)"]
    set count 0
    set skipped 0
    foreach c $hierCells {
      incr count
      # For runtime optimization, extract the list of primitives for the hierachical module $c
      # set primitives [get_cells -quiet -hier -filter "NAME=~$c/* && (IS_PRIMITIVE && REF_NAME !~ BUFG* && REF_NAME !~ VCC && REF_NAME !~ GND)"]
      # set primitives [filter -quiet $hierPrimitives "NAME=~$c/*"]
      set primitives [lsearch -all -inline -glob $hierPrimitives $c/*]
      # For runtime optimization, if the sub-hierarchy $c has less primitives than $minCellCount,
      # then compute the stats for the module without diving into it. This is a major runtime saving
      # when the module has 1000s of very small sub-hierarchies
      if {[llength $primitives] < $minCellCount} {
        set opins [get_pins -quiet -of $primitives -filter {!IS_CLOCK && DIRECTION == OUT && IS_CONNECTED}]
        set nets [get_nets -quiet -of $opins -segments -top_net_of_hierarchical_group -filter {(FLAT_PIN_COUNT > 1) && (TYPE == SIGNAL)}]
        set numPins [llength $opins]
        set data(${c}:PIN_COUNT) 0
        catch { set data(${c}:PIN_COUNT) [expr [join [get_property -quiet FLAT_PIN_COUNT $nets] +] ] }
        set data(${c}:OPINS) $numPins
        set data(${c}:PRIMITIVES) [llength $primitives]
        set data(${c}:AVG_FANOUT) 0.0
        catch { set data(${c}:AVG_FANOUT) [format {%.2f} [expr ((1.0 * $data(${c}:PIN_COUNT) - $numPins) / $numPins ] ] }
        set data(${c}:FLAT_PIN_COUNT) $data(${c}:PIN_COUNT)
        set data(${c}:FLAT_OPINS) $data(${c}:OPINS)
        set data(${c}:FLAT_PRIMITIVES) $data(${c}:PRIMITIVES)
        set data(${c}:FLAT_AVG_FANOUT) $data(${c}:AVG_FANOUT)
        incr skipped
        # Skip this hierarchical module
        continue
      }
      calculateAvgFanout $c $minCellCount
    }

    set primitives [get_cells -quiet -filter {IS_PRIMITIVE && REF_NAME !~ BUFG* && REF_NAME !~ VCC && REF_NAME !~ GND}]
    set opins [get_pins -quiet -of $primitives -filter {!IS_CLOCK && DIRECTION == OUT && IS_CONNECTED}]
    # Uniquify the nets
    set nets [get_nets -quiet -of $opins -segments -top_net_of_hierarchical_group -filter {(FLAT_PIN_COUNT > 1) && (TYPE == SIGNAL)}]
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
    # Save data from current cell inside the debug table
    if {$params(debug) && ($params(debug_level) == 2)} {
      if {$numPrimitives > $minCellCount} {
        $dbgtbl addrow [list $cell $numPrimitives $numPins $totalFlatPinCount $avgFanout ]
      }
    } elseif {$params(debug) && ($params(debug_level) >= 3)} {
      if {$numPrimitives > $minCellCount} {
        $dbgtbl addrow [list $cell $numPrimitives $numPins $totalFlatPinCount "$avgFanout (*)" ]
      } else {
        $dbgtbl addrow [list $cell $numPrimitives $numPins $totalFlatPinCount $avgFanout ]
      }
    }

    if {$numPrimitives > $minCellCount} {
      lappend data(-) $avgFanout
      lappend data(@) $cell
  #     puts "$cell / numPrimitives=$numPrimitives / avgFanout=$avgFanout"
    }

  } errorstring]} {
    puts " -E- Average fanout calculation failed: $errorstring"
#     if {$params(verbose)} { puts " -E- Average fanout calculation failed: $errorstring" }
  }

  # Restore the current instance
  current_instance -quiet
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
  # Uniquify the nets
  set nets [get_nets -quiet -of $opins -segments -top_net_of_hierarchical_group -filter {(FLAT_PIN_COUNT > 1) && (TYPE == SIGNAL)}]
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
  # E.g: $guideline == {<=70}
  if {[regexp {^([^0-9]+)([0-9].*)$} $guideline - mode m]} {
    set guideline $m
  } elseif {($guideline == {-}) || ($guideline == {})} {
    # For user custom metrics, a guideline of "-" means to just display
    # the metric value without comparing it to any threshold
    set mode {-}
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
    "-" {
      # No guideline, just display the metric value
      # (mainly to be used for user custom metrics)
      set status {-}
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
  if {$params(show_fail_only) && (($status == "OK") || ($status == "-"))} {
    # If -only_fails, then only show metrics that have failed. Skip $status=="OK"
    return -code ok
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

  variable reports
  variable metrics
  variable params
  variable guidelines
  if {$params(debug) && !$force} {
    # Do not remove arrays in debug mode
    return -code ok
  }
  catch { unset metrics }
  catch { unset guidelines }
#   catch { unset reports }
#   array set reports [list]
  array set metrics [list]
  return -code ok
}

proc ::tclapp::xilinx::designutils::report_failfast::addCustomMetric {name description guideline} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  variable metrics
  variable guidelines
  variable params
  if {![regexp {^custom[0-9]*\.} $name]} {
    puts " -W- custom metric should start with 'custom*.'. Skipping metric '$name'"
    return -code ok
  }
  if {$params(verbose)} {
    puts " -I- adding customer metric '$name'"
  }
  addMetric_ORG $name $description
  if {![info exists guidelines(${name})]} {
    # Only override the guideline if not already defined (e.g from config file)
    set guidelines(${name}) $guideline
  }
  # For custom metrics, automatically add the corresponding metric that holds the available resources
  dputs " -D- adding customer metric '${name}.avail'"
  addMetric_ORG ${name}.avail [format {%s (Avail)} $description]
  return -code ok
}

proc ::tclapp::xilinx::designutils::report_failfast::setCustomMetric {name value {avail -}} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  variable metrics
  if {![info exists metrics(${name}:def)]} {
    puts " -E- metric '$name' does not exist"
    return -code ok
  }
  dputs " -D- setting: $name = $value (available resources=$avail)"
  set metrics(${name}:def) 2
  set metrics(${name}:val) $value
  # For custom metrics, save the available resources in a single call
  set metrics(${name}.avail:def) 2
  set metrics(${name}.avail:val) $avail
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

proc ::tclapp::xilinx::designutils::report_failfast::getReport {name args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  variable reports
  variable params
  if {[info exists reports($name)]} {
    if {$params(verbose)} { puts " -I- Found report '$name'" }
    if {$params(debug) && ($params(debug_level) >= 4)} {
      # Output report in debug mode
      puts " -D- report: $name"
      foreach line [split $reports($name) \n] {
        puts " -D- # [string range $line 0 199]"
      }
    }
    return $reports($name)
  }
  set res {}
  set startTime [clock seconds]
  # Debug: remove -quiet
#   set args [lsearch -all -inline -not -exact $args {-quiet}]
  if {$params(debug)} { puts [format " -D- running '$name' with: %s ..." [string range $args 0 199]] }
  if {[catch {set res [$name {*}$args]} errorstring]} {
    if {$params(verbose)} { puts " -E- $errorstring" }
  }
  set stopTime [clock seconds]
  if {$params(verbose)} { puts " -I- report '$name' completed in [expr $stopTime - $startTime] seconds" }
  set reports($name) $res
  if {$params(debug) && ($params(debug_level) >= 4)} {
    # Output report in debug mode
    puts " -D- report: $name"
    foreach line [split $reports($name) \n] {
      puts " -D- # [string range $line 0 199]"
    }
  }
  return $res
}

proc ::tclapp::xilinx::designutils::report_failfast::importReport {name filename} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  variable reports
  variable params
  if {![file exists $filename]} {
    puts " -E- File '$filename' does not exist"
    return -code ok
  }
  if {[info exists reports($name)]} {
    if {$params(verbose)} { puts " -I- Found report '$name'. Overridding existing report with new one" }
  }
  if {$params(verbose)} {
    puts " -I- Importing report '[file normalize $filename]'"
  }
  set FH [open $filename {r}]
  set report [read $FH]
  close $FH
  set reports($name) $report
  return $report
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
#       extractMetricFromTable report {utilization.clb.lut}      -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{CLB LUTs} {SLICE LUTs}} -column {Used} -default {n/a}
#       extractMetricFromTable report {utilization.clb.lut.pct}  -search {{(Slice|CLB|Netlist) Logic\s*$} {(Slice|CLB|Netlist) Logic\s*$}} -row {{CLB LUTs} {SLICE LUTs}} -column {Util%} -trim float -default {n/a}
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
#       puts [format {# %s} $line]
      # Only display the first 200 characters to avoid very long lines
      puts [format {# %s} [string range $line 0 199]]
    }
  }

  return $tables
}

# namespace import -force ::tclapp::xilinx::designutils::report_failfast::report_failfast