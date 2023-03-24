# package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export prettyTable
}

########################################################################################
##
## Company:        Xilinx, Inc.
## Created by:     David Pefourque
##
## Version:        2022.10.31
## Description:    This package provides a simple way to handle formatted tables
##
##
## BASIC USAGE:
## ============
##
## 1- Create new table object with optional title
##
##   Vivado% set tbl [::tclapp::xilinx::designutils::prettyTable {Pin Slack}]
##
## 2- Define header
##
##   Vivado% $tbl header [list NAME IS_LEAF IS_CLOCK SETUP_SLACK HOLD_SLACK]
##
## 3- Add row(s)
##
##   Vivado% $tbl addrow [list {or1200_wbmux/muxreg_reg[4]_i_45/I5} 1 0 10.000 3.266 ]
##   Vivado% $tbl addrow [list or1200_mult_mac/p_1_out__2_i_9/I2 1 0 9.998 1.024 ]
##   Vivado% $tbl addrow [list {or1200_wbmux/muxreg_reg[3]_i_52/I1} 1 0 9.993 2.924 ]
##   Vivado% $tbl addrow [list {or1200_wbmux/muxreg_reg[14]_i_41/I2} 1 0 9.990 3.925 ]
##
## 4- Print table
##
##   Vivado% $tbl print
##   +-------------------------------------------------------------------------------------+
##   | Pin slack                                                                           |
##   +-------------------------------------+---------+----------+-------------+------------+
##   | NAME                                | IS_LEAF | IS_CLOCK | SETUP_SLACK | HOLD_SLACK |
##   +-------------------------------------+---------+----------+-------------+------------+
##   | or1200_wbmux/muxreg_reg[4]_i_45/I5  | 1       | 0        | 10.000      | 3.266      |
##   | or1200_mult_mac/p_1_out__2_i_9/I2   | 1       | 0        | 9.998       | 1.024      |
##   | or1200_wbmux/muxreg_reg[3]_i_52/I1  | 1       | 0        | 9.993       | 2.924      |
##   | or1200_wbmux/muxreg_reg[14]_i_41/I2 | 1       | 0        | 9.990       | 3.925      |
##   +-------------------------------------+---------+----------+-------------+------------+
##
## 5- Get number of rows
##
##   Vivado% $tbl numrows
##   4
##
## 5- Destroy table (optional)
##
##   Vivado% $tbl destroy
##
##
##
## ADVANCED USAGE:
## ===============
##
## 1- Interactivity:
##
##   Vivado% ::tclapp::xilinx::designutils::prettyTable -help
##   Vivado% set tbl [::tclapp::xilinx::designutils::prettyTable]
##   Vivado% $tbl
##   Vivado% $tbl configure -help
##   Vivado% $tbl export -help
##   Vivado% $tbl import -help
##   Vivado% $tbl print -help
##   Vivado% $tbl sort -help
##
## 2- Adjust table indentation:
##
##   Vivado% $tbl indent 8
##   OR
##   Vivado% $tbl configure -indent 8
##
##   Vivado% $tbl print
##           +-------------------------------------------------------------------------------------+
##           | Pin Slack                                                                           |
##           +-------------------------------------+---------+----------+-------------+------------+
##           | NAME                                | IS_LEAF | IS_CLOCK | SETUP_SLACK | HOLD_SLACK |
##           +-------------------------------------+---------+----------+-------------+------------+
##           | or1200_wbmux/muxreg_reg[4]_i_45/I5  | 1       | 0        | 10.000      | 3.266      |
##           | or1200_mult_mac/p_1_out__2_i_9/I2   | 1       | 0        | 9.998       | 1.024      |
##           | or1200_wbmux/muxreg_reg[3]_i_52/I1  | 1       | 0        | 9.993       | 2.924      |
##           | or1200_wbmux/muxreg_reg[14]_i_41/I2 | 1       | 0        | 9.990       | 3.925      |
##           +-------------------------------------+---------+----------+-------------+------------+
##
## 3- Sort the table by columns. Multi-columns sorting is supporting:
##
##   Vivado% $tbl sort +setup_slack
##   Vivado% $tbl sort +3
##
##   Vivado% $tbl print
##           +-------------------------------------------------------------------------------------+
##           | Pin Slack                                                                           |
##           +-------------------------------------+---------+----------+-------------+------------+
##           | NAME                                | IS_LEAF | IS_CLOCK | SETUP_SLACK | HOLD_SLACK |
##           +-------------------------------------+---------+----------+-------------+------------+
##           | or1200_wbmux/muxreg_reg[14]_i_41/I2 | 1       | 0        | 9.990       | 3.925      |
##           | or1200_wbmux/muxreg_reg[3]_i_52/I1  | 1       | 0        | 9.993       | 2.924      |
##           | or1200_mult_mac/p_1_out__2_i_9/I2   | 1       | 0        | 9.998       | 1.024      |
##           | or1200_wbmux/muxreg_reg[4]_i_45/I5  | 1       | 0        | 10.000      | 3.266      |
##           +-------------------------------------+---------+----------+-------------+------------+
##
## 4- Export table to multiple formats:
##
##   4.1- Regular table:
##
##     Vivado% $tbl export -format table
##           +-------------------------------------------------------------------------------------+
##           | Pin Slack                                                                           |
##           +-------------------------------------+---------+----------+-------------+------------+
##           | NAME                                | IS_LEAF | IS_CLOCK | SETUP_SLACK | HOLD_SLACK |
##           +-------------------------------------+---------+----------+-------------+------------+
##           | or1200_wbmux/muxreg_reg[14]_i_41/I2 | 1       | 0        | 9.990       | 3.925      |
##           | or1200_wbmux/muxreg_reg[3]_i_52/I1  | 1       | 0        | 9.993       | 2.924      |
##           | or1200_mult_mac/p_1_out__2_i_9/I2   | 1       | 0        | 9.998       | 1.024      |
##           | or1200_wbmux/muxreg_reg[4]_i_45/I5  | 1       | 0        | 10.000      | 3.266      |
##           +-------------------------------------+---------+----------+-------------+------------+
##
##     is equivalent to
##
##     Vivado% $tbl print
##
##   4.2- CSV format:
##
##     Vivado% $tbl export -format csv -delimiter {;}
##     # title;"Pin Slack"
##     # header;"NAME";"IS_LEAF";"IS_CLOCK";"SETUP_SLACK";"HOLD_SLACK"
##     # indent;"8"
##     # limit;"-1"
##     # display_limit;"50"
##     "NAME";"IS_LEAF";"IS_CLOCK";"SETUP_SLACK";"HOLD_SLACK"
##     "or1200_wbmux/muxreg_reg[14]_i_41/I2";"1";"0";"9.990";"3.925"
##     "or1200_wbmux/muxreg_reg[4]_i_45/I5";"1";"0";"10.000";"3.266"
##     "or1200_wbmux/muxreg_reg[3]_i_52/I1";"1";"0";"9.993";"2.924"
##     "or1200_mult_mac/p_1_out__2_i_9/I2";"1";"0";"9.998";"1.024"
##
##   4.3- Tcl script:
##
##     Vivado% $tbl export -format tcl
##     set tbl [::tclapp::xilinx::designutils::prettyTable]
##     $tbl configure -title {Pin Slack} -indent 8 -limit -1 -display_limit 50
##     $tbl header [list NAME IS_LEAF IS_CLOCK SETUP_SLACK HOLD_SLACK]
##     $tbl addrow [list {or1200_wbmux/muxreg_reg[14]_i_41/I2} 1 0 9.990 3.925 ]
##     $tbl addrow [list {or1200_wbmux/muxreg_reg[4]_i_45/I5} 1 0 10.000 3.266 ]
##     $tbl addrow [list {or1200_wbmux/muxreg_reg[3]_i_52/I1} 1 0 9.993 2.924 ]
##     $tbl addrow [list or1200_mult_mac/p_1_out__2_i_9/I2 1 0 9.998 1.024 ]
##
##   4.4- List format:
##
##     Vivado% $tbl export -format list -delimiter { }
##           NAME:or1200_wbmux/muxreg_reg[14]_i_41/I2 IS_LEAF:1 IS_CLOCK:0 SETUP_SLACK:9.990 HOLD_SLACK:3.925
##           NAME:or1200_wbmux/muxreg_reg[4]_i_45/I5 IS_LEAF:1 IS_CLOCK:0 SETUP_SLACK:10.000 HOLD_SLACK:3.266
##           NAME:or1200_wbmux/muxreg_reg[3]_i_52/I1 IS_LEAF:1 IS_CLOCK:0 SETUP_SLACK:9.993 HOLD_SLACK:2.924
##           NAME:or1200_mult_mac/p_1_out__2_i_9/I2 IS_LEAF:1 IS_CLOCK:0 SETUP_SLACK:9.998 HOLD_SLACK:1.024
##
##
## 5- Save results to file:
##
##   Vivado% $tbl print -file <filename> [-append]
##   Vivado% $tbl export -file <filename> [-append]
##
## 6- Return results by reference for large tables:
##
##   Vivado% $tbl print -return_var foo
##   Vivado% $tbl export -return_var foo
##
##   Vivado% puts $foo
##           +-------------------------------------------------------------------------------------+
##           | Pin Slack                                                                           |
##           +-------------------------------------+---------+----------+-------------+------------+
##           | NAME                                | IS_LEAF | IS_CLOCK | SETUP_SLACK | HOLD_SLACK |
##           +-------------------------------------+---------+----------+-------------+------------+
##           | or1200_wbmux/muxreg_reg[14]_i_41/I2 | 1       | 0        | 9.990       | 3.925      |
##           | or1200_wbmux/muxreg_reg[4]_i_45/I5  | 1       | 0        | 10.000      | 3.266      |
##           | or1200_wbmux/muxreg_reg[3]_i_52/I1  | 1       | 0        | 9.993       | 2.924      |
##           | or1200_mult_mac/p_1_out__2_i_9/I2   | 1       | 0        | 9.998       | 1.024      |
##           +-------------------------------------+---------+----------+-------------+------------+
##
##
##
## 7- Import table from CSV file
##
##   Vivado% $tbl import -file table.csv -delimiter {,}
##
## 8- Query/interact with the content of the table
##
##   Vivado% upvar 0 ${tbl}::table table
##   Vivado% set header [$tbl header]
##   Vivado% foreach row $table { <do something with the row...> }
##
## 9- Other commands:
##
##   9.1- Clone the table:
##
##     Vivado% set clone [$tbl clone]
##
##   9.2- Reset/clear the content of the table:
##
##     Vivado% $tbl reset
##
##   9.3- Add separator between rows:
##
##   Vivado% set tbl [::tclapp::xilinx::designutils::prettyTable {Pin Slack}]
##   Vivado% $tbl header [list NAME IS_LEAF IS_CLOCK SETUP_SLACK HOLD_SLACK]
##   Vivado% $tbl addrow [list {or1200_wbmux/muxreg_reg[4]_i_45/I5} 1 0 10.000 3.266 ]
##   Vivado% $tbl addrow [list or1200_mult_mac/p_1_out__2_i_9/I2 1 0 9.998 1.024 ]
##   Vivado% $tbl separator
##   Vivado% $tbl addrow [list {or1200_wbmux/muxreg_reg[3]_i_52/I1} 1 0 9.993 2.924 ]
##   Vivado% $tbl separator
##   Vivado% $tbl addrow [list {or1200_wbmux/muxreg_reg[14]_i_41/I2} 1 0 9.990 3.925 ]
##   Vivado% $tbl print
##           +-------------------------------------------------------------------------------------+
##           | Pin Slack                                                                           |
##           +-------------------------------------+---------+----------+-------------+------------+
##           | NAME                                | IS_LEAF | IS_CLOCK | SETUP_SLACK | HOLD_SLACK |
##           +-------------------------------------+---------+----------+-------------+------------+
##           | or1200_wbmux/muxreg_reg[4]_i_45/I5  | 1       | 0        | 10.000      | 3.266      |
##           | or1200_mult_mac/p_1_out__2_i_9/I2   | 1       | 0        | 9.998       | 1.024      |
##           +-------------------------------------+---------+----------+-------------+------------+
##           | or1200_wbmux/muxreg_reg[3]_i_52/I1  | 1       | 0        | 9.993       | 2.924      |
##           +-------------------------------------+---------+----------+-------------+------------+
##           | or1200_wbmux/muxreg_reg[14]_i_41/I2 | 1       | 0        | 9.990       | 3.925      |
##           +-------------------------------------+---------+----------+-------------+------------+
##
##   9.4- Destroy the table and release memory:
##
##     Vivado% $tbl destroy
##
##   9.5- Get information on the table:
##
##     Vivado% $tbl info
##     Header: NAME IS_LEAF IS_CLOCK SETUP_SLACK HOLD_SLACK
##     # Cols: 5
##     # Rows: 4
##     Param[indent]: 8
##     Param[maxNumRows]: -1
##     Param[maxNumRowsToDisplay]: -1
##     Param[title]: Pin Slack
##     Memory footprint: 330 bytes
##
##   9.6- Get the memory size taken by the table:
##
##     Vivado% $tbl sizeof
##     330
##
########################################################################################

########################################################################################
## 2022.10.31 - Added 'cleardevice', 'getregion', 'setregion, 'incrregion' methods
##              (template 'deviceview')
##            - Improved support for Versal devices (template 'deviceview')
##            - Changed some messages verbosity for -inline ('import' method)
##            - Improved support for clock regions formatted as S*X*Y*
## 2021.12.20 - Added support for -split_table ('print' method)
##            - Added support for -split_table ('print_array', 'print_table')
##            - Changed -header to be optional ('print_table', 'create_table')
## 2021.05.14 - Added support for rows expansion ('delrows' method)
##            - Added support for columns expansion ('delcolumns' method)
## 2020.04.16 - Fixed an issue when a collection of objects could be truncated to 500 objects
##              (impact all methods but most likely 'plotcells')
## 2020.04.03 - Updated -inline to support deleting the current row ('filter' method)
## 2019.10.30 - Added global debug (::tclapp::xilinx::designutils::prettyTable::debug 0|1)
##            - Added 'print_array' to ::tclapp::xilinx::designutils::prettyTable and to namespace ::tclapp::xilinx::designutils
##            - Added support for -indent/-left/-right/-classic/-lean/-compact (print_table)
##            - Added 'arrayget' method
##            - Added 'arrayset' method
## 2019.10.02 - Added 'rebuild' method
##            - Added 'trim' method
##            - Added support for -rows ('print' method)
##            - Added support for -rows ('export' method)
## 2018.07.03 - Added 'eval' method
##            - Added 'createpivot', 'refreshtable' methods
##            - Added 'create_table' and 'print_table' to ::tclapp::xilinx::designutils::prettyTable
##              and to namespace ::tclapp::xilinx::designutils
##            - Added support for -rows/-eq/-lt/-gt/-bt ('search' method)
##            - Added support for column names for -columns ('search' method)
##            - Added support for -inline ('filter' method)
##            - Added support for -from_row/-to_row/-head/-tail ('export' method)
##            - Added support for JSON/dict formats ('export' method)
##            - Added support for dict and gzip formats ('import' method)
##            - Added support for -next_to/-show_column_indexes/-head/-tail ('print' method)
##            - Added support for compact format (-compact) ('print' method)
##            - Added math functions and operators
##            - Updated 'getcells', 'setcells', 'incrcells', 'appendcells',
##              'prependcells' methods to support range of cells
##            - Renamed 'getcell', 'setcell', 'incrcell', 'appendcell',
##              'prependcell' methods to enable multiple cells
## 2018.05.04 - Added 'reorderrows' method
## 2018.05.02 - Updated 'reordercols' method
##            - Added support for -from_row/-to_row ('print' method)
##            - Changed return value to the table object itself (methods 'creatematrix',
##              'insertcolumn', 'insertrow', 'delcolumns', 'delrows', 'cleartable',
##              'filter', 'reordercols', 'plotregions', 'plotcells', 'plotnets')
##            - Updated -columns to apply for all formats ('export' method)
##            - Added support for -order_columns ('export' method)
##            - Added support for -align_right/-align_left ('export' method)
##            - Added support for custom formats and arguments ('export' method)
## 2018.04.27 - Added 'insertrow' method
##            - Added 'reordercols' method
##            - Added 'version' method
##            - Added support for -skip_header/-noheader/-append ('import' method)
##            - Minor fixes and enhancements
## 2018.04.16 - Fixed issue with -return_table ('search' method)
## 2017.10.09 - Fixed sorting of columns with heterogeneous data ('sort' method)
##            - Added 'transpose' method
## 2017.06.05 - Fixed example code
## 2016.10.04 - Added support for -inline (import)
## 2016.08.23 - Updated default alignment for template 'deviceview'
## 2016.06.30 - Fixed issue with 'delcolumns', 'delrows' methods
## 2016.06.24 - Added 'search', 'filter', 'prependcell' methods
##            - Fixed issue with 'set_param' method
##            - Added support for private methods for templates
##            - Added 'plotcells', 'plotnets', 'plotregions' methods for
##              template 'deviceview'
## 2016.06.17 - Added 'appendcell', 'cleartable', 'incrcell' methods
##            - Added support for -origin/-offsetx/-offsety (configure)
##            - Added support for templates for table creation
##            - Updated 'separator' method to accept a list of row numbers
##              E.g: create table based on device view
## 2016.06.13 - Added 'setrow', 'setcolumn' methods
## 2016.06.09 - Added 'delrows', 'delcolumns' methods
##            - Added 'getcell', 'setcell' methods
##            - Added 'insertcolumn', 'settable' methods
##            - Added 'creatematrix' method
## 2016.05.23 - Updated 'title' method to set/get the table's title
## 2016.05.20 - Added 'getrow', 'getcolumns', 'gettable' methods
## 2016.04.08 - Added 'appendrow' method
## 2016.03.25 - Added 'numcols' method
##            - Added new format for 'export' method (array)
##            - Fixed help message for 'numrows' method
## 2016.03.02 - Added -noheader to 'export' method
##            - Addes support for -noheader when exporting CSV
## 2016.01.27 - Fixed missing header when exporting to CSV
## 2015.12.10 - Added 'title' method to add/change the table title
##            - Added new command line options to 'configure' method to set the default
##              table format and cell alignment
##            - Added support for -indent from the 'print' method
## 2015.12.09 - Expanded syntax for 'sort' method to be able to sort columns of different
##              types
##            - Added -verbose to 'export' method for CSV format
## 2014.11.04 - Added proc 'lrevert' to avoid dependency
## 2014.07.19 - Added support for a new 'lean' table format to the 'print'
##              and 'export' methods
##            - Added support for left/right text alignment in table cells
## 2014.04.25 - Changed version format to 2014.04.25 to be compatible with 'package' command
## 04/25/2014 - Fixed typo inside exportToCSV
##            - Added -help to prettyTable
##            - Added -noheader/-notitle to method print
## 01/15/2014 - Added support for multi-lines titles when exporting to CSV format
##            - Changed namespace's variables to 'variable'
## 09/16/2013 - Added meta-comment 'Categories' to all procs
##            - Updated 'docstring' to support new meta-comment 'Categories'
##            - Updated various methods to support -columns/-display_columns (select
##              list of columns to be printed out)
## 09/11/2013 - Added method 'numrows'
##            - Improved method 'sort'
##            - Added support for multi-lines title
##            - Other minor changes
## 02/15/2013 - Initial release
########################################################################################


proc ::tclapp::xilinx::designutils::prettyTable { args } {
  # Summary : Utility to easily create and print tables

  # Argument Usage:
  # [args]: sub-command. The supported sub-commands are: create | info | sizeof | destroyall
  # [-usage]: Usage information

  # Return Value:
  # returns a new prettyTable object

  # Categories: xilinxtclstore, designutils

  uplevel [concat ::tclapp::xilinx::designutils::prettyTable::prettyTable $args]
#   eval [concat ::tclapp::xilinx::designutils::prettyTable::prettyTable $args]
}


###########################################################################
##
## Package for handling and printing of formatted tables
##
###########################################################################

#------------------------------------------------------------------------
# Namespace for the package
#------------------------------------------------------------------------

interp alias {} ::tclapp::xilinx::designutils::print_array {} ::tclapp::xilinx::designutils::prettyTable print_array
interp alias {} ::tclapp::xilinx::designutils::print_table {} ::tclapp::xilinx::designutils::prettyTable print_table
interp alias {} ::tclapp::xilinx::designutils::create_table {} ::tclapp::xilinx::designutils::prettyTable create_table

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils::prettyTable {
  variable n 0
#   set params [list indent 0 maxNumRows 10000 maxNumRowsToDisplay 50 title {} ]
  variable params [list indent 0 title {} tableFormat {classic} cellAlignment {left} maxNumRows -1 maxNumRowsToDisplay -1 columnsToDisplay {} origin {topleft} offsetx 0 offsety 0 template {} methods {method}]
  variable history
  variable debug 0
  variable version {2022.10.31}
} ]

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::prettyTable
#------------------------------------------------------------------------
# Main function
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::prettyTable { args } {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  #-------------------------------------------------------
  # Process command line arguments
  #-------------------------------------------------------
  variable debug
  set error 0
  set show_help 0
  set method [lshift args]
  switch -regexp -- $method {
    {^sizeof$} -
    {^si(z(e(of?)?)?)?$} {
      return [eval [concat ::tclapp::xilinx::designutils::prettyTable::Sizeof] ]
    }
    {^info$} -
    {^in(fo?)?$} {
      return [eval [concat ::tclapp::xilinx::designutils::prettyTable::Info] ]
    }
    {^destroyall$} -
    {^de(s(t(r(o(y(a(ll?)?)?)?)?)?)?)?$} {
      return [eval [concat ::tclapp::xilinx::designutils::prettyTable::DestroyAll] ]
    }
    {^-help$} -
    {^-h(e(lp?)?)?$} -
    {^-usage$} -
    {^-u(s(a(ge?)?)?)?$} {
      incr show_help
    }
    {^create$} -
    {^cr(e(a(te?)?)?)?$} {
      return [eval [concat ::tclapp::xilinx::designutils::prettyTable::Create $args] ]
    }
    {^template$} -
    {^te(m(p(l(a(te?)?)?)?)?)?$} {
      # Create table based on template
      return [eval [concat ::tclapp::xilinx::designutils::prettyTable::Template $args] ]
    }
    {^print_table$} -
    {^print_t(a(b(le?)?)?)?$} {
      # Create->print->delete table
      return [::tclapp::xilinx::designutils::prettyTable::print_table {*}$args]
    }
    {^print_array$} -
    {^print_a(r(r(ay?)?)?)?$} {
      # Create->print->delete table from Tcl array
      return [::tclapp::xilinx::designutils::prettyTable::print_array {*}$args]
    }
    {^create_table$} -
    {^create_(t(a(b(le?)?)?)?)?$} {
      # Create table
      return [::tclapp::xilinx::designutils::prettyTable::create_table {*}$args]
    }
    {^version$} -
    {^v(e(r(s(i(on?)?)?)?)?)?$} {
      # Return the package version
      return $::tclapp::xilinx::designutils::prettyTable::version
    }
    {^debug$} -
    {^de(b(ug?)?)?$} {
      set debug [lshift args]
      return -code ok
    }
    default {
      # The 'method' variable has the table's title. Since it can have multiple words
      # it is cast as a List to work well with 'eval'
      return [eval [concat ::tclapp::xilinx::designutils::prettyTable::Create [list $method]] ]
    }
  }

  if {$show_help} {
    # <-- HELP
    puts [format {
      Usage: prettyTable
                  [<title>]                - Create a new prettyTable object (optional table title)
                  [create|create <title>]  - Create a new prettyTable object (optional table title)
                  [template <name>]        - Create a new prettyTable object based on template
                  [create_table]           - Create a new prettyTable object from table content (-help)
                  [print_table]            - Create and print a prettyTable from table content (-help)
                  [print_array]            - Create and print a prettyTable from Tcl array (-help)
                  [sizeof]                 - Provides the memory consumption of all the prettyTable objects
                  [info]                   - Provides a summary of all the prettyTable objects that have been created
                  [destroyall]             - Destroy all the prettyTable objects and release the memory
                  [version]                - Return the package version
                  [-u|-usage|-h|-help]     - This help message

      Description: Utility to create and manipulate tables

      Example Script:
         set tbl [prettyTable {Pins Slacks}]
         $tbl configure -limit -1 -indent 2 -display_limit -1
         set Header [list NAME CLASS DIRECTION IS_LEAF IS_CLOCK LOGIC_VALUE SETUP_SLACK HOLD_SLACK]
         $tbl header $Header
         foreach pin [get_pins -hier *] {
           set SETUP_SLACK [get_property SETUP_SLACK $pin]
           if {$SETUP_SLACK <= 0.0} {
             set row [list]
             foreach prop $Header {
               lappend row [get_property $prop $pin]
             }
             $tbl addrow $row
           }
         }
         $tbl print -file table.rpt
         $tbl sort -SETUP_SLACK
         $tbl print -file table_sorted.rpt
         $tbl destroy

    } ]
    # HELP -->
    return
  }

}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::Create
#------------------------------------------------------------------------
# Constructor for a new prettyTable object
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::Create { {title {}} } {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  variable n
  # Search for the next available object number, i.e namespace should not
  # already exist
  while { [namespace exist [set instance [namespace current]::[incr n]] ]} {}
  namespace eval $instance {
    variable header [list]
    variable table [list]
    variable separators [list]
    variable params
    variable numRows 0
  }
  catch {unset ${instance}::params}
  array set ${instance}::params $::tclapp::xilinx::designutils::prettyTable::params
  # Save the table's title
  set ${instance}::params(title) $title
  interp alias {} $instance {} ::tclapp::xilinx::designutils::prettyTable::do $instance
  set instance
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::Create
#------------------------------------------------------------------------
# Constructor for a new prettyTable object
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::Template { {name {}} } {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  switch $name {
    "" {
      puts " -I- The supported templates are: device | deviceview"
      return -code ok
    }
    device -
    deviceview {
      # +-----+----+----+----+----+----+----+
      # |     | X0 | X1 | X2 | X3 | X4 | X5 |
      # +-----+----+----+----+----+----+----+
      # | Y14 |    |    |    |    |    |    |
      # | Y13 |    |    |    |    |    |    |
      # | Y12 |    |    |    |    |    |    |
      # | Y11 |    |    |    |    |    |    |
      # | Y10 |    |    |    |    |    |    |
      # +-----+----+----+----+----+----+----+
      # | Y9  |    |    |    |    |    |    |
      # | Y8  |    |    |    |    |    |    |
      # | Y7  |    |    |    |    |    |    |
      # | Y6  |    |    |    |    |    |    |
      # | Y5  |    |    |    |    |    |    |
      # +-----+----+----+----+----+----+----+
      # | Y4  |    |    |    |    |    |    |
      # | Y3  |    |    |    |    |    |    |
      # | Y2  |    |    |    |    |    |    |
      # | Y1  |    |    |    |    |    |    |
      # | Y0  |    |    |    |    |    |    |
      # +-----+----+----+----+----+----+----+
      set maxX 0
      set maxY 0
      # hasMaxtrixSLR=1 : clock regions match S*X*Y* (used in devices such as P80)
      set hasMaxtrixSLR 0
      foreach slr [lsort [get_slrs -quiet]] {
        foreach region [get_clock_regions -quiet -of $slr] {
          regexp {^(S([0-9]))?X([0-9]+)Y([0-9]+)$} $region - - S X Y
          if {$X > $maxX} { set maxX $X }
          if {$Y > $maxY} { set maxY $Y }
          if {$S != {}} { set hasMaxtrixSLR 1 }
          lappend ar(${slr}:X) $X
          lappend ar(${slr}:Y) $Y
        }
      }

      if {$hasMaxtrixSLR} {
        # Device with SLRs positioned in a matrix (P80)
        # ----------------------------------
        #  +----+----+----+----+----+----+----+----+----+----+----+-----+-----+-----+-----+----+----+----+----+----+----+----+----+----+----+
        #  |    | X0 | X1 | X2 | X3 | X4 | X5 | X6 | X7 | X8 | X9 | X10 | X11 | X11 | X10 | X9 | X8 | X7 | X6 | X5 | X4 | X3 | X2 | X1 | X0 |
        #  +----+----+----+----+----+----+----+----+----+----+----+-----+-----+-----+-----+----+----+----+----+----+----+----+----+----+----+
        #  | Y0 |    |    |    |    |    |    |    |    |    |    |     |     |     |     |    |    |    |    |    |    |    |    |    |    |
        #  | Y1 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
        #  | Y2 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
        #  | Y3 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
        #  | Y4 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
        #  | Y5 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
        #  | Y6 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
        #  +----+----+----+----+----+----+----+----+----+----+----+-----+-----+-----+-----+----+----+----+----+----+----+----+----+----+----+
        #  | Y6 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
        #  | Y5 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
        #  | Y4 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
        #  | Y3 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
        #  | Y2 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
        #  | Y1 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
        #  | Y0 |    |    |    |    |    |    |    |    |    |    |     |     |     |     |    |    |    |    |    |    |    |    |    |    |
        #  +----+----+----+----+----+----+----+----+----+----+----+-----+-----+-----+-----+----+----+----+----+----+----+----+----+----+----+
        # ----------------------------------
        # Header
        set header [list {}]
        for {set i 0} {$i <= $maxX} {incr i} {
          lappend header "X$i"
        }
        for {set i $maxX} {$i >= 0} {incr i -1} {
          lappend header "X$i"
        }
        # Column 0
        for {set i 0} {$i <= $maxY} {incr i} {
          lappend column0 "Y$i"
        }
        for {set i $maxY} {$i >= 0} {incr i -1} {
          lappend column0 "Y$i"
        }
        set tbl [tclapp::xilinx::designutils::prettyTable]
        $tbl creatematrix [expr (($maxX +1) * 2) +1] [expr (($maxY +1) *2) +0]
        $tbl configure -align_right -origin bottomleft -offsetx 1 -offsety 0
        $tbl header $header
        $tbl setcolumn 0 $column0
        $tbl separator [expr ($maxY+1)]
        # Save the 'template' parameter with the template name
        $tbl set_param {template} {deviceview}
        $tbl set_param {methods} {method deviceview}
        $tbl set_param {deviceType} {2x2}
        $tbl set_param {deviceInvalidCRs} [list]
        # Max X/Y of one of the SLRs
        $tbl set_param {deviceMaxX} $maxX
        $tbl set_param {deviceMaxY} $maxY
      } else {
        # Legacy SSI device
        # -----------------
        #  +-----+----+----+----+----+----+----+----+----+----+----+-----+-----+-----+
        #  |     | X0 | X1 | X2 | X3 | X4 | X5 | X6 | X7 | X8 | X9 | X10 | X11 | X12 |
        #  +-----+----+----+----+----+----+----+----+----+----+----+-----+-----+-----+
        #  | Y13 |    |    |    |    |    |    |    |    |    |    |   x |   x |   x |
        #  | Y12 |    |    |    |    |    |    |    |    |    |    |   x |   x |   x |
        #  | Y11 |    |    |    |    |    |    |    |    |    |    |   x |   x |   x |
        #  +-----+----+----+----+----+----+----+----+----+----+----+-----+-----+-----+
        #  | Y10 |    |    |    |    |    |    |    |    |    |    |   x |   x |   x |
        #  |  Y9 |    |    |    |    |    |    |    |    |    |    |   x |   x |   x |
        #  |  Y8 |    |    |    |    |    |    |    |    |    |    |   x |   x |   x |
        #  +-----+----+----+----+----+----+----+----+----+----+----+-----+-----+-----+
        #  |  Y7 |    |    |    |    |    |    |    |    |    |    |   x |   x |   x |
        #  |  Y6 |    |    |    |    |    |    |    |    |    |    |   x |   x |   x |
        #  |  Y5 |    |    |    |    |    |    |    |    |    |    |   x |   x |   x |
        #  +-----+----+----+----+----+----+----+----+----+----+----+-----+-----+-----+
        #  |  Y4 |    |    |    |    |    |    |    |    |    |    |   x |   x |   x |
        #  |  Y3 |    |    |    |    |    |    |    |    |    |    |   x |   x |   x |
        #  |  Y2 |    |    |    |    |    |    |    |    |    |    |   x |   x |   x |
        #  |  Y1 |    |    |    |    |    |    |    |    |    |    |   x |   x |   x |
        #  |  Y0 |    |    |    |    |    |    |    |    |    |    |     |     |     |
        #  +-----+----+----+----+----+----+----+----+----+----+----+-----+-----+-----+
        # -----------------
        set column0 [list]
        set header [list {}]
        for {set i 0} {$i <= $maxX} {incr i} {
          lappend header "X$i"
        }
        for {set i $maxY} {$i >= 0} {incr i -1} {
          lappend column0 "Y$i"
        }
        set tbl [tclapp::xilinx::designutils::prettyTable]
        $tbl creatematrix [expr $maxX +2] [expr $maxY +1]
        $tbl configure -align_right -origin bottomleft -offsetx 1 -offsety 0
        $tbl header $header
        $tbl setcolumn 0 $column0
        # Start from the highest number SLR. The lowest (SLR0)
        # can be skipped as the number of separators that are needed
        # is the number of SLRs minus 1
        foreach slr [lrange [lsort -decreasing [get_slrs -quiet]] 0 end-1] {
          set Y [lsort -integer -increasing -unique $ar(${slr}:Y)]
          # Get the lowest Y number for this SLR
          set n [lindex $Y 0]
          $tbl separator [expr $maxY - $n +1]
        }
        # Save the 'template' parameter with the template name
        $tbl set_param {template} {deviceview}
        $tbl set_param {methods} {method deviceview}
        $tbl set_param {deviceType} {ssi}
        $tbl set_param {deviceInvalidCRs} [list]
        # Max X/Y of the entire device
        $tbl set_param {deviceMaxX} $maxX
        $tbl set_param {deviceMaxY} $maxY
      }

      # Find invalid (non-existing) clock regions
      if {$hasMaxtrixSLR} {
        # Assuming that each SLR is symetric when in a matrix configuration
        set regions [get_clock_regions -quiet -of [get_slrs SLR0]]
      } else {
        set regions [get_clock_regions -quiet]
      }
      set invalidClockRegions [list]
      for {set X 0} {$X <= $maxX} {incr X} {
        for {set Y 0} {$Y <= $maxY} {incr Y} {
          if {$hasMaxtrixSLR} {
            if {[lsearch $regions "S0X${X}Y${Y}"] == -1} {
              for {set idx 0} {$idx < [llength [get_slrs]]} {incr idx} {
                lappend invalidClockRegions "S${idx}X${X}Y${Y}"
              }
            }
          } else {
            if {[lsearch $regions "X${X}Y${Y}"] == -1} {
              lappend invalidClockRegions "X${X}Y${Y}"
            }
          }
        }
      }
      # Save the list of invalid clock regions
      $tbl set_param {deviceInvalidCRs} $invalidClockRegions

      # Clear the device to add the invalid regions on it
      $tbl cleardevice

      # Return the table object
      set tbl
    }
    default {
      puts " -E- invalid template '$name'. Valid templates are: device | deviceview"
      return -code ok
    }
  }
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::print_table
#------------------------------------------------------------------------
# Create/print/delete a prettyTable based on existing content
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::print_table {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  set title {}
  set header {}
  set table {}
  set printOptions [list]
  set indent 0
  set channel {stdout}
  set error 0
  set help 0
  set verbose 0
  if {[llength $args] == 0} { incr help }
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-values$} -
      {^-va(l(u(es?)?)?)?$} {
        set table [lshift args]
      }
      {^-c(o(l(u(m(ns?)?)?)?)?)?$} -
      {^-he(a(d(er?)?)?)?$} {
        set header [lshift args]
      }
      {^-title$} -
      {^-ti(t(le?)?)?$} {
        set title [lshift args]
      }
      {^-left$} -
      {^-le(ft?)?$} -
      {^-align_left$} -
      {^-align_l(e(ft?)?)?$} {
        lappend printOptions {-left}
      }
      {^-right$} -
      {^-ri(g(ht?)?)?$} -
      {^-align_right$} -
      {^-align_r(i(g(ht?)?)?)?$} {
        lappend printOptions {-right}
      }
      {^-lean$} -
      {^-le(an?)?$} {
        lappend printOptions {-lean}
      }
      {^-classic$} -
      {^-cl(a(s(s(ic?)?)?)?)?$} {
        lappend printOptions {-classic}
      }
      {^-compact$} -
      {^-co(m(p(a(ct?)?)?)?)?$} {
        lappend printOptions {-compact}
      }
      {^-indent$} -
      {^-in(d(e(nt?)?)?)?$} {
        set indent [lshift args]
      }
      {^-channel$} -
      {^-ch(a(n(n(el?)?)?)?)?$} {
        set channel [lshift args]
      }
      {^-split_table$} -
      {^-sp(l(i(t(_(t(a(b(le?)?)?)?)?)?)?)?)?$} {
        lappend printOptions {-split_table}
        lappend printOptions [lshift args]
      }
      {^-v(e(r(b(o(se?)?)?)?)?)?$} {
        set verbose 1
      }
      {^\?$} -
      {^-h(e(lp?)?)?$} {
        set help 1
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
  Usage: ::tclapp::xilinx::designutils::prettyTable print_table
              -values <row(s)>
              [-columns <column(s)>|-header <column(s)>]
              [-title <title>]
              [-align_left|-left]
              [-align_right|-right]
              [-lean][-classic][-compact]
              [-indent <indent_level>]
              [-split_table <num_rows>]
              [-channel <channel>]
              [-verbose|-v]
              [-help|-h]

  Description: Print table from table content

    -columns|-header: table column names
    -values: table rows
    -title: table title
    -indent: indent table
    -channel: output channel. Default: stdout
    -split_table: specify the max number of rows. Split the table into side-by-side tables

  Example:
     ::tclapp::xilinx::designutils::prettyTable print_table -columns {Name # %%} -values [list {LUT 9754 66.51} {CARRY 2622 17.88} ]
} ]
    # HELP -->
    return {}
  }

  if {[llength $header] == 0} {
#     puts " -E- no column defined (-columns/-header)"
#     incr error
    # Create header if not specified
    for {set idx 0} {$idx < [llength [lindex $table 0]]} {incr idx} {
      lappend header [format {Column %s} $idx]
    }
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  if {[catch {
    set tbl [::tclapp::xilinx::designutils::prettyTable]
    if {$title != {}} {
      $tbl title $title
    }
    $tbl header $header
    $tbl settable $table
    puts $channel [$tbl print -indent $indent {*}$printOptions]
    catch {$tbl destroy}
  } errorstring]} {
    puts " -E- $errorstring"
  }
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::print_array
#------------------------------------------------------------------------
# Create/print/delete a prettyTable based on existing Tcl array content
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::print_array {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  set title {}
  set header {}
  set printOptions [list]
  set indent 0
  array set var [list]
  set channel {stdout}
  set error 0
  set help 0
  set verbose 0
  if {[llength $args] == 0} { incr help }
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-var$} -
      {^-v(ar?)?$} {
        set _var [lshift args]
        catch { unset var }
        upvar 2 $_var var
      }
      {^-c(o(l(u(m(ns?)?)?)?)?)?$} -
      {^-he(a(d(er?)?)?)?$} {
        set header [lshift args]
      }
      {^-title$} -
      {^-ti(t(le?)?)?$} {
        set title [lshift args]
      }
      {^-left$} -
      {^-le(ft?)?$} -
      {^-align_left$} -
      {^-align_l(e(ft?)?)?$} {
        lappend printOptions {-left}
      }
      {^-right$} -
      {^-ri(g(ht?)?)?$} -
      {^-align_right$} -
      {^-align_r(i(g(ht?)?)?)?$} {
        lappend printOptions {-right}
      }
      {^-lean$} -
      {^-le(an?)?$} {
        lappend printOptions {-lean}
      }
      {^-classic$} -
      {^-cl(a(s(s(ic?)?)?)?)?$} {
        lappend printOptions {-classic}
      }
      {^-compact$} -
      {^-co(m(p(a(ct?)?)?)?)?$} {
        lappend printOptions {-compact}
      }
      {^-indent$} -
      {^-in(d(e(nt?)?)?)?$} {
        set indent [lshift args]
      }
      {^-channel$} -
      {^-ch(a(n(n(el?)?)?)?)?$} {
        set channel [lshift args]
      }
      {^-split_table$} -
      {^-sp(l(i(t(_(t(a(b(le?)?)?)?)?)?)?)?)?$} {
        lappend printOptions {-split_table}
        lappend printOptions [lshift args]
      }
      {^-v(e(r(b(o(se?)?)?)?)?)?$} {
        set verbose 1
      }
      {^\?$} -
      {^-h(e(lp?)?)?$} {
        set help 1
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
  Usage: ::tclapp::xilinx::designutils::prettyTable print_array
              -var <TclArrayVar>
              [-columns <column(s)>|-header <column(s)>]
              [-title <title>]
              [-align_left|-left]
              [-align_right|-right]
              [-lean][-classic][-compact]
              [-indent <indent_level>]
              [-split_table <num_rows>]
              [-channel <channel>]
              [-verbose|-v]
              [-help|-h]

  Description: Print table from an existing Tcl array

    -var: Tcl array name that contain the table data
    -columns|-header: table column names
    -title: table title
    -indent: indent table
    -channel: output channel. Default: stdout
    -split_table: specify the max number of rows. Split the table into side-by-side tables

  Example:
     ::tclapp::xilinx::designutils::prettyTable print_array -var myarray -title {Title for my table}
} ]
    # HELP -->
    return {}
  }

  if {![array exists var]} {
    puts " -E- variable '$_var' is not a Tcl array"
    incr error
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  if {[catch {
    set tbl [::tclapp::xilinx::designutils::prettyTable]
    $tbl arrayget var
    if {$title != {}} {
      $tbl title $title
    }
    if {$header != {}} {
      $tbl header $header
    }
    puts $channel [$tbl print -indent $indent {*}$printOptions]
    catch {$tbl destroy}
  } errorstring]} {
    puts " -E- $errorstring"
  }
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::create_table
#------------------------------------------------------------------------
# Create a prettyTable based on existing content
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::create_table {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  set title {}
  set header {}
  set table {}
  set error 0
  set help 0
  set verbose 0
  if {[llength $args] == 0} { incr help }
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-values$} -
      {^-va(l(u(es?)?)?)?$} {
        set table [lshift args]
      }
      {^-c(o(l(u(m(ns?)?)?)?)?)?$} -
      {^-he(a(d(er?)?)?)?$} {
        set header [lshift args]
      }
      {^-title$} -
      {^-ti(t(le?)?)?$} {
        set title [lshift args]
      }
      {^-v(e(r(b(o(se?)?)?)?)?)?$} {
        set verbose 1
      }
      {^\?$} -
      {^-h(e(lp?)?)?$} {
        set help 1
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
  Usage: ::tclapp::xilinx::designutils::prettyTable create_table
              -values <row(s)>
              [-columns <column(s)>|-header <column(s)>]
              [-title <title>]
              [-verbose|-v]
              [-help|-h]

  Description: Create table from table content

    -columns|-header: table column names
    -values: table rows
    -title: table title
    -channel: output channel. Default: stdout

  Example:
     ::tclapp::xilinx::designutils::prettyTable create_table -columns {Name # %%} -values [list {LUT 9754 66.51} {CARRY 2622 17.88} ]
} ]
    # HELP -->
    return {}
  }

  if {[llength $header] == 0} {
#     puts " -E- no column defined (-columns/-header)"
#     incr error
    # Create header if not specified
    for {set idx 0} {$idx < [llength [lindex $table 0]]} {incr idx} {
      lappend header [format {Column %s} $idx]
    }
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  set tbl {}
  if {[catch {
    set tbl [::tclapp::xilinx::designutils::prettyTable]
    if {$title != {}} {
      $tbl title $title
    }
    $tbl header $header
    $tbl settable $table
  } errorstring]} {
    puts " -E- $errorstring"
  }
  return $tbl
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::Sizeof
#------------------------------------------------------------------------
# Memory footprint of all the existing prettyTable objects
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::Sizeof {} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  return [::tclapp::xilinx::designutils::prettyTable::method:sizeof ::tclapp::xilinx::designutils::prettyTable]
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::Info
#------------------------------------------------------------------------
# Provide information about all the existing prettyTable objects
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::Info {} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  foreach child [lsort -dictionary [namespace children]] {
    puts "\n  Object $child"
    puts "  ==================="
    $child info
  }
  return 0
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::DestroyAll
#------------------------------------------------------------------------
# Detroy all the existing prettyTable objects and release the memory
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::DestroyAll {} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  set count 0
  foreach child [namespace children] {
    $child destroy
    incr count
  }
  puts "  $count object(s) have been destroyed"
  return 0
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::docstring
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Return the embedded help of a proc
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::docstring procname {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  if {[info proc $procname] ne $procname} { return }
  # reports a proc's args and leading comments.
  # Multiple documentation lines are allowed.
  set res ""
  # This comment should not appear in the docstring
  foreach line [split [uplevel 1 [list info body $procname]] \n] {
      if {[string trim $line] eq ""} continue
      # Skip comments that have been added to support rdi::register_proc command
      if {[regexp -nocase -- {^\s*#\s*(Summary|Argument Usage|Return Value|Categories)\s*\:} $line]} continue
      if {![regexp {^\s*#(.+)} $line -> line]} break
      lappend res [string trim $line]
  }
  join $res \n
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::lshift
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Stack function
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::lshift {inputlist} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  upvar $inputlist argv
  set arg  [lindex $argv 0]
  set argv [lrange $argv 1 end]
  return $arg
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::lrevert
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Reverse a list
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::lrevert L {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

   for {set res {}; set i [llength $L]} {$i>0} {#see loop} {
       lappend res [lindex $L [incr i -1]]
   }
   set res
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::min
# ::tclapp::xilinx::designutils::prettyTable::max
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Return min/max. Handles empty strings
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::min {x y} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  if {$y == {}} {
    set y $x
  } elseif {$x == {}} {
    set x $y
  }
  expr {$x<$y? $x:$y}
}

proc ::tclapp::xilinx::designutils::prettyTable::max {x y} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  if {$y == {}} {
    set y $x
  } elseif {$x == {}} {
    set x $y
  }
  expr {$x>$y?$x:$y}
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::sort_double_incr
# ::tclapp::xilinx::designutils::prettyTable::sort_double_decr
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Helper procs for ::tclapp::xilinx::designutils::prettyTable::method:sort to handle list
# of integers/reals mixed with strings
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::sort_double_incr {one two} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  switch [string is double $one][string is double $two] {
    00 {
      return 0
    }
    01 {
      return 1
    }
    10 {
      return -1
    }
    11 {
      if { $one < $two } {
        return -1
      } elseif { $one > $two} {
        return 1
      } else {
        return 0
      }
    }
  }
}

proc ::tclapp::xilinx::designutils::prettyTable::sort_double_decr {one two} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  switch [string is double $one][string is double $two] {
    00 {
      return 0
    }
    01 {
      return 1
    }
    10 {
      return -1
    }
    11 {
      if { $one < $two } {
        return 1
      } elseif { $one > $two} {
        return -1
      } else {
        return 0
      }
    }
  }
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::getFrequencyDistribution
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Example:
#   getFrequencyDistribution [list clk_out2_pll_clrx_2 clk_out2_pll_lnrx_3 clk_out2_pll_lnrx_3 ]
# => {clk_out2_pll_lnrx_3 2} {clk_out2_pll_clrx_2 1}
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::getFrequencyDistribution {L} {
  # Summary :
  # Argument Usage:
  # Return Value:
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

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::list2csv
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Convert a Tcl list to a CSV-friedly string
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::list2csv { list {sepChar ,} } {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  set out ""
  set sep {}
  foreach val $list {
    if {[string match "*\[\"$sepChar\]*" $val]} {
      append out $sep\"[string map [list \" \"\"] $val]\"
    } else {
      append out $sep\"$val\"
    }
    set sep $sepChar
  }
  return $out
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::csv2list
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Convert a CSV string to a Tcl list based on a field separator
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::csv2list { str {sepChar ,} } {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  regsub -all {(\A\"|\"\Z)} $str \0 str
  set str [string map [list $sepChar\"\"$sepChar $sepChar$sepChar] $str]
  set str [string map [list $sepChar\"\"\" $sepChar\0\" \
                            \"\"\"$sepChar \"\0$sepChar \
                            $sepChar\"\"$sepChar $sepChar$sepChar \
                           \"\" \" \
                           \" \0 \
                           ] $str]
  set end 0
  while {[regexp -indices -start $end {(\0)[^\0]*(\0)} $str \
          -> start end]} {
      set start [lindex $start 0]
      set end   [lindex $end 0]
      set range [string range $str $start $end]
      set first [string first $sepChar $range]
      if {$first >= 0} {
          set str [string replace $str $start $end \
              [string map [list $sepChar \1] $range]]
      }
      incr end
  }
  set str [string map [list $sepChar \0 \1 $sepChar \0 {} ] $str]
  return [split $str \0]
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::convertCoordinates
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Convert coordonates for getcells/setcells/appendcells/prependcells
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::convertCoordinates {self X Y} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  upvar #0 ${self}::table table
  upvar #0 ${self}::header header
  upvar #0 ${self}::numRows numRows
  set maxX [expr [llength $header] -1]
  set maxY [expr [llength $table] -1]
  switch [subst $${self}::params(origin)] {
    topleft {
    }
    bottomleft {
      set Y [expr $maxY - $Y]
    }
    topright {
      set X [expr $maxX - $X]
    }
    bottomright {
      set X [expr $maxX - $X]
      set Y [expr $maxY - $Y]
    }
    default {
    }
  }
  set X [expr $X + [subst $${self}::params(offsetx)] ]
  set Y [expr $Y + [subst $${self}::params(offsety)] ]
  return [list $X $Y]
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::export:tcl
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Dump the content of the prettyTable object as Tcl code
# The result is returned as a single string or through upvar
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::export:tcl {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  array set defaults [list \
      -return_var {} \
    ]
  array set options [array get defaults]
  array set options $args

  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::params params
  upvar #0 ${self}::separators separators
  upvar #0 ${self}::numRows numRows

  # 'options(-return_var)' holds the variable name from the caller's environment
  # that should receive the content of the report
  if {$options(-return_var) != {}} {
    # The caller's environment is 1 levels up
    upvar 1 $options(-return_var) res
  }
  set res {}

  append res [format {set tbl [::tclapp::xilinx::designutils::prettyTable]
$tbl configure -title {%s} -align {%s} -format {%s} -indent %s -limit %s -display_limit %s -display_columns {%s} -origin {%s} -offsetx {%s} -offsety {%s}
$tbl header [list %s]} $params(title) $params(cellAlignment) $params(tableFormat) $params(indent) $params(maxNumRows) $params(maxNumRowsToDisplay) $params(columnsToDisplay) $params(origin) $params(offsetx) $params(offsety) $header]
  append res "\n"
  set count 0
  foreach row $table {
    incr count
    append res "[format {$tbl addrow [list %s ]} $row] \n"
    # Check if a separator has been assigned to this row number and add a separator
    # if so.
    if {[lsearch $separators $count] != -1} {
      append res "[format {$tbl separator}]\n"
    }
  }
  if {$options(-return_var) != {}} {
    # The report is returned through the upvar
    return {}
  } else {
    return $res
  }
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::export:csv
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Dump the content of the prettyTable object as CSV format
# The result is returned as a single string or through upvar
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::export:csv {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  array set defaults [list \
      -header 1 \
      -delimiter {,} \
      -return_var {} \
      -verbose 0 \
    ]
  array set options [array get defaults]
  array set options $args
  set sepChar $options(-delimiter)

  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::params params
  upvar #0 ${self}::separators separators
  upvar #0 ${self}::numRows numRows

  # 'options(-return_var)' holds the variable name from the caller's environment
  # that should receive the content of the report
  if {$options(-return_var) != {}} {
    # The caller's environment is 1 levels up
    upvar 1 $options(-return_var) res
  }
  set res {}

  # Support for multi-lines title
  set first 1
  foreach line [split $params(title) \n] {
    if {$first} {
      set first 0
      append res "# title${sepChar}[::tclapp::xilinx::designutils::prettyTable::list2csv [list $line] $sepChar]\n"
    } else {
      append res "#      ${sepChar}[::tclapp::xilinx::designutils::prettyTable::list2csv [list $line] $sepChar]\n"
    }
  }
#   append res "# title${sepChar}[::tclapp::xilinx::designutils::prettyTable::list2csv [list $params(title)] $sepChar]\n"
  if {$options(-verbose)} {
    # Additional header information are hidden by default
    append res "# header${sepChar}[::tclapp::xilinx::designutils::prettyTable::list2csv $header $sepChar]\n"
    append res "# indent${sepChar}[::tclapp::xilinx::designutils::prettyTable::list2csv $params(indent) $sepChar]\n"
    append res "# limit${sepChar}[::tclapp::xilinx::designutils::prettyTable::list2csv $params(maxNumRows) $sepChar]\n"
    append res "# display_limit${sepChar}[::tclapp::xilinx::designutils::prettyTable::list2csv $params(maxNumRowsToDisplay) $sepChar]\n"
    append res "# display_columns${sepChar}[::tclapp::xilinx::designutils::prettyTable::list2csv [list $params(columnsToDisplay)] $sepChar]\n"
  }
  if {$options(-header)} {
    append res "[::tclapp::xilinx::designutils::prettyTable::list2csv $header $sepChar]\n"
  }
  set count 0
  foreach row $table {
    incr count
    append res "[::tclapp::xilinx::designutils::prettyTable::list2csv $row $sepChar]\n"
    # Check if a separator has been assigned to this row number and add a separator
    # if so.
    if {[lsearch $separators $count] != -1} {
      append res "# ++++++++++++++++++++++++++++++++++++++++++++++++++\n"
    }
  }
  if {$options(-return_var) != {}} {
    # The report is returned through the upvar
    return {}
  } else {
    return $res
  }
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::export:list
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Dump the content of the prettyTable object as "list" with one
# line per row
# The result is returned as a single string or throug upvar
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::export:list {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  array set defaults [list \
      -delimiter { } \
      -return_var {} \
      -columns [subst $${self}::params(columnsToDisplay)] \
    ]
  array set options [array get defaults]
  array set options $args
  set sepChar $options(-delimiter)

  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::params params
  upvar #0 ${self}::separators separators
  upvar #0 ${self}::numRows numRows

  # 'options(-return_var)' holds the variable name from the caller's environment
  # that should receive the content of the report
  if {$options(-return_var) != {}} {
    # The caller's environment is 1 levels up
    upvar 1 $options(-return_var) res
  }
  set res {}

  # Build the list of columns to be displayed
  if {$options(-columns) == {}} {
    # If empty, then all the columns are displayed. Build the list of all columns
    for {set index 0} {$index < [llength $header]} {incr index} {
      lappend options(-columns) $index
    }
  }

  set count 0
  set indentString [string repeat " " $params(indent)]
  foreach row $table {
    incr count
    append res $indentString
    # Iterate through all the columns of the row
    for {set index 0} {$index < [llength $header]} {incr index} {
      # Should the column be visible?
      if {[lsearch $options(-columns) $index] == -1} { continue }
      # Yes
      append res "[lindex $header $index]:[lindex $row $index]${sepChar}"
    }
    # Remove extra separator at the end of the line due to 'foreach' loop
    regsub "${sepChar}$" $res {} res
    append res "\n"
    # Check if a separator has been assigned to this row number and add a separator
    # if so.
    if {[lsearch $separators $count] != -1} {
      append res "${indentString}# ++++++++++++++++++++++++++++++++++++++++++++++++++\n"
    }
  }
  if {$options(-return_var) != {}} {
    # The report is returned through the upvar
    return {}
  } else {
    return $res
  }
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::export:tclArray
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Dump the content of the prettyTable object as a fragment Tcl code to
# set a Tcl array
# The result is returned as a single string or through upvar
# The result can be used as, for example: array set myarray [source res.ftcl]
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::export:array {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  array set defaults [list \
      -return_var {} \
    ]
  array set options [array get defaults]
  array set options $args

  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::params params
  upvar #0 ${self}::separators separators
  upvar #0 ${self}::numRows numRows

  # 'options(-return_var)' holds the variable name from the caller's environment
  # that should receive the content of the report
  if {$options(-return_var) != {}} {
    # The caller's environment is 1 levels up
    upvar 1 $options(-return_var) res
  }
  set res {}

  append res [format {#  This file can be imported with:  array set myarray [source <file>]}]
  append res [format "\nreturn \[list \\\n"]
  append res [format "  {header} { %s } \\\n" $header]
  append res [format "  {rows} \[list \\\n"]
  set count -1
  foreach row $table {
    incr count
    append res "[format {    %s { %s } %s} $count $row \\]\n"
  }
  append res "    \] \\\n"
  append res "  \]\n"
  if {$options(-return_var) != {}} {
    # The report is returned through the upvar
    return {}
  } else {
    return $res
  }
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::export:dict
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Dump the content of the prettyTable object as Tcl Dict format
# The result is returned as a single string or through upvar
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::export:dict {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::params params
  upvar #0 ${self}::separators separators
  upvar #0 ${self}::numRows numRows

  array set defaults [list \
      -return_var {} \
      -verbose 0 \
    ]
  array set options [array get defaults]
#   array set options $args

  set error 0
  set help 0
  if {[llength $args] == 0} { incr help }
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-header$} -
      {^-h(e(a(d(er?)?)?)?)?$} {
        # Do nothing. Unused option
        lshift args
      }
      {^-title$} -
      {^-t(i(t(le?)?)?)?$} {
        # Do nothing. Unused option
        lshift args
      }
      {^-delimiter$} -
      {^-d(e(l(i(m(i(t(er?)?)?)?)?)?)?)?$} {
        # Do nothing. Unused option
        lshift args
      }
      {^-return_var$} -
      {^-re(t(u(r(n(_(v(ar?)?)?)?)?)?)?)?$} {
        set options(-return_var) [lshift args]
      }
      {^-v(e(r(b(o(se?)?)?)?)?)?$} {
        set options(-verbose) [lshift args]
      }
      {^\?$} -
      {^-help$} -
      {^-h(e(lp?)?)?$} {
        set help 1
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
  Usage: <prettyTableObject> export -format dict
              [-help|-h]

  Description: Export table as Tcl Dict format

  Example:
     <prettyTableObject> export -format dict
     set dict [<prettyTableObject> export -format dict]
} ]
    # HELP -->
    return {}
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  # 'options(-return_var)' holds the variable name from the caller's environment
  # that should receive the content of the report
  if {$options(-return_var) != {}} {
    # The caller's environment is 1 levels up
    upvar 1 $options(-return_var) res
  }

  # Create the dictionary
  set res [dict create {header} $header {params} [array get params] {rows} $table {separators} $separators]

  if {$options(-return_var) != {}} {
    # The report is returned through the upvar
    return {}
  } else {
    return $res
  }
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::export:json
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Dump the content of the prettyTable object as JSON format
# The result is returned as a single string or through upvar
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::export:json {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::params params
  upvar #0 ${self}::separators separators
  upvar #0 ${self}::numRows numRows

  array set defaults [list \
      -return_var {} \
      -verbose 0 \
    ]
  array set options [array get defaults]
#   array set options $args

  set format {default}
  set numericAsString 0
  set literalAsString 0
  set rowsOnly 0
  set error 0
  set help 0
  if {[llength $args] == 0} { incr help }
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-numeral_as_strings$} -
      {^-nu(m(e(r(a(l(_(a(s(_(s(t(r(i(n(gs?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?$} {
        set numericAsString 1
      }
      {^-literal_as_strings$} -
      {^-li(t(e(r(a(l(_(a(s(_(s(t(r(i(n(gs?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?$} {
        set literalAsString 1
      }
      {^-only_rows$} -
      {^-on(l(y(_(r(o(ws?)?)?)?)?)?)?$} {
        set rowsOnly 1
      }
      {^-compact$} -
      {^-co(m(p(a(ct?)?)?)?)?$} {
        set format {compact}
      }
      {^-header$} -
      {^-h(e(a(d(er?)?)?)?)?$} {
        # Do nothing. Unused option
        lshift args
      }
      {^-title$} -
      {^-t(i(t(le?)?)?)?$} {
        # Do nothing. Unused option
        lshift args
      }
      {^-delimiter$} -
      {^-d(e(l(i(m(i(t(er?)?)?)?)?)?)?)?$} {
        # Do nothing. Unused option
        lshift args
      }
      {^-return_var$} -
      {^-re(t(u(r(n(_(v(ar?)?)?)?)?)?)?)?$} {
        set options(-return_var) [lshift args]
      }
      {^-v(e(r(b(o(se?)?)?)?)?)?$} {
        set options(-verbose) [lshift args]
      }
      {^\?$} -
      {^-help$} -
      {^-h(e(lp?)?)?$} {
        set help 1
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
  Usage: <prettyTableObject> export -format json
              [-compact]
              [-numeral_as_strings]
              [-literal_as_strings]
              [-only_rows]
              [-help|-h]

  Description: Export table as JSON format

    -compact: compact format
    -numeral_as_strings: numeric values are encoded as strings
    -literal_as_strings: true/false/null are encoded as strings
    -only_rows: generate JSON for rows only

  Example:
     <prettyTableObject> export -format json
     <prettyTableObject> export -format json -args {-compact}
     <prettyTableObject> export -format json -- -compact
     <prettyTableObject> export -format json -- -compact -numeral_as_strings
} ]
    # HELP -->
    return {}
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  # 'options(-return_var)' holds the variable name from the caller's environment
  # that should receive the content of the report
  if {$options(-return_var) != {}} {
    # The caller's environment is 1 levels up
    upvar 1 $options(-return_var) res
  }
  set res {}

  set jsonHeaderStr [format {"%s"} [join $header {", "}] ]
  set jsonParamsStr {}
  set jsonRowsStr {}

  set L [list]
  foreach param [lsort [array names params]] {
    set value $params($param)
    if {[regexp {^[-+]?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][-+]?[0-9]+)?$} $value]} {
      # floating point numbers
      if {$numericAsString} {
        lappend L [format {"%s": "%s"} $param $value]
      } else {
        lappend L [format {"%s": %s} $param $value]
      }
    } elseif {[regexp -nocase {^(true|false|null)$} $value]} {
      if {$literalAsString} {
        lappend L [format {"%s": "%s"} $param $value]
      } else {
        lappend L [format {"%s": %s} $param $value]
      }
    } else {
      lappend L [format {"%s": "%s"} $param $value]
    }
  }
  append jsonParamsStr "\n"
  if {$format == {compact}} {
    append jsonParamsStr [format {        { %s },} [join $L {, }]]
  } else {
    append jsonParamsStr [format "        {\n          %s\n       }," [join $L ",\n          "]]
  }
  # remove last ','
  set jsonParamsStr [string range $jsonParamsStr 0 end-1]

  set idx -1
  foreach row $table {
    incr idx
    set L [list]
    foreach h $header r $row {
      if {[regexp {^[-+]?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][-+]?[0-9]+)?$} $r]} {
        # floating point numbers
        if {$numericAsString} {
          lappend L [format {"%s": "%s"} $h $r]
        } else {
          lappend L [format {"%s": %s} $h $r]
        }
      } elseif {[regexp -nocase {^(true|false|null)$} $r]} {
        if {$literalAsString} {
          lappend L [format {"%s": "%s"} $h $r]
        } else {
          lappend L [format {"%s": %s} $h $r]
        }
      } else {
        lappend L [format {"%s": "%s"} $h $r]
      }
    }
    append jsonRowsStr "\n"
    if {$format == {compact}} {
      append jsonRowsStr [format {        { %s },} [join $L {, }]]
    } else {
      append jsonRowsStr [format "        {\n          %s\n        }," [join $L ",\n          "]]
    }
  }
  # remove last ','
  set jsonRowsStr [string range $jsonRowsStr 0 end-1]

  if {$rowsOnly} {
    set JSON [format {[%s%s]} $jsonRowsStr \n ]
  } else {

    set JSON [format {{
  "table": {
    "header": [%s],
    "params": [%s
    ],
    "rows": [%s
    ]
  }
}
} $jsonHeaderStr $jsonParamsStr $jsonRowsStr ]

  }

  set res $JSON

  if {$options(-return_var) != {}} {
    # The report is returned through the upvar
    return {}
  } else {
    return $res
  }
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::do
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Dispatcher with methods
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::do {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  variable debug
  upvar #0 ${self}::table table
  upvar #0 ${self}::history history
  if {[llength $args] == 0} {
#     error " -E- wrong number of parameters: <prettyTableObject> <method> \[<arguments>\]"
    set method {?}
  } else {
    # The first argument is the method
    set method [lshift args]
  }
  set methods [subst $${self}::params(methods)]
  # The line below only match if $methods has a length of 1 and the
  # full method name has been specified by the user
  if {[info proc ::tclapp::xilinx::designutils::prettyTable::${methods}:${method}] == "::tclapp::xilinx::designutils::prettyTable::${methods}:${method}"} {
    switch $method {
      clone -
      destroy -
      info {
        # Do not save the history
      }
      default {
        # Save the history
#         lappend history [list $self $method {*}$args]
      }
    }
    catch {
      if {$debug} {
        puts " -D- ::tclapp::xilinx::designutils::prettyTable::${methods}:${method} $self $args"
      }
    }
#     eval ::tclapp::xilinx::designutils::prettyTable::${methods}:${method} $self $args
    ::tclapp::xilinx::designutils::prettyTable::${methods}:${method} $self {*}$args
  } else {
    # Search for a unique matching method among all the available methods
    set match [dict create]
    set procnames [list]
    foreach m $methods {
      set procnames [concat $procnames [info proc ::tclapp::xilinx::designutils::prettyTable::${m}:*]]
    }
    foreach procname $procnames {
      set str [regsub {::tclapp::xilinx::designutils::prettyTable::[^\:]+:} $procname {}]
      if {[string first $method $str] == 0} {
        dict lappend match $str $procname
      }
    }
    set keys [dict keys $match]
    switch [llength $keys] {
      0 {
        error " -E- unknown method $method"
      }
      1 {
        # Last win: if multiple methods match (with different paths), take the last one
        set procname [lindex [dict get $match $keys] end]
        regexp {:([^:]+)$} $procname - method
        switch $method {
          clone -
          destroy -
          info {
            # Do not save the history
          }
          default {
            # Save the history
#             lappend history [list $self $method {*}$args]
          }
        }
        catch {
          if {$debug} {
            puts " -D- $procname $self $args"
          }
        }
#         eval $procname $self $args
        $procname $self {*}$args
      }
      default {
        error " -E- multiple methods match '$method': $keys"
      }
    }
  }
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:?
#------------------------------------------------------------------------
# Usage: <prettyTableObject> ?
#------------------------------------------------------------------------
# Return all the available methods. The methods with no embedded help
# are not displayed (i.e hidden)
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:? {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # This help message
  puts "   Usage: <prettyTableObject> <method> \[<arguments>\]"
  puts "   Where <method> is:"
  set method [dict create]
  set methods [subst $${self}::params(methods)]
  set procnames [list]
  # Build the list of all the proc names based on the list of methods
  foreach m $methods {
    set procnames [concat $procnames [info proc ::tclapp::xilinx::designutils::prettyTable::${m}:*]]
  }
  # Build the dict: key=method name  value=proc name
  foreach procname $procnames {
    set method [regsub {::tclapp::xilinx::designutils::prettyTable::[^\:]+:} $procname {}]
    dict lappend match $method $procname
  }
  foreach key [lsort [dict keys $match]] {
    # Last win: if multiple methods match (with different paths), take the last one
    set procname [lindex [dict get $match $key] end]
    set method [regsub {::tclapp::xilinx::designutils::prettyTable::[^\:]+:} $procname {}]
    set help [::tclapp::xilinx::designutils::prettyTable::docstring $procname]
    if {$help ne ""} {
      puts "         [format {%-12s%s- %s} $method \t $help]"
    }
  }
  puts ""
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:title
#------------------------------------------------------------------------
# Usage: <prettyTableObject> title [<string>]
#------------------------------------------------------------------------
# Set the table title
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:title {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Set/get the title of the table
  switch [llength $args] {
    0 {
      # If no argument is provided then just return the current title
    }
    1 {
      # If just 1 argument then it must be a list
      eval set ${self}::params(title) $args
    }
    default {
      # Multiple arguments should be cast as a list
      eval set ${self}::params(title) [list $args]
    }
  }
  set ${self}::params(title)
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:header
#------------------------------------------------------------------------
# Usage: <prettyTableObject> header [<list>]
#------------------------------------------------------------------------
# Set the table header
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:header {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Set/get the header of the table
  switch [llength $args] {
    0 {
      # If no argument is provided then just return the current header
    }
    1 {
      # If just 1 argument then it must be a list
      eval set ${self}::header $args
    }
    default {
      # Multiple arguments should be cast as a list
      eval set ${self}::header [list $args]
    }
  }
  set ${self}::header
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:addrow
#------------------------------------------------------------------------
# Usage: <prettyTableObject> addrow <list>
#------------------------------------------------------------------------
# Add a row to the table
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:addrow {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Add a row to the table (?)
  if {$args == {}} { set args {-help} }
  if {[lsearch {-h -help ?} [lindex $args 0]] != -1} {
    puts [format {  Usage: <prettyTableObject> addrow <row>}]
    return -code ok
  }

  set maxNumRows [subst $${self}::params(maxNumRows)]
  if {([subst $${self}::numRows] >= $maxNumRows) && ($maxNumRows != -1)} {
    error " -E- maximum number of rows reached ([subst $${self}::params(maxNumRows)]). Failed adding new row"
  }
  eval lappend ${self}::table $args
  incr ${self}::numRows
  return [subst $${self}::numRows]
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:appendrow
#------------------------------------------------------------------------
# Usage: <prettyTableObject> appendrow <list>
#------------------------------------------------------------------------
# Append a row to the previous row of the table
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:appendrow {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Append a row to the previous row (?)
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows

  if {$args == {}} { set args {-help} }
  if {[lsearch {-h -help ?} [lindex $args 0]] != -1} {
    puts [format {  Usage: <prettyTableObject> appendrow <list>}]
    puts [format {  Append all elements to previous row}]
    return -code ok
  }

  if {$numRows == 0} {
    # If the table is empty, then add the row
    switch [llength $args] {
      0 {
        return 0
      }
      1 {
        lappend table [lindex $args end]
      }
      default {
        lappend table $args
      }
    }
    incr numRows
    return 0
  }
  set previousrow [lindex $table end]
  set row [list]
  switch [llength $args] {
    0 {
      return 0
    }
    1 {
      foreach el1 $previousrow el2 [lindex $args 0] {
        lappend row [format {%s%s} $el1 $el2]
      }
    }
    default {
      foreach el1 $previousrow el2 $args {
        lappend row [format {%s%s} $el1 $el2]
      }
    }
  }
  set table [lreplace $table end end $row]
  return 0
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:creatematrix
#------------------------------------------------------------------------
# Usage: <prettyTableObject> creatematrix <numcols> <numrows> <row_filler>
#------------------------------------------------------------------------
# Create a matrix
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:creatematrix {self numcols numrows {row_filler {}}} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Create a matrix
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows
  set row [list]
  set table [list]
  set header [list]
  for {set col 0} {$col < $numcols} {incr col} {
    lappend header $col
    lappend row $row_filler
  }
  for {set r 0} {$r < $numrows} {incr r} {
    lappend table $row
  }
  set numRows $numrows
  return $self
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:insertcolumn
#------------------------------------------------------------------------
# Usage: <prettyTableObject> insertcolumn <col_idx> <col_header> <row_filler>
#------------------------------------------------------------------------
# Insert a column
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:insertcolumn {self col_idx col_header row_filler} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Insert a column
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows
  if {$col_idx == {}} {
    return {}
  }
  if {[regexp {^end$} $col_idx]} { set col_idx [expr [llength $header] -0] }
  if {[regexp {^end-([0-9]+)$} $col_idx - num]} { set col_idx [expr [llength $header] -0 - $num] }
  if {($col_idx < 0) || ($col_idx > [llength $header])} {
    puts " -W- column '$col_idx' out of bound"
    return {}
  }
  if {[catch {
    # Insert column inside header
    set header [linsert $header $col_idx $col_header]
    set L [list]
    foreach row $table {
      # Insert column inside row
      set row [linsert $row $col_idx $row_filler]
      lappend L $row
    }
    set table $L
  } errorstring]} {
    puts " -W- $errorstring"
  } else {
  }
  return $self
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:insertrow
#------------------------------------------------------------------------
# Usage: <prettyTableObject> insertrow <row_idx> <row_filler>
#------------------------------------------------------------------------
# Insert a row
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:insertrow {self row_idx row} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Insert a row
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows
  if {$row_idx == {}} {
    return {}
  }
  if {[regexp {^end$} $row_idx]} { set row_idx [expr [llength $table] -0] }
  if {[regexp {^end-([0-9]+)$} $row_idx - num]} { set row_idx [expr [llength $table] -0 - $num] }
  if {($row_idx < 0) || ($row_idx > [llength $table])} {
    puts " -W- row '$row_idx' out of bound"
    return {}
  }
  if {[llength $row] != [llength $header]} {
    puts " -W- row size ([llength $row]) does not match the header size ([llength $header])"
    return {}
  }
  if {[catch {
    # Insert row
    set table [linsert $table $row_idx $row]
    incr numRows
  } errorstring]} {
    puts " -W- $errorstring"
  } else {
  }
  return $self
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:delcolumns
#------------------------------------------------------------------------
# Usage: <prettyTableObject> delcolumns <list_of_column_indexes>
#------------------------------------------------------------------------
# Delete a list of column(s)
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:delcolumns {self columns} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Delete a list of column(s)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows
  if {$columns == {}} {
    return {}
  }
  set L [list]
  set columns [expandNumericRange $self [join $columns ,] -unique 1]
  foreach column $columns {
  if {[regexp {^end$} $column]} { set column [expr [llength $header] -1] }
  if {[regexp {^end-([0-9]+)$} $column - num]} { set column [expr [llength $header] -1 - $num] }
  if {($column < 0) || ($column > [expr [llength $header] -1])} {
    puts " -W- column '$column' out of bound"
    continue
  }
    lappend L $column
  }
  set columns $L
  foreach col [lsort -unique -integer -decreasing $columns] {
    if {[catch {
      # Remove column from header
      set header [lreplace $header $col $col]
      set L [list]
      foreach row $table {
        # Remove column from row
        set row [lreplace $row $col $col]
        lappend L $row
      }
      set table $L
    } errorstring]} {
      puts " -W- $errorstring"
    } else {
    }
  }
  return $self
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:delrows
#------------------------------------------------------------------------
# Usage: <prettyTableObject> delrows <list_of_row_indexes>
#------------------------------------------------------------------------
# Delete a list of row(s)
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:delrows {self rows} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Delete a list of row(s)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows
  if {$rows == {}} {
    return {}
  }
  set L [list]
  set rows [expandNumericRange $self [join $rows ,] -unique 1]
  foreach row $rows {
    if {[regexp {^end$} $row]} { set row [expr [llength $table] -1] }
    if {[regexp {^end-([0-9]+)$} $row - num]} { set row [expr [llength $table] -1 - $num] }
    if {($row < 0) || ($row > [expr [llength $table] -1])} {
      puts " -W- row '$row' out of bound"
      continue
    }
    lappend L $row
  }
  set rows $L
  foreach pos [lsort -unique -integer -decreasing $rows] {
    if {[catch {
      set table [lreplace $table $pos $pos]
    } errorstring]} {
      puts " -W- $errorstring"
    } else {
      incr numRows -1
    }
  }
  return $self
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:getcells
#------------------------------------------------------------------------
# Usage: <prettyTableObject> getcells <col> <row>
#        <prettyTableObject> getcells <range(s)>
#------------------------------------------------------------------------
# Return a cell by its <col> and <row> index or by ranges
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:getcells {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Get table cell value(s) (?)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows

  if {([llength $args] == 0) || ([llength $args] > 2)} { set args {-help} }
  if {[lsearch {-h -help ?} [lindex $args 0]] != -1} {
    puts [format {  Usage: <prettyTableObject> getcells <column> <row>}]
    puts [format {         <prettyTableObject> getcells <range(s)>}]
    puts [format {  Multiple ranges can be specified. For example: c2:3r0,c1r2:3 }]
    return -code ok
  }

  set column {}
  set row {}
  set range {}

  switch [llength $args] {
    1 {
      set range $args
      set res [::tclapp::xilinx::designutils::prettyTable::expandRange $self $range -mode value]
      return $res
    }
    2 {
      set column [lindex $args 0]
      set row [lindex $args 1]
    }
  }

  if {($column == {}) || ($row == {})} {
    return {}
  }
  if {[regexp {^end$} $column]} { set column [expr [llength $header] -1] }
  if {[regexp {^end-([0-9]+)$} $column - num]} { set column [expr [llength $header] -1 - $num] }
  if {($column < 0) || ($column > [expr [llength $header] -1])} {
    puts " -W- column '$column' out of bound"
    return {}
  }
  if {[regexp {^end$} $row]} { set row [expr [llength $table] -1] }
  if {[regexp {^end-([0-9]+)$} $row - num]} { set row [expr [llength $table] -1 - $num] }
  if {($row < 0) || ($row > [expr [llength $table] -1])} {
    puts " -W- row '$row' out of bound"
    return {}
  }
  # Convert coordinates based on origin
  foreach {column row} [convertCoordinates $self $column $row] { break }
  set res [lindex [lindex $table $row] $column]
  return $res
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:setcells
#------------------------------------------------------------------------
# Usage: <prettyTableObject> setcells <col> <row>
#------------------------------------------------------------------------
# Set a cell value directly by its <col> and <row> index
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:setcells {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Set table cell value(s) (?)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows

  if {([llength $args] != 2) && ([llength $args] != 3)} { set args {-help} }
  if {[lsearch {-h -help ?} [lindex $args 0]] != -1} {
    puts [format {  Usage: <prettyTableObject> setcells <column> <row> <value>}]
    puts [format {         <prettyTableObject> setcells <range(s)> <value>}]
    puts [format {  Multiple ranges can be specified. For example: c2:3r0,c1r2:3 }]
    return -code ok
  }

  set column {}
  set row {}
  set range {}
  set value {}

  switch [llength $args] {
    2 {
      set range [lindex $args 0]
      set value [lindex $args 1]
      set cells [::tclapp::xilinx::designutils::prettyTable::expandRange $self $range -mode coord]
      foreach cell $cells {
        foreach {col row} $cell { break }
        $self setcells $col $row $value
      }
      return $value
    }
    3 {
      set column [lindex $args 0]
      set row [lindex $args 1]
      set value [lindex $args 2]
    }
  }

  if {($column == {}) || ($row == {})} {
    return {}
  }
  if {[regexp {^end$} $column]} { set column [expr [llength $header] -1] }
  if {[regexp {^end-([0-9]+)$} $column - num]} { set column [expr [llength $header] -1 - $num] }
  if {($column < 0) || ($column > [expr [llength $header] -1])} {
    puts " -W- column '$column' out of bound"
    return {}
  }
  if {[regexp {^end$} $row]} { set row [expr [llength $table] -1] }
  if {[regexp {^end-([0-9]+)$} $row - num]} { set row [expr [llength $table] -1 - $num] }
  if {($row < 0) || ($row > [expr [llength $table] -1])} {
    puts " -W- row '$row' out of bound"
    return {}
  }
  # Convert coordinates based on origin
  foreach {column row} [convertCoordinates $self $column $row] { break }
  set L [lindex $table $row]
#   lreplace $L $column $column $value
  set table [lreplace $table $row $row [lreplace $L $column $column $value] ]
  return $value
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:appendcells
#------------------------------------------------------------------------
# Usage: <prettyTableObject> appendcells <col> <row> <value>
#        <prettyTableObject> appendcells <range(s)> <value>
#------------------------------------------------------------------------
# Append to a cell value directly by its <col> and <row> index
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:appendcells {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Append to table cell value(s) (?)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows

  if {([llength $args] != 2) && ([llength $args] != 3)} { set args {-help} }
  if {[lsearch {-h -help ?} [lindex $args 0]] != -1} {
    puts [format {  Usage: <prettyTableObject> appendcells <column> <row> <value>}]
    puts [format {         <prettyTableObject> appendcells <range(s)> <value>}]
    puts [format {  Multiple ranges can be specified. For example: c2:3r0,c1r2:3 }]
    return -code ok
  }

  set column {}
  set row {}
  set range {}
  set value {}

  switch [llength $args] {
    2 {
      set range [lindex $args 0]
      set value [lindex $args 1]
      set cells [::tclapp::xilinx::designutils::prettyTable::expandRange $self $range -mode coord]
      set res {}
      foreach cell $cells {
        foreach {col row} $cell { break }
        set res [$self appendcells $col $row $value]
      }
      return $res
    }
    3 {
      set column [lindex $args 0]
      set row [lindex $args 1]
      set value [lindex $args 2]
    }
  }

  if {($column == {}) || ($row == {})} {
    return {}
  }
  if {[regexp {^end$} $column]} { set column [expr [llength $header] -1] }
  if {[regexp {^end-([0-9]+)$} $column - num]} { set column [expr [llength $header] -1 - $num] }
  if {($column < 0) || ($column > [expr [llength $header] -1])} {
    puts " -W- column '$column' out of bound"
    return {}
  }
  if {[regexp {^end$} $row]} { set row [expr [llength $table] -1] }
  if {[regexp {^end-([0-9]+)$} $row - num]} { set row [expr [llength $table] -1 - $num] }
  if {($row < 0) || ($row > [expr [llength $table] -1])} {
    puts " -W- row '$row' out of bound"
    return {}
  }
  # Convert coordinates based on origin
  foreach {column row} [convertCoordinates $self $column $row] { break }
  set L [lindex $table $row]
  set currentValue [lindex $L $column]
  set newValue [format {%s%s} $currentValue $value]
  set table [lreplace $table $row $row [lreplace $L $column $column $newValue] ]
  return $newValue
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:prependcells
#------------------------------------------------------------------------
# Usage: <prettyTableObject> prependcells <col> <row> <value>
#      : <prettyTableObject> prependcells <range(s)> <value>
#------------------------------------------------------------------------
# Prepend to a cell value directly by its <col> and <row> index
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:prependcells {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Prepend to table cell value(s) (?)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows

  if {([llength $args] != 2) && ([llength $args] != 3)} { set args {-help} }
  if {[lsearch {-h -help ?} [lindex $args 0]] != -1} {
    puts [format {  Usage: <prettyTableObject> prependcells <column> <row> <value>}]
    puts [format {         <prettyTableObject> prependcells <range(s)> <value>}]
    puts [format {  Multiple ranges can be specified. For example: c2:3r0,c1r2:3 }]
    return -code ok
  }

  set column {}
  set row {}
  set range {}
  set value {}

  switch [llength $args] {
    2 {
      set range [lindex $args 0]
      set value [lindex $args 1]
      set cells [::tclapp::xilinx::designutils::prettyTable::expandRange $self $range -mode coord]
      set res {}
      foreach cell $cells {
        foreach {col row} $cell { break }
        set res [$self prependcells $col $row $value]
      }
      return $res
    }
    3 {
      set column [lindex $args 0]
      set row [lindex $args 1]
      set value [lindex $args 2]
    }
  }

  if {($column == {}) || ($row == {})} {
    return {}
  }
  if {[regexp {^end$} $column]} { set column [expr [llength $header] -1] }
  if {[regexp {^end-([0-9]+)$} $column - num]} { set column [expr [llength $header] -1 - $num] }
  if {($column < 0) || ($column > [expr [llength $header] -1])} {
    puts " -W- column '$column' out of bound"
    return {}
  }
  if {[regexp {^end$} $row]} { set row [expr [llength $table] -1] }
  if {[regexp {^end-([0-9]+)$} $row - num]} { set row [expr [llength $table] -1 - $num] }
  if {($row < 0) || ($row > [expr [llength $table] -1])} {
    puts " -W- row '$row' out of bound"
    return {}
  }
  # Convert coordinates based on origin
  foreach {column row} [convertCoordinates $self $column $row] { break }
  set L [lindex $table $row]
  set currentValue [lindex $L $column]
  set newValue [format {%s%s} $value $currentValue ]
  set table [lreplace $table $row $row [lreplace $L $column $column $newValue] ]
  return $newValue
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:incrcells
#------------------------------------------------------------------------
# Usage: <prettyTableObject> incrcells <col> <row> <value>
#        <prettyTableObject> incrcells <range(s)> <value>
#------------------------------------------------------------------------
# Increment cell value directly by its <col> and <row> index
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:incrcells {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Increment table cell value(s) (?)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows

  if {([llength $args] == 0) || ([llength $args] > 3)} { set args {-help} }
  if {[lsearch {-h -help ?} [lindex $args 0]] != -1} {
    puts [format {  Usage: <prettyTableObject> incrcells <column> <row> [<value>]}]
    puts [format {         <prettyTableObject> incrcells <range(s)> [<value>]}]
    puts [format {  Multiple ranges can be specified. For example: c2:3r0,c1r2:3 }]
    return -code ok
  }

  set column {}
  set row {}
  set range {}
  set value 1

  if [regexp {(c|C|r|R)} [lindex $args 0]] {
    # Range is specified
    switch [llength $args] {
      1 {
        set range [lindex $args 0]
      }
      2 {
        set range [lindex $args 0]
        set value [lindex $args 1]
      }
      default {
        puts " -E- incorrect number of arguments"
        return -code ok
      }
    }
    set cells [::tclapp::xilinx::designutils::prettyTable::expandRange $self $range -mode coord]
    set res {}
    foreach cell $cells {
      foreach {col row} $cell { break }
      set res [$self incrcells $col $row $value]
    }
    return $res
  } else {
    # <column> <row> are specified
    switch [llength $args] {
      2 {
        set column [lindex $args 0]
        set row [lindex $args 1]
      }
      3 {
        set column [lindex $args 0]
        set row [lindex $args 1]
        set value [lindex $args 2]
      }
      default {
        puts " -E- incorrect number of arguments"
        return -code ok
      }
    }
  }

  if {($column == {}) || ($row == {})} {
    return {}
  }
  if {[regexp {^end$} $column]} { set column [expr [llength $header] -1] }
  if {[regexp {^end-([0-9]+)$} $column - num]} { set column [expr [llength $header] -1 - $num] }
  if {($column < 0) || ($column > [expr [llength $header] -1])} {
    puts " -W- column '$column' out of bound"
    return {}
  }
  if {[regexp {^end$} $row]} { set row [expr [llength $table] -1] }
  if {[regexp {^end-([0-9]+)$} $row - num]} { set row [expr [llength $table] -1 - $num] }
  if {($row < 0) || ($row > [expr [llength $table] -1])} {
    puts " -W- row '$row' out of bound"
    return {}
  }
  set currentvalue [$self getcells $column $row]
  if {$currentvalue == {}} {
    set currentvalue 0
  }
  if {[catch {set newvalue [expr $currentvalue + $value]} errorstring]} {
    puts " -E- $errorstring"
    return -code ok
  }
  $self setcells $column $row $newvalue
  return $newvalue
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:setrow
#------------------------------------------------------------------------
# Usage: <prettyTableObject> setrow <row_index> <row>
#------------------------------------------------------------------------
# Set an entire row by its index
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:setrow {self idx row} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Set a row
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows
  if {$idx == {end}} { set idx [expr [llength $table] -1] }
  if {[regexp {^end-([0-9]+)$} $idx - num]} { set idx [expr [llength $table] -1 - $num] }
  if {($idx < 0) || ($idx > [expr [llength $table] -1])} {
    puts " -W- row '$idx' out of bound"
    return {}
  }
  if {[llength $row] != [llength $header]} {
    puts " -W- invalid row length (length:[llength $row] / header:[llength $header] )"
    return {}
  }
  set table [lreplace $table $idx $idx $row ]
  return $row
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:setcolumn
#------------------------------------------------------------------------
# Usage: <prettyTableObject> setcolumn <col_index> <column>
#------------------------------------------------------------------------
# Set an entire column by its index
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:setcolumn {self idx column} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Set a column
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows
  if {$idx == {end}} { set idx [expr [llength $header] -1] }
  if {[regexp {^end-([0-9]+)$} $idx - num]} { set idx [expr [llength $header] -1 - $num] }
  if {($idx < 0) || ($idx > [expr [llength $header] -1])} {
    puts " -W- column '$idx' out of bound"
    return {}
  }
  if {[llength $column] != [llength $table]} {
    puts " -W- invalid column length (length:[llength $column] / table:[llength $table] )"
    return {}
  }
  for {set r 0} {$r < [llength $table]} {incr r} {
    set L [lindex $table $r]
    set table [lreplace $table $r $r [lreplace $L $idx $idx [lindex $column $r]] ]
  }
  return $column
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:getcolumns
#------------------------------------------------------------------------
# Usage: <prettyTableObject> getcolumns <list_of_column_indexes>
#------------------------------------------------------------------------
# Return a list of column(s)
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:getcolumns {self columns} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Return a list of column(s)
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows
  if {$columns == {}} {
    return {}
  }
  set res [list]
  foreach row $table {
    set L [list]
    foreach col $columns {
      if {[llength $columns] == 1} {
        # Single column: flatten the list to avoid a list of list
        set L [lindex $row $col]
      } else {
        lappend L [lindex $row $col]
      }
    }
    lappend res $L
  }
  return $res
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:getrow
#------------------------------------------------------------------------
# Usage: <prettyTableObject> getrow <row_index>
#------------------------------------------------------------------------
# Return a row by index
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:getrow {self index} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Return a row
  upvar #0 ${self}::table table
  return [lindex $table $index]
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:settable
#------------------------------------------------------------------------
# Usage: <prettyTableObject> settable
#------------------------------------------------------------------------
# Set the entire table
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:settable {self rows} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Set the table content
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows
  set table $rows
  set numRows [llength $rows]
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:gettable
#------------------------------------------------------------------------
# Usage: <prettyTableObject> gettable
#------------------------------------------------------------------------
# Return the entire table
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:gettable {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Return the table
  upvar #0 ${self}::table table
  return $table
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:numrows
#------------------------------------------------------------------------
# Usage: <prettyTableObject> numrows
#------------------------------------------------------------------------
# Return the number of rows of the table
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:numrows {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Get the number of rows
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows
  set numRows [llength $table]
  return $numRows
#   return [llength [subst $${self}::table]]
#   return [subst $${self}::numRows]
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:numcols
#------------------------------------------------------------------------
# Usage: <prettyTableObject> numcols
#------------------------------------------------------------------------
# Return the number of columns of the table
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:numcols {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Get the number of columns
  return [llength [subst $${self}::header]]
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:indent
#------------------------------------------------------------------------
# Usage: <prettyTableObject> indent [<value>]
#------------------------------------------------------------------------
# Set/get the indent level for the table
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:indent {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Set the indent level for the table
  if {$args != {}} {
    set ${self}::params(indent) $args
  } else {
    # If no argument is provided then return the current indent level
  }
  set ${self}::params(indent)
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:get_param
#------------------------------------------------------------------------
# **HIDDEN**
#------------------------------------------------------------------------
# Usage: <prettyTableObject> get_param <param>
#------------------------------------------------------------------------
# Get a parameter from the 'params' associative array
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:get_param {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  if {[llength $args] != 1} {
    error " -E- wrong number of parameters: <prettyTableObject> get_param <param>"
  }
  if {![info exists ${self}::params([lindex $args 0])]} {
    error " -E- unknown parameter '[lindex $args 0]'"
  }
  return [subst $${self}::params([lindex $args 0])]
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:set_param
#------------------------------------------------------------------------
# **HIDDEN**
#------------------------------------------------------------------------
# Usage: <prettyTableObject> set_param <param> <value>
#------------------------------------------------------------------------
# Set a parameter inside the 'params' associative array
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:set_param {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  if {[llength $args] < 2} {
    error " -E- wrong number of parameters: <prettyTableObject> set_param <param> <value>"
  }
  set ${self}::params([lindex $args 0]) [lindex $args 1]
  return 0
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:separator
#------------------------------------------------------------------------
# Usage: <prettyTableObject> separator [<row_indexes>]
#------------------------------------------------------------------------
# Add a separator after the last inserted row
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:separator {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Add a row separator (?)
  if {[lsearch {-h -help ?} [lindex $args 0]] != -1} {
    puts [format {  Usage: <prettyTableObject> separator [<row_indexes>]}]
    puts [format {  When no <row_indexes> is specified, add separator after last inserted row }]
    puts [format {  Add separator after each row specified inside <row_indexes> }]
    puts [format {  When not specified, add separator after last inserted row }]
    puts [format {  Use ' <prettyTableObject> configure -remove_separator' to remove separators}]
    return -code ok
  }

  if {[subst $${self}::numRows] > 0} {
    if {$args != {}} {
      # The row number is passed as parameter
      foreach row $args {
        eval lappend ${self}::separators $row
      }
    } else {
      # Add the current row number to the list of separators
      eval lappend ${self}::separators [subst $${self}::numRows]
    }
  }
  return 0
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:cleartable
#------------------------------------------------------------------------
# Usage: <prettyTableObject> cleartable
#------------------------------------------------------------------------
# Clear table content
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:cleartable {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Clear table content
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows
  set tmp $header
  set col0 [$self getcolumns 0]
  # Clear table content by creating an empty matrix
  $self creatematrix [llength $header] [llength $table]
  # Restore header
  $self header $tmp
  # Restore first column if the table was created from the template 'deviceview'
  set template [$self get_param {template}]
  switch $template {
    device -
    deviceview {
      $self setcolumn 0 $col0
    }
  }
  return $self
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:rebuild
#------------------------------------------------------------------------
# Usage: <prettyTableObject> rebuild
#------------------------------------------------------------------------
# Rebuild the table content. Fixes issues that can result with some of
# the methods when some of the rows have different lengths. It can also
# be used to readjust the table rows when the table header is changed
# (augmented or reduced).
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:rebuild {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Rebuild the table
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows
  set L [list]
  set size [expr [llength $header] -1]
  set emptyrow [list]
  for {set i 0} {$i <= $size} {incr i} {
    lappend emptyrow {}
  }
  # Iterate through each row
  foreach row $table {
    # Reformat the row: make sure it has the exact number of elements as the length of the table header
    set row [lrange [concat $row $emptyrow] 0 $size]
    lappend L $row
  }
  $self settable $L
  return $self
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:reset
#------------------------------------------------------------------------
# Usage: <prettyTableObject> reset
#------------------------------------------------------------------------
# Reset the object to an empty one. All the data of that object are lost
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:reset {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Reset object and empty all the data
  set ${self}::header [list]
  set ${self}::table [list]
  set ${self}::separators [list]
  set ${self}::history [list]
  set ${self}::numRows 0
  catch {unset ${self}::params}
  array set ${self}::params $::tclapp::xilinx::designutils::prettyTable::params
#   set ${self}::params(indent) 0
  return 0
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:destroy
#------------------------------------------------------------------------
# Usage: <prettyTableObject> destroy
#------------------------------------------------------------------------
# Destroy an object and release its memory footprint. The object is not
# accessible anymore after that command
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:destroy {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Destroy object
  set ${self}::header [list]
  set ${self}::table [list]
  set ${self}::separators [list]
  set ${self}::history [list]
  set ${self}::numRows 0
  catch {unset ${self}::params}
  namespace delete $self
  return 0
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:sizeof
#------------------------------------------------------------------------
# Usage: <prettyTableObject> sizeof
#------------------------------------------------------------------------
# Return the memory footprint of the object
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:sizeof {ns args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Return memory footprint of the object
  set sum [expr wide(0)]
  foreach var [info vars ${ns}::*] {
      if {[info exists $var]} {
          upvar #0 $var v
          if {[array exists v]} {
              incr sum [string bytelength [array get v]]
          } else {
              incr sum [string bytelength $v]
          }
      }
  }
  foreach child [namespace children $ns] {
      incr sum [::tclapp::xilinx::designutils::prettyTable::method:sizeof $child]
  }
  set sum
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:print
#------------------------------------------------------------------------
# Usage: <prettyTableObject> print [<options>]
#------------------------------------------------------------------------
# Return the printed table
#------------------------------------------------------------------------
#
# Sample of 'classic' table
# =========================
#
#   +-------------------------------------------------------------------------------------+
#   | Pin Slack                                                                           |
#   +-------------------------------------+---------+----------+-------------+------------+
#   | NAME                                | IS_LEAF | IS_CLOCK | SETUP_SLACK | HOLD_SLACK |
#   +-------------------------------------+---------+----------+-------------+------------+
#   | or1200_wbmux/muxreg_reg[4]_i_45/I5  | 1       | 0        | 10.000      | 3.266      |
#   | or1200_mult_mac/p_1_out__2_i_9/I2   | 1       | 0        | 9.998       | 1.024      |
#   | or1200_wbmux/muxreg_reg[3]_i_52/I1  | 1       | 0        | 9.993       | 2.924      |
#   | or1200_wbmux/muxreg_reg[14]_i_41/I2 | 1       | 0        | 9.990       | 3.925      |
#   | or1200_wbmux/muxreg_reg[4]_i_45/I5  | 1       | 0        | 10.000      | 3.266      |
#   +-------------------------------------+---------+----------+-------------+------------+
#   | or1200_wbmux/muxreg_reg[4]_i_45/I5  | 1       | 0        | 10.000      | 3.266      |
#   | or1200_wbmux/muxreg_reg[4]_i_45/I5  | 1       | 0        | 10.000      | 3.266      |
#   +-------------------------------------+---------+----------+-------------+------------+
#
# Sample of 'lean' table
# ======================
#
#   +--------------------------------------------------------------------------
#   | Pin Slack
#   +--------------------------------------------------------------------------
#
#   NAME                                 IS_LEAF  IS_CLOCK  SETUP_SLACK  HOLD_SLACK
#   -----------------------------------  -------  --------  -----------  ----------
#   or1200_wbmux/muxreg_reg[4]_i_45/I5   1        0         10.000       3.266
#   or1200_mult_mac/p_1_out__2_i_9/I2    1        0         9.998        1.024
#   or1200_wbmux/muxreg_reg[3]_i_52/I1   1        0         9.993        2.924
#   or1200_wbmux/muxreg_reg[14]_i_41/I2  1        0         9.990        3.925
#   or1200_wbmux/muxreg_reg[4]_i_45/I5   1        0         10.000       3.266
#   -----------------------------------  -------  --------  -----------  ----------
#   or1200_wbmux/muxreg_reg[4]_i_45/I5   1        0         10.000       3.266
#   or1200_wbmux/muxreg_reg[4]_i_45/I5   1        0         10.000       3.266
#
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:print {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Print table. The output can be captured in a variable (-help)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::separators separators
  upvar #0 ${self}::params params
  upvar #0 ${self}::numRows numRows
  set indent $params(indent)

  set error 0
  set help 0
  set filename {}
  set startRow 0
  set endRow {end}
  set onlyRows [list]
  set printHeader 1
  set printTitle 1
#   set align {-} ; # '-' for left cell alignment and '' for right cell alignment
  if {$params(cellAlignment) == {left}} { set align {-} } else { set align {} } ; # '-' for left cell alignment and '' for right cell alignment
#   set format {classic} ; # table format: classic|lean
  set format $params(tableFormat) ; # table format: classic|lean
  set append 0
  set returnVar {}
  set columnsToDisplay $params(columnsToDisplay)
  set printNextTo {}
  set showColIndexes 0
  set splitTable -1
  set splitTableCmdLine [list]
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-file$} -
      {^-fi(le?)?$} {
         set filename [lshift args]
      }
      {^-append$} -
      {^-a(p(p(e(nd?)?)?)?)?$} {
        set append 1
      }
      {^-from_row$} -
      {^-fr(o(m(_(r(ow?)?)?)?)?)?$} {
        set startRow [lshift args]
      }
      {^-to_row$} -
      {^-to(_(r(ow?)?)?)?$} {
        set endRow [lshift args]
      }
      {^-rows$} -
      {^-ro(ws?)?$} {
        set onlyRows [lshift args]
      }
      {^-head$} -
      {^-he(ad?)?$} {
        set n [lshift args]
        set startRow 0
        set endRow [min [expr $n - 1] [expr $numRows - 1] ]
      }
      {^-tail$} -
      {^-ta(il?)?$} {
        set n [lshift args]
        set startRow [max 0 [expr $numRows - $n] ]
        set endRow {end}
      }
      {^-split_table$} -
      {^-sp(l(i(t(_(t(a(b(le?)?)?)?)?)?)?)?)?$} {
        set splitTable [lshift args]
      }
      {^-return_var$} -
      {^-re(t(u(r(n(_(v(ar?)?)?)?)?)?)?)?$} {
        set returnVar [lshift args]
      }
      {^-columns$} -
      {^-co(l(u(m(ns?)?)?)?)?$} {
        set columnsToDisplay [lshift args]
        lappend splitTableCmdLine {-columns}
        lappend splitTableCmdLine $columnsToDisplay
      }
      {^-noheader$} -
      {^-noh(e(a(d(er?)?)?)?)?$} {
        set printHeader 0
        lappend splitTableCmdLine {-noheader}
      }
      {^-left$} -
      {^-le(ft?)?$} -
      {^-align_left$} -
      {^-align_l(e(ft?)?)?$} {
        set align {-}
        lappend splitTableCmdLine {-align_left}
      }
      {^-right$} -
      {^-ri(g(ht?)?)?$} -
      {^-align_right$} -
      {^-align_r(i(g(ht?)?)?)?$} {
        set align {}
        lappend splitTableCmdLine {-align_right}
      }
      {^-lean$} -
      {^-le(an?)?$} {
        set format {lean}
        lappend splitTableCmdLine {-lean}
      }
      {^-classic$} -
      {^-cl(a(s(s(ic?)?)?)?)?$} {
        set format {classic}
        lappend splitTableCmdLine {-classic}
      }
      {^-compact$} -
      {^-co(m(p(a(ct?)?)?)?)?$} {
        set format {compact}
        lappend splitTableCmdLine {-compact}
      }
      {^-format$} -
      {^-fo(r(m(at?)?)?)?$} {
        set format [lshift args]
        lappend splitTableCmdLine {-format}
        lappend splitTableCmdLine $format
      }
      {^-next_to$} -
      {^-ne(x(t(_(to?)?)?)?)?$} {
        set printNextTo [lshift args]
      }
      {^-indent$} -
      {^-in(d(e(nt?)?)?)?$} {
        set indent [lshift args]
        lappend splitTableCmdLine {-indent}
        lappend splitTableCmdLine $indent
      }
      {^-notitle$} -
      {^-not(i(t(le?)?)?)?$} {
        set printTitle 0
        lappend splitTableCmdLine {-notile}
      }
      {^\?$} -
      {^-help$} -
      {^-h(e(lp?)?)?$} {
        set help 1
      }
      {^-header$} -
      {^-he(a(d(er?)?)?)?$} {
        # Hidden ommand line option to be compatible with 'export' method
        set printHeader [lshift args]
      }
      {^-title$} -
      {^-ti(t(le?)?)?$} {
        # Hidden ommand line option to be compatible with 'export' method
        set printTitle [lshift args]
      }
      {^-show_column_indexes$} -
      {^-sh(o(w(_(c(o(l(u(m(n(_(i(n(d(e(x(es?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?$} {
        set showColIndexes 1
      }
      {^-delimiter$} -
      {^-d(e(l(i(m(i(t(er?)?)?)?)?)?)?)?$} -
      {^-verbose$} -
      {^-v(e(r(b(o(se?)?)?)?)?)?$} {
        # Hidden ommand line option to be compatible with 'export' method
        # Do nothing but removing next argument. Not supported for this context
        lshift args
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
  Usage: <prettyTableObject> print
              [-file <filename>]
              [-append]
              [-return_var <tcl_var_name>]
              [-columns <list_of_columns_to_display>]
              [-from_row <start_row_index>][-to_row <end_row_index>][-rows <row_indexes>][-head <num>][-tail <num>]
              [-align_left|-left]
              [-align_right|-right]
              [-format classic|lean|compact][-lean][-classic][-compact]
              [-indent <indent_level>]
              [-next_to <string>]
              [-noheader]
              [-notitle]
              [-show_column_indexes]
              [-split_table <num_rows>]
              [-help|-h]

  Description: Return table content

    -columns: unordered list of columns to display. Other columns are hidden
    -indent: indent table
    -next_to: print table on the right side of another table. Use -indent to
      leave increase space(s) between both tables
    -show_column_indexes: show the column indexes in the table header
    -from_row/-to_row/-rows/-head/-tail: control the number of rows that are reported
    -split_table: specify the max number of rows. Split the table into side-by-side tables

  Example:
     <prettyTableObject> print
     <prettyTableObject> print -columns {0 2 5}
     <prettyTableObject> print -return_var report
     <prettyTableObject> print -file output.rpt -append
     <prettyTableObject> print -indent 1 -next_to [<prettyTableObject> print]

} ]
    # HELP -->
    return {}
  }

  switch $format {
    nospacing {
      set gap {}
    }
    compact {
      set gap { }
    }
    lean {
      set gap {  }
    }
    classic {
    }
    default {
      puts " -E- invalid format '$format'. The valid formats are: classic|lean|compact"
      incr error
    }
  }

  if {[llength $onlyRows] && (($startRow != 0) || ($endRow != {end}))} {
    puts " -E- -rows and -from_row/-to_row are exclusive"
    incr error
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  # The -return_var option provides the variable name from the caller's environment
  # that should receive the report
  if {$returnVar != {}} {
    # The caller's environment is 2 levels up
    upvar 2 $returnVar res
  }
  set res {}

  # Build the list of columns to be displayed
  if {$columnsToDisplay == {}} {
    # If empty, then all the columns are displayed. Build the list of all columns
    for {set index 0} {$index < [llength $header]} {incr index} {
      lappend columnsToDisplay $index
    }
  }

  # No header has been defined
  if {[llength $header] == 0} {
    puts " -E- NO HEADER DEFINED"
    return {}
  }

  # <-- -split_table: split the table into multiple side-by-side tables
  if {$splitTable != -1} {
    set numRowsToDisplay $splitTable
    set idx $startRow
    set report {}
    if {$endRow == {end}} {
      set lastRow [expr [$self numrows] -1]
    } else {
      set lastRow $endRow
    }
    while 1 {
      if {$idx > $lastRow} { break }
      if {[expr $idx + $numRowsToDisplay] <= $lastRow} {
        set report [$self print {*}$splitTableCmdLine -from_row $idx -to_row [expr $idx + $numRowsToDisplay -1] -next_to $report]
      } else {
        set report [$self print {*}$splitTableCmdLine -from_row $idx -to_row $lastRow -next_to $report]
      }
      set idx [expr $idx + $numRowsToDisplay]
    }

    # The 'res' variable is important when -return_var is specified
    set res $report
    if {$filename != {}} {
      if {$append} {
        set FH [open $filename a]
      } else {
        set FH [open $filename w]
      }
      puts $FH $res
      close $FH
      return
    }
    if {$returnVar != {}} {
      # The report is returned through the upvar
      return {}
    } else {
      return $res
    }
  }
  # End of -split_table -->

  set maxs {}
  set idx -1
  foreach item $header {
    incr idx
    if {$showColIndexes} {
      # Format" <columnName> (<columnIndex>)
      lappend maxs [string length "$item ($idx)"]
    } else {
      lappend maxs [string length $item]
    }
  }
  set numCols [llength $header]
  set count 0
  set maxNumRowsToDisplay [subst $${self}::params(maxNumRowsToDisplay)]
  foreach row [lrange $table $startRow $endRow] {
    incr count
    if {[llength $onlyRows] && ([lsearch $onlyRows [expr $count -1]] == -1)} {
      # Row index is not in the list of indexes specified with -rows
      # Row index start at 0 => $count-1
      continue
    }
    if {($count > $maxNumRowsToDisplay) && ($maxNumRowsToDisplay != -1)} {
      # Did we reach the maximum of rows to be displayed?
      break
    }
    for {set j 0} {$j<$numCols} {incr j} {
      set item [lindex $row $j]
      set max [lindex $maxs $j]
      if {[string length $item]>$max} {
        lset maxs $j [string length $item]
      }
    }
  }
  # Create the row separator string
  set indentString [string repeat " " $indent]
  switch $format {
    nospacing -
    compact -
    lean {
      set separator "${indentString}"
    }
    classic {
      set separator "${indentString}+"
    }
  }
  # Build the separator string based on the list of columns to be displayed
#   foreach max $maxs { append separator "-[string repeat - $max]-+" }
  for {set index 0} {$index < $numCols} {incr index} {
    if {[lsearch $columnsToDisplay $index] == -1} { continue }
    switch $format {
      nospacing -
      compact -
      lean {
        append separator "[string repeat - [lindex $maxs $index]]${gap}"
      }
      classic {
        append separator "-[string repeat - [lindex $maxs $index]]-+"
      }
    }
  }
  if {$printTitle} {
    # Generate the title
    if {$params(title) ne {}} {
      # The upper separator should something like +----...----+
      switch $format {
        nospacing -
        compact -
        lean {
          append res "${indentString}+[string repeat - [expr [string length $separator] - [string length $indentString] -2]]\n"
        }
        classic {
          append res "${indentString}+[string repeat - [expr [string length $separator] - [string length $indentString] -2]]+\n"
        }
      }
      # Support multi-lines title
      foreach line [split $params(title) \n] {
        append res "${indentString}| "
        append res [format "%-[expr [string length $separator] - [string length $indentString] -4]s" $line]
        switch $format {
          nospacing -
          compact -
          lean {
            append res " \n"
          }
          classic {
            append res " |\n"
          }
        }
      }
      switch $format {
        nospacing -
        compact -
        lean {
          append res "${indentString}+[string repeat - [expr [string length $separator] - [string length $indentString] -2]]\n\n"
        }
        classic {
#           append res "${indentString}+[string repeat - [expr [string length $separator] - [string length $indentString] -2]]+\n\n"
        }
      }
    }
  }
  if {$printHeader} {
    # Generate the table header
    switch $format {
      nospacing -
      compact -
      lean {
        append res "${indentString}"
      }
      classic {
        append res "${separator}\n"
        append res "${indentString}|"
      }
    }
    # Generate the table header based on the list of columns to be displayed
  #   foreach item $header max $maxs {append res [format " %-${max}s |" $item]}
    for {set index 0} {$index < $numCols} {incr index} {
      if {[lsearch $columnsToDisplay $index] == -1} { continue }
      switch $format {
        nospacing -
        compact -
        lean {
          if {$showColIndexes} {
            append res [format "%-[lindex $maxs $index]s${gap}" "[lindex $header $index] ($index)" ]
          } else {
            append res [format "%-[lindex $maxs $index]s${gap}" [lindex $header $index]]
          }
#           append res [format "%-[lindex $maxs $index]s  " [lindex $header $index]]
        }
        classic {
          if {$showColIndexes} {
            append res [format " %-[lindex $maxs $index]s |" "[lindex $header $index] ($index)" ]
          } else {
            append res [format " %-[lindex $maxs $index]s |" [lindex $header $index]]
          }
#           append res [format " %-[lindex $maxs $index]s |" [lindex $header $index]]
        }
      }
    }
    append res "\n"
  }
  append res "${separator}\n"
  # Generate the table rows
  set count 0
  foreach row [lrange $table $startRow $endRow] {
      incr count
      if {[llength $onlyRows] && ([lsearch $onlyRows [expr $count -1]] == -1)} {
        # Row index is not in the list of indexes specified with -rows
        # Row index start at 0 => $count-1
        continue
      }
      if {($count > $maxNumRowsToDisplay) && ($maxNumRowsToDisplay != -1)} {
        # Did we reach the maximum of rows to be displayed?
        break
      }
      switch $format {
        nospacing -
        compact -
        lean {
          append res "${indentString}"
        }
        classic {
          append res "${indentString}|"
        }
      }
      # Build the row string based on the list of columns to be displayed
#       foreach item $row max $maxs {append res [format " %-${max}s |" $item]}
      for {set index 0} {$index < $numCols} {incr index} {
        if {[lsearch $columnsToDisplay $index] == -1} { continue }
        switch $format {
          nospacing -
          compact -
          lean {
            append res [format "%${align}[lindex $maxs $index]s${gap}" [lindex $row $index]]
          }
          classic {
            append res [format " %${align}[lindex $maxs $index]s |" [lindex $row $index]]
          }
        }
      }
      append res \n
      # Check if a separator has been assigned to this row number and add a separator
      # if so.
      if {[lsearch $separators $count] != -1} {
        append res "$separator\n"
      }
  }
  # Add table footer only if the last row does not have a separator defined, otherwise the separator
  # is printed twice
  if {[lsearch $separators $count] == -1} {
    switch $format {
      nospacing -
      compact -
      lean {
      }
      classic {
        append res $separator
      }
    }
  }

  # By by side printing: the table is printed on the right side of the provided string
  if {$printNextTo != {}} {
    set sideLeft [split $printNextTo \n]
    set sideRight [split $res \n]
    set L [list]
    foreach line $sideLeft {
      lappend L [string length $line]
    }
    # Extract the maximum line length of $sideLeft
    set maxLineLength [expr max([join $L ,])]
    set L [list]
    # Process $sideLeft and $sideRight line-by-line
    for {set linenum 0} {$linenum < [max [llength $sideLeft] [llength $sideRight]]} {incr linenum} {
      # Start with $sideLeft
      set line [lindex $sideLeft $linenum]
      # Add space to make sure that the line length matches the maximum line length of $sideLeft
      append line [string repeat { } [expr $maxLineLength - [string length $line]]]
      # Append the line from the table
      append line [format {%s} [lindex $sideRight $linenum]]
      lappend L $line
    }
    set res [join $L \n]
  }

  if {($count > $maxNumRowsToDisplay) && ($maxNumRowsToDisplay != -1)} {
    # Did we reach the maximum of rows to be displayed?
    append res "\n\n -W- Table truncated. Only the first [subst $${self}::params(maxNumRowsToDisplay)] rows are displayed\n"
  }
  if {$filename != {}} {
    if {$append} {
      set FH [open $filename a]
    } else {
      set FH [open $filename w]
    }
    puts $FH $res
    close $FH
    return
  }
  if {$returnVar != {}} {
    # The report is returned through the upvar
    return {}
  } else {
    return $res
  }
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:info
#------------------------------------------------------------------------
# Usage: <prettyTableObject> info
#------------------------------------------------------------------------
# List various information about the object
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:info {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Information about the object
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::params params
  upvar #0 ${self}::history history
  puts [format {    Header: %s} $header]
  puts [format {    # Cols: %s} [llength $header]]
  puts [format {    # Rows: %s} [subst $${self}::numRows] ]
  foreach param [lsort [array names params]] {
    puts [format {    Param[%s]: %s} $param $params($param)]
  }
  puts [format {    Memory footprint: %d bytes} [::tclapp::xilinx::designutils::prettyTable::method:sizeof $self]]
#   puts [format {    History (%s)} [llength $history] ]
#   foreach el $history {
#     puts [format {        %s} $el]
#   }
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:trim
#------------------------------------------------------------------------
# Usage: <prettyTableObject> trim
#------------------------------------------------------------------------
# Trim the table
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:trim {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Trim the table (?)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::params params

  if {([llength $args] == 0) || (([llength $args] != 1) && ([llength $args] != 3))} { set args {-help} }
  if {[lsearch {-h -help ?} $args] != -1} {
    puts [format {  Usage: <prettyTableObject> trim <max> [-ellipsis 0|1]}]
    puts [format {         -ellipsis 1: add ellipsis as last row}]
    puts [format {         -ellipsis 0 (default): don't add ellipsis}]
    return -code ok
  }

  set max [lindex $args 0]
  array set defaults [list \
      -ellipsis 0 \
    ]
  array set options [array get defaults]
  array set options [lrange $args 1 end]

  if {[subst $${self}::numRows] <=  $max} {
    return $self
  }
  eval set ${self}::table [list [lrange [subst $${self}::table] 0 [expr $max -1] ] ]
  if {$options(-ellipsis)} {
    # Adding the ellipsis row
    set row [list]
    foreach el [subst $${self}::header] {
      lappend row {...}
    }
    eval lappend ${self}::table [list $row]
  } else {
  }
  eval set ${self}::numRows [llength $table]
  return $self
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:sort
#------------------------------------------------------------------------
# Usage: <prettyTableObject> [-real|-integer|-dictionary] [<COLUMN_HEADER>] [+<COLUMN_HEADER>] [-<COLUMN_HEADER>]
#------------------------------------------------------------------------
# Sort the table based on the specified column header. The table can
# be sorted ascending or descending
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:sort {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Sort the table based on one or more column headers (-help)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::params params
  set direction {-increasing}
  set sortType {-dictionary}
  set column {}
  set command {}
  set indexes [list]
  set help 0
  if {[llength $args] == 0} { set help 1 }
  foreach elm $args {
    if {[regexp {^(\-h(elp)?)$} $elm] || [regexp {^\?$} $elm]} {
      set help 1
      break
    } elseif {[regexp {^(\-real)$} $elm]} {
      set sortType {-real}
    } elseif {[regexp {^(\-integer)$} $elm]} {
      set sortType {-integer}
    } elseif {[regexp {^(\-dictionary)$} $elm]} {
      set sortType {-dictionary}
    } elseif {[regexp {^(\+)(.+)$} $elm -- - column]} {
      set direction {-increasing}
    } elseif {[regexp {^(\-)(.+)$} $elm -- - column]} {
      set direction {-decreasing}
    } elseif {[regexp {^(.+)$} $elm -- column]} {
      set direction {-increasing}
    } else {
      continue
    }
    if {$column == {}} { continue }
    if {[regexp {^[0-9]+$} $column]} {
      # A column number is provided, nothing further to do
      set index $column
    } else {
      # A header name has been provided. It needs to be converted
      # as a column number
      set index [lsearch -nocase $header $column]
      if {$index == -1} {
        puts " -E- unknown column header '$column'"
        continue
      }
    }
    # Save the column and direction for each column
    lappend indexes [list $index $direction $sortType]
    # Reset default direction and column
    set direction {-increasing}
    set column {}
  }

  if {$help} {
    puts [format {
  Usage: <prettyTableObject> sort
              [-real|-integer|-dictionary]
              [-<COLUMN_NUMBER>|+<COLUMN_NUMBER>|<COLUMN_NUMBER>]
              [-<COLUMN_HEADER>|+<COLUMN_HEADER>|<COLUMN_HEADER>]
              [-help|-h]

  Description: Sort the table based on one or multiple column headers.

    -real/-integer/-dictionary are sticky and apply to the column(s)
    specified afterward. They can be used multiple times to sort columns
    of different types.

  Example:
     <prettyTableObject> sort +SLACK
     <prettyTableObject> sort -integer -FANOUT
     <prettyTableObject> sort -integer -2 +1 -SLACK
     <prettyTableObject> sort -integer -2 -dictionary +1 -real -SLACK
     <prettyTableObject> sort +SETUP_SLACK -HOLD_SLACK
} ]
    # HELP -->
    return {}
  }

#   foreach item [lrevert $indexes] {}
  foreach item [::tclapp::xilinx::designutils::prettyTable::lrevert $indexes] {
    foreach {index direction sortType} $item { break }
    set options {}
    switch $sortType {
      -integer -
      -real {
        # Use special commands to sort real/integers to handle heterogeneous data
        if {$direction == {-increasing}} {
          set options "-command sort_double_incr"
        } else {
          set options "-command sort_double_decr"
        }
      }
      default {
        # For -dictionary
        set options "$direction $sortType"
      }
    }
    if {$command == {}} {
      set command "lsort $options -index $index \$table"
    } else {
      set command "lsort $options -index $index \[$command\]"
    }
  }
  if {[catch { set table [eval $command] } errorstring]} {
    puts " -E- Sorting indexes '$indexes': $errorstring"
  } else {
    # Since the rows are sorted, the separators don't mean anything anymore, so remove them
    set ${self}::separators [list]
#     puts " -I- Sorting indexes '$indexes' completed"
  }
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:transpose
#------------------------------------------------------------------------
# Usage: <prettyTableObject> transpose
#------------------------------------------------------------------------
# Transpose the table
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:transpose {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Transpose the table
  upvar #0 ${self}::table rows
  upvar #0 ${self}::header header
  upvar #0 ${self}::title title
  upvar #0 ${self}::numRows numrows
  upvar #0 ${self}::separators separators

  if {[lsort -unique $header] == [list {}]} {
    # Empty header. The matrix is only made of the table rows
    set matrix $rows
  } else {
    # If header defined, include it in the matrix along with the
    # table rows
    set matrix [concat [list $header] $rows]
  }

  # Create template of an empty row for the transposed matrix
  # (number of rows of current table)
  set row {}
  set transpose {}
  foreach r $matrix {
    lappend row {}
  }
  # Create empty transposed matrix
  foreach c [lindex $matrix 0] {
    lappend transpose $row
  }

  # Transpose the matrix: rows become columns
  set nr 0
  foreach r $matrix {
    set nc 0
    foreach c $r {
      lset transpose [list $nc $nr] $c
      incr nc
    }
    incr nr
  }

#   # Re-create a header with format: header row0 row1 ... rowN
#   set header {header}
#   set n -1
#   foreach el [lrange $row 1 end] {
#     lappend header [format {row%d} [incr n]]
#   }
#   # Save the transposed matrix
#   set rows $transpose
#   # Update the number of rows
#   set numrows [llength $transpose]

  # The header is the first row of the transposed matrix
  set header [lindex $transpose 0]
  # Save the transposed matrix
  set rows [lrange $transpose 1 end]
  # Update the number of rows
  set numrows [llength $rows]
  # Remove separators
  set separators [list]

  return 0
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:configure
#------------------------------------------------------------------------
# Usage: <prettyTableObject> configure [<options>]
#------------------------------------------------------------------------
# Configure some of the object parameters
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:configure {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Configure object (-help)
  set error 0
  set help 0
  if {[llength $args] == 0} {
    set help 1
  }
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-title$} -
      {^-t(i(t(le?)?)?)?$} {
        set ${self}::params(title) [lshift args]
      }
      {^-left$} -
      {^-le(ft?)?$} -
      {^-align_left$} -
      {^-align_l(e(ft?)?)?$} {
        set ${self}::params(cellAlignment) {left}
      }
      {^-right$} -
      {^-ri(g(ht?)?)?$} -
      {^-align_right$} -
      {^-align_r(i(g(ht?)?)?)?$} {
        set ${self}::params(cellAlignment) {right}
      }
      {^-align$} -
      {^-al(i(gn?)?)?$} {
        set ${self}::params(cellAlignment) [lshift args]
      }
      {^-lean$} -
      {^-le(a(n?)?)?$} {
        set ${self}::params(tableFormat) {lean}
      }
      {^-classic$} -
      {^-cl(a(s(s(ic?)?)?)?)?$} {
        set ${self}::params(tableFormat) {classic}
      }
      {^-format$} -
      {^-fo(r(m(at?)?)?)?$} {
        set format [lshift args]
        switch $format {
          lean -
          classic {
             set ${self}::params(tableFormat) $format
          }
          default {
            puts " -E- invalid format '$format'. The valid formats are: classic|lean"
            incr error
          }
        }
      }
      {^-indent$} -
      {^-in(d(e(nt?)?)?)?$} {
        set ${self}::params(indent) [lshift args]
      }
      {^-limit$} -
      {^-li(m(it?)?)?$} {
        set ${self}::params(maxNumRows) [lshift args]
      }
      {^-display_limit$} -
      {^-di(s(p(l(a(y(_(l(i(m(it?)?)?)?)?)?)?)?)?)?)?$} {
        set ${self}::params(maxNumRowsToDisplay) [lshift args]
      }
      {^-origin$} -
      {^-or(i(g(in?)?)?)?$} {
        set origin [lshift args]
        if {[lsearch [list topleft topright bottomleft bottomright ] $origin] != -1} {
          set ${self}::params(origin) $origin
        } else {
          puts " -W- invalid value '$origin' for -origin. Valid values are: topleft topright bottomleft bottomright"
        }
      }
      {^-offsetx?$} {
        set ${self}::params(offsetx) [lshift args]
      }
      {^-offsety?$} {
        set ${self}::params(offsety) [lshift args]
      }
      {^-remove_separators$} -
      {^-re(m(o(v(e(_(s(e(p(a(r(a(t(o(rs?)?)?)?)?)?)?)?)?)?)?)?)?)?)?$} {
        set ${self}::separators [list]
      }
      {^-display_column$} -
      {^-di(s(p(l(a(y(_(c(o(l(u(m(ns?)?)?)?)?)?)?)?)?)?)?)?)?$} {
        set ${self}::params(columnsToDisplay) [lshift args]
      }
      {^\?$} -
      {^-help$} -
      {^-h(e(lp?)?)?$} {
        set help 1
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
  Usage: <prettyTableObject> configure
              [-title <string>]
              [-format classic|lean][-lean][-classic]
              [-align_left|-left]
              [-align_right|-right]
              [-indent <indent_level>]
              [-limit <max_number_of_rows>]
              [-display_columns <list_of_columns_to_display>]
              [-display_limit <max_number_of_rows_to_display>]
              [-remove_separators]
              [-origin <topleft|topright|bottomleft|bottomright>]
              [-offsetx <num>][-offsety <num>]
              [-help|-h]

  Description: Configure some of the internal parameters.

    -origin: set the origin of coordinates for setcells/getcells/appendcells/prependcells
      Valid values are: topleft|topright|bottomleft|bottomright
      Default value is: topleft
    -offsetx/-offsety: offset added to coordinates for setcells/getcells/appendcells/prependcells

  Example:
     <prettyTableObject> configure -format lean -align_right
     <prettyTableObject> configure -indent 2
     <prettyTableObject> configure -display_columns {0 2 3 6}
} ]
    # HELP -->
    return {}
  }

}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:clone
#------------------------------------------------------------------------
# Usage: <prettyTableObject> clone
#------------------------------------------------------------------------
# Clone the object and return the cloned object. The original object
# is not modified
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:clone {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Clone object. Return new object
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::params params
  upvar #0 ${self}::separators separators
  upvar #0 ${self}::numRows numRows
  set tbl [::tclapp::xilinx::designutils::prettyTable::Create]
  set ${tbl}::header $header
  set ${tbl}::table $table
  set ${tbl}::separators $separators
  set ${tbl}::numRows $numRows
  array set ${tbl}::params [array get params]
  return $tbl
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:arrayset
#------------------------------------------------------------------------
# Usage: <prettyTableObject> arrayset <TclVar>
#------------------------------------------------------------------------
# Copy the table content inside a Tcl array
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:arrayset {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Save the table content inside a Tcl array (?)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows

  if {([llength $args] == 0) || ([llength $args] > 1)} { set args {-help} }
  if {[lsearch {-h -help ?} [lindex $args 0]] != -1} {
    puts [format {  Usage: <prettyTableObject> arrayset <TclVar>}]
    return -code ok
  }

  # Variable passed as reference
  set _var [lindex $args 0]
  upvar 2 $_var var
  catch {unset var}
  for {set r 0} {$r < $numRows} {incr r} {
    for {set c 0} {$c < [llength $header]} {incr c} {
      set var(${c},${r}) [$self getcells $c $r]
    }
  }
  set var(header) $header
  set var(title) [$self title]
  set var(numrows) [llength $table]
  set var(numcols) [llength $header]
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:arrayget
#------------------------------------------------------------------------
# Usage: <prettyTableObject> arrayget <TclVar>
#------------------------------------------------------------------------
# Restore the content of the Tcl array into the table
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:arrayget {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Save the content of a Tcl array inside the table (?)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows

  if {([llength $args] == 0) || ([llength $args] > 1)} { set args {-help} }
  if {[lsearch {-h -help ?} [lindex $args 0]] != -1} {
    puts [format {  Usage: <prettyTableObject> arrayget <TclArrayVar>}]
    return -code ok
  }

  # Check that the variable passed as reference is a Tcl array
  set _var [lindex $args 0]
  upvar 2 $_var var
  if {![array exists var]} {
    puts " -E- variable '$_var' is not a Tcl array"
    return -code ok
  }

  set cols [list]
  set rows [list]
  foreach key [array names var] {
    if {[regexp {^([0-9]+),([0-9]+)$} $key - c r]} {
      lappend rows $r
      lappend cols $c
    }
  }
  set rows [lsort -unique -integer $rows]
  set cols [lsort -unique -integer $cols]
# puts "rows: [lindex $rows 0] -> [lindex $rows end]"
# puts "cols: [lindex $cols 0] -> [lindex $cols end]"
  $self creatematrix [expr [lindex $cols end] +1] [expr [lindex $rows end] +1]
  for {set r 0} {$r <= [lindex $rows end]} {incr r} {
    for {set c 0} {$c <= [lindex $cols end]} {incr c} {
      if {[info exists var(${c},${r})]} {
        $self setcells $c $r $var(${c},${r})
      }
    }
  }
  # Restore title (if exists)
  if {[info exists var(title)]} {
    $self title $var(title)
  } else {
    $self title {}
  }
  # Restore header (if exists)
  if {[info exists var(header)]} {
    set header $var(header)
  } else {
    set header [list]
    for {set c 0} {$c <= [lindex $cols end]} {incr c} {
      lappend header c${c}
    }
  }
  set numRows [llength $table]
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:import
#------------------------------------------------------------------------
# Usage: <prettyTableObject> import [<options>]
#------------------------------------------------------------------------
# Create the table from a CSV file or Tcl Dictionary
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:import {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Import table from CSV file or Tcl Dict (-help)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::params params
  upvar #0 ${self}::separators separators
  upvar #0 ${self}::numRows numRows

  set error 0
  set help 0
  set verbose 0
  set filename {}
  set format {csv}
  set dictionary {}
  set csvHasHeader 1
  set importHeader 1
  set append 0
  set csvDelimiter {,}
  set inlineContent {}
  if {[llength $args] == 0} { incr help }
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-format$} -
      {^-fo(r(m(at?)?)?)?$} {
        set format [lshift args]
      }
      {^-csv$} -
      {^-csv?$} {
        set format {csv}
      }
      {^-dict$} -
      {^-di(ct?)?$} {
        set dictionary [lshift args]
        set format {dict}
      }
      {^-delimiter$} -
      {^-d(e(l(i(m(i(t(er?)?)?)?)?)?)?)?$} {
        set csvDelimiter [lshift args]
      }
      {^-file$} -
      {^-f(i(le?)?)?$} {
        set filename [lshift args]
      }
      {^-inline$} -
      {^-i(n(l(i(ne?)?)?)?)?$} {
        set inlineContent [lshift args]
        set format {csv}
      }
      {^-noheader$} -
      {^-n(o(h(e(a(d(er?)?)?)?)?)?)?$} {
        set csvHasHeader 0
      }
      {^-skip_header$} -
      {^-s(k(i(p(_(h(e(a(d(er?)?)?)?)?)?)?)?)?)?$} {
        set importHeader 0
      }
      {^-append$} -
      {^-a(p(p(e(nd?)?)?)?)?$} {
        set append 1
      }
      {^-verbose$} -
      {^-v(e(r(b(o(se?)?)?)?)?)?$} {
        set verbose 1
      }
      {^\?$} -
      {^-help$} -
      {^-h(e(lp?)?)?$} {
        set help 1
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
  Usage: <prettyTableObject> import
              [-format csv|dict][-csv]
              [-dict <dictionary>]
              [-file <filename>]
              [-inline <inline_CSV_content>]
              [-delimiter <csv_delimiter>]
              [-append]
              [-noheader]
              [-skip_header]
              [-verbose]
              [-help|-h]

  Description: Create table from CSV file or Tcl dictionary

    -file: input file. Gzip supported
    -format: import format. Default: csv
    -append: append CSV/Dict to the table
    -noheader: CSV file does not have header
    -skip_header: skip the CSV header
    -verbose: report the number of imported row(s)

  Example:
     <prettyTableObject> import -file table.csv
     <prettyTableObject> import -file table.csv -delimiter ,
     <prettyTableObject> import -inline {
"Pin","Slow Max","Slow Min","Fast Max","Fast Min"
"CLKDIV->CLK","0.418","0.345"
"CLK->CLKDIV","0.481","0.391"
"CLKOUT0","0.403","0.345","0.208","0.166"
"CLKOUT2","0.403","0.345","0.208","0.166"
     <prettyTableObject> import -format dict -file table.dict.gz
     <prettyTableObject> import -dict $dictionary
     <prettyTableObject> import -dict $dictionary -append
    }
} ]
    # HELP -->
    return {}
  }

  if {($filename != {}) && ![file exists $filename]} {
    puts " -E- file '$filename' does not exist"
    incr error
  }

  switch $format {
    csv {
    }
    dict {
      if {[file exists $filename]} {
        if {[regexp {.gz$} $filename]} {
          # gzip-ed file
          set FH [open "| zcat $filename" {r}]
        } else {
          set FH [open $filename {r}]
        }
        set dictionary [read $FH]
        close $FH
      }
      if {$dictionary == {}} {
        puts " -E- empty dictionary (-dict)"
        incr error
      } else {
        if {![dict exists $dictionary {header}]} {
          puts " -E- dictionary is missing header (key 'header')"
          incr error
        }
        if {![dict exists $dictionary {rows}]} {
          puts " -E- dictionary is missing row(s) (key 'rows')"
          incr error
        }
      }
    }
    default {
      puts " -E- invalid format '$format'. The valid formats are: csv|dict"
      incr error
    }
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  ## Import from Tcl Dictionary

  if {$format == {dict}} {
    if {$append} {
      if {[llength [dict get $dictionary {header}]] != [llength $header]} {
        puts " -E- the number of columns do not match (table:[llength $header] / import:[llength [dict get $dictionary {header}]])"
        return -code ok
      }
    } else {
      # Import from Tcl Dictionary
      set header [dict get $dictionary {header}]
    }
    # Save the number of rows from the original table (-append)
    set offset [llength $table]
    set limit $params(maxNumRows)
    if {$append} {
      # Append to the existing table
      set table [concat $table [dict get $dictionary {rows}] ]
    } else {
      set table [dict get $dictionary {rows}]
    }
    if {$limit != -1} {
      # Max number of rows has been specified
      set table [lrange [dict get $dictionary {rows}] 0 [expr $limit -1] ]
    }
    if {[dict exists $dictionary {separators}]} {
      if {!$append} {
        set separators [dict get $dictionary {separators}]
      } else {
        foreach el [dict get $dictionary {separators}] {
          # Need to offset the separator index by the number of rows from original table
          lappend separators [expr $el + $offset]
        }
      }
    } else {
      if {!$append} {
        # Reset seperators when -append is not used
        set separators {}
      }
    }
    if {[dict exists $dictionary {params}]} {
      if {!$append} {
        # Import param when -append is not used
        array set params [dict get $dictionary {params}]
      }
    }
    # Update number of rows
    $self numrows
    if {$verbose} {
      puts " -I- Number of imported row(s): $numRows"
    }
    return -code ok
  }

  ## Import from CSV

  if {$filename != {}} {
    # Reset object but preserve some of the parameters
    set limit $params(maxNumRows)
#     set displayLimit $params(maxNumRowsToDisplay)
    if {!$append} {
      # Reset the table when not appending
      set tmpHeader $header
      eval $self reset
      if {!$csvHasHeader || !$importHeader} {
        # If header is not imported, preserve the previous one
        set header $tmpHeader
      }
    }
    set params(maxNumRows) $limit
#     set params(maxNumRowsToDisplay) $displayLimit

    if {[regexp {.gz$} $filename]} {
      # gzip-ed file
      set FH [open "| zcat $filename" {r}]
    } else {
      set FH [open $filename {r}]
    }
    set first 1
    set count 0
    while {![eof $FH]} {
      gets $FH line
      # Skip comments and empty lines
      if {[regexp {^\s*#} $line]} { continue }
      if {[regexp {^\s*$} $line]} { continue }
      if {$first} {
        if {$csvHasHeader} {
          if {$importHeader} {
            # Set the header when -skip_header is not used
            set header [::tclapp::xilinx::designutils::prettyTable::csv2list $line $csvDelimiter]
          }
        } else {
          # The CSV does not have a header
          set row [::tclapp::xilinx::designutils::prettyTable::csv2list $line $csvDelimiter]
          if {($header == {}) && (!$append)} {
            # Generate header as list of indexes only when the header
            # does not exist and -append is not used
            set L [list]
            for {set i 0} {$i < [llength $row]} {incr i} {
              lappend L $i
            }
            set header $L
          }
          $self addrow $row
        }
        set first 0
      } else {
        $self addrow [::tclapp::xilinx::designutils::prettyTable::csv2list $line $csvDelimiter]
        incr count
      }
    }
    close $FH
    if {$verbose} {
      puts " -I- Header: $header"
      puts " -I- Number of imported row(s): $count"
    }
  } elseif {$inlineContent != {}} {
    # Reset object but preserve some of the parameters
    set limit $params(maxNumRows)
#     set displayLimit $params(maxNumRowsToDisplay)
    eval $self reset
    set params(maxNumRows) $limit
#     set params(maxNumRowsToDisplay) $displayLimit

    set first 1
    set count 0
    foreach line [split $inlineContent \n] {
      # Skip comments and empty lines
      if {[regexp {^\s*#} $line]} { continue }
      if {[regexp {^\s*$} $line]} { continue }
      if {$first} {
        set header [::tclapp::xilinx::designutils::prettyTable::csv2list $line $csvDelimiter]
        set first 0
      } else {
        $self addrow [::tclapp::xilinx::designutils::prettyTable::csv2list $line $csvDelimiter]
        incr count
      }
    }
    if {$verbose} {
      puts " -I- Header: $header"
      puts " -I- Number of imported row(s): $count"
    }
  }
  # Update number of rows
  $self numrows
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:export
#------------------------------------------------------------------------
# Usage: <prettyTableObject> export [<options>]
#------------------------------------------------------------------------
# Export the table to various format
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:export {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Export table (table/CSV/JSON/tcl/..) (-help)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::separators separators
  upvar #0 ${self}::params params
  upvar #0 ${self}::numRows numRows

  set error 0
  set help 0
  set longhelp 0
  set verbose 0
  set filename {}
  set append 0
  set startRow 0
  set endRow {end}
  set onlyRows [list]
  set printHeader 1
  set printTitle 1
  set returnVar {}
  set format {table}
  # List of valid format s extracted from the list of procs: ::tclapp::xilinx::designutils::prettyTable::export:*
  set validFormats [concat {table} [lsort [regsub -all {::tclapp::xilinx::designutils::prettyTable::export:} [info procs ::tclapp::xilinx::designutils::prettyTable::export:*] {}]]]
#   set tableFormat {classic}
  set tableFormat $params(tableFormat) ; # table format: classic|lean
  set cellAlignment {left}
  set csvDelimiter {,}
  set columnsToDisplay $params(columnsToDisplay)
  set reorderColumns {}
  # $customArgs is used for custom formats
  set customArgs [list]
  if {[llength $args] == 0} { incr help }
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-format$} -
      {^-fo(r(m(at?)?)?)?$} {
        set format [lshift args]
      }
      {^-delimiter$} -
      {^-d(e(l(i(m(i(t(er?)?)?)?)?)?)?)?$} {
        set csvDelimiter [lshift args]
      }
      {^-file$} -
      {^-fi(le?)?$} {
        set filename [lshift args]
      }
      {^-append$} -
      {^-a(p(p(e(nd?)?)?)?)?$} {
        set append 1
      }
      {^-from_row$} -
      {^-fr(o(m(_(r(ow?)?)?)?)?)?$} {
        set startRow [lshift args]
      }
      {^-to_row$} -
      {^-to(_(r(ow?)?)?)?$} {
        set endRow [lshift args]
      }
      {^-rows$} -
      {^-ro(ws?)?$} {
        set onlyRows [lshift args]
      }
      {^-head$} -
      {^-he(ad?)?$} {
        set n [lshift args]
        set startRow 0
        set endRow [min [expr $n - 1] [expr $numRows - 1] ]
      }
      {^-tail$} -
      {^-ta(il?)?$} {
        set n [lshift args]
        set startRow [max 0 [expr $numRows - $n] ]
        set endRow {end}
      }
      {^-return_var$} -
      {^-re(t(u(r(n(_(v(ar?)?)?)?)?)?)?)?$} {
        set returnVar [lshift args]
      }
      {^-columns$} -
      {^-co(l(u(m(ns?)?)?)?)?$} {
        set columnsToDisplay [lshift args]
      }
      {^-order_columns$} -
      {^-or(d(e(r(_(c(o(l(u(m(ns?)?)?)?)?)?)?)?)?)?)?$} {
        set reorderColumns [lshift args]
      }
      {^-table$} -
      {^-ta(b(le?)?)?$} {
        set tableFormat [lshift args]
      }
      {^-noheader$} -
      {^-noh(e(a(d(er?)?)?)?)?$} {
        set printHeader 0
      }
      {^-notitle$} -
      {^-not(i(t(le?)?)?)?$} {
        set printTitle 0
      }
      {^-left$} -
      {^-le(ft?)?$} -
      {^-align_left$} -
      {^-align_l(e(ft?)?)?$} {
        set cellAlignment {left}
      }
      {^-right$} -
      {^-ri(g(ht?)?)?$} -
      {^-align_right$} -
      {^-align_r(i(g(ht?)?)?)?$} {
        set cellAlignment {right}
      }
      {^-args$} -
      {^-ar(gs?)?$} {
        set customArgs [concat $customArgs [lshift args] ]
      }
      {^-verbose$} -
      {^-v(e(r(b(o(se?)?)?)?)?)?$} {
        set verbose 1
      }
      {^\?$} -
      {^-help$} -
      {^-h(e(lp?)?)?$} {
        set help 1
      }
      {^-longhelp$} -
      {^-lo(n(g(h(e(lp?)?)?)?)?)?$} {
        set help 1
        set longhelp 1
      }
      default {
        if {[string match "--" $name]} {
          # Use "--" to start command line option for the export proc. Same as -args
          set customArgs [concat $customArgs $args]
          # Empty the list of arguments
          set args [list]
        } elseif {[string match "-*" $name]} {
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
  Usage: <prettyTableObject> export
              -format %s
              [-table classic|lean|compact]
              [-delimiter <csv_delimiter>]
              [-file <filename>]
              [-append]
              [-return_var <tcl_var_name>]
              [-columns <list_of_columns_to_display>]
              [-order_columns <ordered_list_of_columns>]
              [-align_left|-left]
              [-align_right|-right]
              [-noheader]
              [-notitle]
              [-from_row <start_row_index>][-to_row <end_row_index>][-rows <row_indexes>][-head <num>][-tail <num>]
              [-args <list_arguments>][-- <list_arguments>]
              [-verbose|-v]
              [-help|-h]
              [-longhelp]

  Description: Export table content. The -columns argument is only available for the
               'list' and 'table' export formats

    -columns: list of columns to display. Order based on table header
    -order_columns: ordered list of columns
    -verbose: applicable with -format csv. Add some configuration information as comment
    -align_left: cell alignment. For table format only
    -align_right: cell alignment. For table format only
    -args: specify additional arguments for custom formats (format: -<key> <value>)
      Equivalent to "--" to separate command line options to the export proc
    -from_row/-to_row/-rows/-head/-tail: control the number of rows that are exported

  Example:
     <prettyTableObject> export -format csv
     <prettyTableObject> export -format <custom> -args <arguments>
     <prettyTableObject> export -format <custom> -- <arguments>
     <prettyTableObject> export -format csv -return_var report
     <prettyTableObject> export -file output.rpt -append -columns {0 2 3 4}
     <prettyTableObject> export -file output.rpt -append -order_columns {0 4 3}
} [join $validFormats |] ]
    # HELP -->

    if {$longhelp} {
      puts [format {
  Example of custom proc:

     proc ::tclapp::xilinx::designutils::prettyTable::export:custom {self args} {
       # Summary :
       # Argument Usage:
       # Return Value:
       # Categories: xilinxtclstore, designutils

       array set defaults [list \
           -return_var {} \
         ]
       array set options [array get defaults]
       array set options $args

       upvar #0 ${self}::header header
       upvar #0 ${self}::table table
       upvar #0 ${self}::params params
       upvar #0 ${self}::separators separators
       upvar #0 ${self}::numRows numRows

       # 'options(-return_var)' holds the variable name from the caller's environment
       # that should receive the content of the report
       if {$options(-return_var) != {}} {
         # The caller's environment is 1 levels up
         upvar 1 $options(-return_var) res
       }
       set res {}

       foreach row $table {
         # Do something
       }

       if {$options(-return_var) != {}} {
         # The report is returned through the upvar
         return {}
       } else {
         return $res
       }
     }

  Example:
     <prettyTableObject> export -format custom -args {-arg1 value1 -arg2 value2}
} ]
    # LONGHELP -->
    }

    return {}
  }

  switch $tableFormat {
    nospacing -
    compact -
    lean -
    classic {
    }
    default {
      puts " -E- invalid table format '$tableFormat'. The valid formats are: classic|lean|compact"
      incr error
    }
  }

  if {($reorderColumns != {}) && ($columnsToDisplay != {})} {
    puts " -E- -columns and -order_columns are exclusive"
    incr error
  }

  if {[llength $onlyRows] && (($startRow != 0) || ($endRow != {end}))} {
    puts " -E- -rows and -from_row/-to_row are exclusive"
    incr error
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  # No header has been defined
  if {[lsearch $validFormats $format] == -1} {
    error " -E- invalid format '$format'. The valid formats are: $validFormats"
  }

  # The -return_var option provides the variable name from the caller's environment
  # that should receive the report
  if {$returnVar != {}} {
    # The caller's environment is 2 levels up
    upvar 2 $returnVar res
  }
  set res {}

  # Work on a clone of the table
  set clone [$self clone]

  set columnsToDelete [list]
  if {$columnsToDisplay != {}} {
    for {set idx 0} {$idx < [llength $header]} {incr idx} {
      if {[lsearch $columnsToDisplay $idx] == -1} {
        lappend columnsToDelete $idx
      }
    }
  }
  if {$columnsToDelete != {}} {
    $clone delcolumns $columnsToDelete
  }
  if {$reorderColumns != {}} {
    # Trim columns that are not specified
    $clone reordercols $reorderColumns -trim 1
  }
  if {($startRow != 0) || ($endRow != {end})} {
    # Only keep the rows between -from_row and -to_row
    $clone settable [lrange [$clone gettable] $startRow $endRow]
    # Need to re-index the separators
    set L [list]
    foreach el [subst $${clone}::separators] {
      lappend L [expr $el - $startRow]
    }
    set ${clone}::separators $L
  }

  if {[llength $onlyRows]} {
    # Only keep the rows specified with -rows
    $clone reorderrows [lsort -integer -unique $onlyRows] -trim 1
  }

  # Common command line arguments to all export procs
  set cmdLine [list -delimiter $csvDelimiter -header $printHeader -title $printTitle -verbose $verbose]

  switch $format {
    table {
      if {$returnVar != {}} {
        $clone print -return_var res -format $tableFormat -align_${cellAlignment} {*}$cmdLine
      } else {
        set res [$clone print -format $tableFormat -align_${cellAlignment} {*}$cmdLine]
      }
    }
    default {
      if {$returnVar != {}} {
        ::tclapp::xilinx::designutils::prettyTable::export:${format} $clone -return_var res {*}$customArgs {*}$cmdLine
      } else {
        set res [::tclapp::xilinx::designutils::prettyTable::export:${format} $clone {*}$customArgs {*}$cmdLine]
      }
    }
  }

  catch {$clone destroy}

  if {$filename != {}} {
    if {$append} {
      set FH [open $filename a]
    } else {
      set FH [open $filename w]
    }
    puts $FH $res
    close $FH
    return
  }
  if {$returnVar != {}} {
    # The report is returned through the upvar
    return {}
  } else {
    return $res
  }
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:search
#------------------------------------------------------------------------
# Usage: <prettyTableObject> search [<options>]
#------------------------------------------------------------------------
# Search inside the table
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:search {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Search inside the table (-help)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::params params
  upvar #0 ${self}::numRows numRows
  set error 0
  set help 0
  set verbose 0
  set quiet 0
  set str {}
  set matchStyle {-glob}
  set caseStyle {}
  set all {}
  set returnformat {rowidx}
  set columns {}
  set rows {}
  set print 0
  if {[llength $args] == 0} { incr help }
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-p(a(t(t(e(rn?)?)?)?)?)?$} {
        set str [lshift args]
      }
      {^-no(c(a(se?)?)?)?$} {
        set caseStyle {-nocase}
      }
      {^-re(g(e(xp?)?)?)?$} {
        set matchStyle {-regexp}
      }
      {^-gl(ob?)?$} {
        set matchStyle {-glob}
      }
      {^-ex(a(ct?)?)?$} {
        set matchStyle {-exact}
      }
      {^-gt$} {
        set matchStyle {greatherThan}
      }
      {^-lt$} {
        set matchStyle {lessThan}
      }
      {^-eq$} {
        set matchStyle {equal}
      }
      {^-bt$} {
        set matchStyle {between}
      }
      {^-all?$} {
        set all {-all}
      }
      {^-pr(i(nt?)?)?$} {
        set print 1
      }
      {^-co(l(u(m(ns?)?)?)?)?$} {
        set columns [lshift args]
      }
      {^-ro(ws?)?$} {
        set rows [lshift args]
      }
      {^-return_row_c(o(l(u(m(n(_(i(n(d(e(x(es?)?)?)?)?)?)?)?)?)?)?)?)?$} {
        set returnformat {rowcolidx}
      }
      {^-return_c(o(l(u(m(n(_(i(n(d(e(x(es?)?)?)?)?)?)?)?)?)?)?)?)?$} {
        set returnformat {colidx}
      }
      {^-return_row_i(n(d(e(x(es?)?)?)?)?)?$} {
        set returnformat {rowidx}
      }
      {^-return_matching_s(t(r(i(n(gs?)?)?)?)?)?$} {
        set returnformat {matchingstring}
      }
      {^-return_matching_r(o(ws?)?)?$} {
        set returnformat {matchingrows}
      }
      {^-return_t(a(b(le?)?)?)?$} {
        set returnformat {table}
      }
      {^-v(e(r(b(o(se?)?)?)?)?)?$} {
        set verbose 1
      }
      {^-q(u(i(et?)?)?)?$} {
        set quiet 1
      }
      {^\?$} -
      {^-h(e(lp?)?)?$} {
        set help 1
      }
      default {
        if {[regexp {^[-+]?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][-+]?[0-9]+)?} $name]} {
          # Floating point numbers
          set str $name
        } elseif {[string match "-*" $name]} {
          puts " -E- option '$name' is not a valid option."
          incr error
        } else {
          set str $name
#           puts " -E- option '$name' is not a valid option."
#           incr error
        }
      }
    }
  }

  if {$help} {
    puts [format {
  Usage: <prettyTableObject> search
              -pattern <string>|<string>
              [-nocase]
              [-glob][-exact][-regexp][-eq][-gt][-lt][-bt]
              [-columns <list_of_columns_to_search>]
              [-rows <list_of_rows_to_search>]
              [-return_row_column_indexes]
              [-return_column_indexes]
              [-return_row_indexes]
              [-return_matching_strings]
              [-return_matching_rows]
              [-return_table]
              [-print]
              [-verbose|-v][-quiet]
              [-help|-h]

  Description: Search for values inside the table

    Returns by default the row index(es) (-return_row_indexes)
    Use -colums to provide a list of columns to search. Column names
      and column indexes can be provided. A column name can match multiple
      column indexes
    Use -rows to provide a list of rows to search
    Use -gt/-lt/-eq/-bt to search for numbers greater or equal, less or equal
    or equal to the expression/pattern, or between the range provided by the
    expression/pattern
    Use -verbose with -print to append '(*)' to matching cells

  Example:
     <prettyTableObject> search -pattern {foo*} -nocase -glob
     <prettyTableObject> search {foo.+} -regexp -return_matching_rows -columns {0 2 3 4}
     <prettyTableObject> search -gt -1.23 -return_matching_rows -columns {0 2 3 4}
     <prettyTableObject> search -gt 150 -columns {maxfo accFO}
     <prettyTableObject> search -bt {-1.23 2.1} -return_matching_rows -columns {0 2 3 4}
     <prettyTableObject> search -rows [<prettyTableObject> search -glob {*CARRY*CARRY*CARRY*CARRY*} -return_row_indexes] -lt -0.2 -col 3
} ]
    # HELP -->
    return {}
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  set res [list]
  set tbl {}
  if {$print || ($returnformat == {table})} {
    set tbl [::tclapp::xilinx::designutils::prettyTable]
    $tbl header [$self header]
  }

  # Build the list of column indexes
  set L [list]
  foreach c $columns {
    if {[regexp {^[0-9]+$} $c]} {
      # Column index
      lappend L $c
    } else {
      # Column specified by name. Need to convert it as an index
      set idx [lsearch -all -exact -nocase $header $c]
      if {$idx == -1} {
        if {!$quiet} {
          puts " -E- column '$c' does not match any table column"
        }
        continue
      }
      if {$verbose && !$quiet} {
        puts " -I- Column '$c' -> $idx"
      }
      set L [concat $L $idx]
    }
  }
  set columns $L

  set res [list]
  set matchrows [list]
  # Search for pattern for each row
#   foreach row $table {}
  for {set rowidx 0} {$rowidx < [llength $table]} {incr rowidx} {
    if {($rows != {}) && ([lsearch $rows $rowidx] == -1)} {
      # If a list of rows has been specified, only process those rows
      continue
    }
    set row [lindex $table $rowidx]
    set match {}
    switch $matchStyle {
      between -
      equal -
      greatherThan -
      lessThan {
        for {set idx 0} {$idx < [llength $row]} {incr idx} {
          set value [lindex $row $idx]
          if {![regexp {^[-+]?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][-+]?[0-9]+)?$} $value]} {
            # Skip non-numeric values
            continue
          }
          switch $matchStyle {
            equal {
              if {$value == $str} {
                lappend match $idx
              }
            }
            greatherThan {
              if {$value >= $str} {
                lappend match $idx
              }
            }
            lessThan {
              if {$value <= $str} {
                lappend match $idx
              }
            }
            between {
              set min [min [lindex $str 0] [lindex $str 1]]
              set max [max [lindex $str 0] [lindex $str 1]]
              if {($value >= $min) && ($value <= $max)} {
                lappend match $idx
              }
            }
          }
        }
      }
      default {
        set match [lsearch {*}$all {*}$caseStyle {*}$matchStyle $row $str]
      }
    }
#     set match [lsearch {*}$all {*}$caseStyle {*}$matchStyle $row $str]
    if {($match != {}) && ($match != {-1})} {
      set addrow 0
      foreach colidx $match {
        if {($columns != {}) && ([lsearch $columns $colidx] != -1)} {
          # The column that has match is in the list of columns specified by -columns
          lappend res [list $rowidx $colidx [lindex $row $colidx]]
          if {$print || ($returnformat == {table})} {
            if {$verbose} {
              # In verbose mode, append the string '(*)' to the matching cells
              set row [lreplace $row $colidx $colidx [format {%s (*)} [lindex $row $colidx] ] ]
            }
          }
          set addrow 1
        } elseif {$columns == {}} {
          lappend res [list $rowidx $colidx [lindex $row $colidx]]
          if {$print || ($returnformat == {table})} {
            if {$verbose} {
              # In verbose mode, append the string '(*)' to the matching cells
              set row [lreplace $row $colidx $colidx [format {%s (*)} [lindex $row $colidx] ] ]
            }
          }
          set addrow 1
        }
      }
      if {$addrow} {
        lappend matchrows $row
        if {$print || ($returnformat == {table})} {
          $tbl addrow $row
        }
      }
    }
  }

  if {$print} {
    puts [$tbl print]
  }

  set L [list]
  switch $returnformat {
    rowcolidx {
      foreach el $res {
        foreach {row col val} $el { break }
        lappend L [list $row $col]
      }
    }
    colidx {
      foreach el $res {
        foreach {row col val} $el { break }
        lappend L $col
      }
      set L [lsort -unique $L]
    }
    rowidx {
      foreach el $res {
        foreach {row col val} $el { break }
        lappend L $row
      }
      set L [lsort -unique $L]
    }
    matchingstring {
      foreach el $res {
        foreach {row col val} $el { break }
        lappend L $val
      }
      set L [lsort -unique $L]
    }
    matchingrows {
      set L $matchrows
    }
    table {
      set L $tbl
      # To prevent the table from being destroyed
      set print 0
    }
  }

  if {$print} {
    catch {$tbl destroy}
  }

  return $L
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:filter
#------------------------------------------------------------------------
# Usage: <prettyTableObject> filter [<options>]
#------------------------------------------------------------------------
# Filter table content
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:filter {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Filter table (-help)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::params params
  upvar #0 ${self}::numRows numRows
  set error 0
  set help 0
  set verbose 0
  set procname {}
  set procargs [list]
  set inlineContent {}
  set print 0
  if {[llength $args] == 0} { incr help }
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-pr(oc?)?$} -
      {^-co(m(m(a(nd?)?)?)?)?$} {
        set procname [lshift args]
      }
      {^-ar(gs?)?$} {
        set procargs [lshift args]
      }
      {^-inline$} -
      {^-i(n(l(i(ne?)?)?)?)?$} {
        set inlineContent [lshift args]
      }
      {^-pr(i(nt?)?)?$} {
        set print 1
      }
      {^-v(e(r(b(o(se?)?)?)?)?)?$} {
        set verbose 1
      }
      {^\?$} -
      {^-h(e(lp?)?)?$} {
        set help 1
      }
      default {
        if {[string match "-*" $name]} {
          puts " -E- option '$name' is not a valid option."
          incr error
        } else {
          set procname $name
#           puts " -E- option '$name' is not a valid option."
#           incr error
        }
      }
    }
  }

  if {$help} {
    puts [format {
  Usage: <prettyTableObject> filter
              [-command <proc>|-proc <proc>|<proc>]
              [-args <list_of_arguments>]
              [-inline <inline_content>]
              [-print]
              [-verbose|-v]
              [-help|-h]

  Description: Filter table content

    The filter proc should be defined as: proc <procname> {row args} { ... ; return $row }
    When TCL_ERROR is returned by the proc, the row is discarded.
    -inline: provide inline content instead of a proc name. Column indexes can be
      refered as c<colIndex>, e.g c0 for column 0
    -print: print the filtered table

  Example:
     <prettyTableObject> filter myprocname
     <prettyTableObject> filter myprocname -args {-arg1 ... -argN}
     <prettyTableObject> filter -inline { set c3 [expr $c1 + $c5] }
     <prettyTableObject> filter -inline { if {$c3 > 0} { error -1 ; # Delete row } }
} ]
    # HELP -->
    return {}
  }

  if {($procname == {}) && ($inlineContent == {})} {
    puts " -E- no proc name or inline content specified (-command/-inline)"
    incr error
  } elseif {($procname != {}) && ($inlineContent != {})} {
    puts " -E- -command and -inline cannot be specified together"
    incr error
  } elseif {$procname != {}} {
    if { [uplevel #0 [list info proc $procname]] == {} } {
      puts " -E- proc '$procname' does not exists<[info proc $procname]>"
      incr error
    }
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  if {$inlineContent != {}} {
    # Create a local proc from the inline content:
    # - For each row, a variable is created for the
    #   equivalent column index: c0, c1, ... cN
    # - The user can modify the variables
    # - The row is recomposed from all the variables
    set procDef [format {
    proc dummyfilter {row args} {
      if {[catch {
        for {set idx 0} {$idx < [llength $row]} {incr idx} {
          set c${idx} [lindex $row $idx]
        }

        # Inline content
        %s

        set newrow [list]
        for {set idx 0} {$idx < [llength $row]} {incr idx} {
          lappend newrow [set c${idx}]
        }
      } errorstring]} {
        if {$errorstring == -1} {
          # If the inline code return TCL_ERROR=-1, then delete the row
          error $errorstring
        } else {
          # Otherwise, print the error message and preserve the row
          puts " -E- $errorstring"
          set newrow $row
        }
      }
      return $newrow
    }
} $inlineContent ]

    # Eval the proc inside the local space
    if {[catch {eval $procDef} errorstring]} {
      puts " -E- $errorstring"
      return -code ok
    }
    # Point to the created proc
    set procname {dummyfilter}
    set inlineContent {}
  }

  set res [list]
  set tbl {}
  if {$print} {
    set tbl [::tclapp::xilinx::designutils::prettyTable]
    $tbl header [$self header]
  }

  set rowidx -1
  set newtable [list]
  # Search for pattern for each row
  foreach row $table {
    incr rowidx
    if {[catch {set res [$procname $row {*}$procargs]} errorstring]} {
      # Tcl Error => the row should not be preserved
    } else {
      lappend newtable $res
      if {$print} {
        $tbl addrow $res
      }
    }
  }

  set table $newtable
  set numRows [llength $table]

  if {$print} {
    puts [$tbl print]
    catch {$tbl destroy}
  }

  return $self
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:reordercols
#------------------------------------------------------------------------
# Usage: <prettyTableObject> reordercols <list_of_column_indexes> [-trim <0|1>]
#------------------------------------------------------------------------
# Reorder a list of column(s). When a column index is specified multiple
# times, the column is duplicated
#------------------------------------------------------------------------

proc ::tclapp::xilinx::designutils::prettyTable::method:reordercols {self columns args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Reorder a list of column(s) (?)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows

  array set defaults [list \
      -trim 0 \
    ]
  array set options [array get defaults]
  array set options $args
  if {[lsearch {-h -help ?} $columns] != -1} {
    puts [format {  Usage: <prettyTableObject> reordercols <list_of_column_indexes> [-trim 0|1]}]
    puts [format {         -trim 1: trim unspecified column(s)}]
    puts [format {         -trim 0 (default): append non-specified column(s)}]
    return -code ok
  }

  if {$columns == {}} {
    return {}
  }

  set L [list]
  foreach column $columns {
  if {[regexp {^end$} $column]} { set column [expr [llength $header] -1] }
  if {[regexp {^end-([0-9]+)$} $column - num]} { set column [expr [llength $header] -1 - $num] }
  if {($column < 0) || ($column > [expr [llength $header] -1])} {
    puts " -W- column '$column' out of bound"
    continue
  }
    lappend L $column
  }
  set columns $L
  # Build the temporary fragment table that will make the
  # first columns of the final table
  set fragHeader [list]
  set fragTable [list]
  for {set idx 0} {$idx < $numRows} {incr idx} {
    lappend fragTable [list]
  }
  foreach col $columns {
    lappend fragHeader [lindex $header $col]
    set L [list]
    foreach row $table fragRow $fragTable {
      # Remove column from row
      lappend fragRow [lindex $row $col]
      lappend L $fragRow
    }
    set fragTable $L
  }
  # Remove columns from current table
  foreach col [lsort -unique -integer -decreasing $columns] {
    if {[catch {
      # Remove column
      $self delcolumns $col
    } errorstring]} {
      puts " -W- $errorstring"
    } else {
    }
  }
  if {$options(-trim)} {
    # Discard columns that have not been specified
    set header $fragHeader
    set table $fragTable
  } else {
    # Merge the fragment table with the original table: fragment table first
    set header [concat $fragHeader $header]
    set L [list]
    foreach row $table fragRow $fragTable {
      lappend L [concat $fragRow $row]
    }
    set table $L
  }
  # Done
  return $self
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:reorderrows
#------------------------------------------------------------------------
# Usage: <prettyTableObject> reorderrows <list_of_row_indexes> [-trim <0|1>]
#------------------------------------------------------------------------
# Reorder a list of row(s). When a row index is specified multiple
# times, the row is duplicated
#------------------------------------------------------------------------

proc ::tclapp::xilinx::designutils::prettyTable::method:reorderrows {self rows args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Reorder a list of row(s) (?)
  upvar #0 ${self}::table table
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows

  array set defaults [list \
      -trim 0 \
    ]
  array set options [array get defaults]
  array set options $args
  if {[lsearch {-h -help ?} $rows] != -1} {
    puts [format {  Usage: <prettyTableObject> reorderrows <list_of_row_indexes> [-trim 0|1]}]
    puts [format {         -trim 1: trim unspecified row(s)}]
    puts [format {         -trim 0 (default): append non-specified row(s)}]
    return -code ok
  }

  if {$rows == {}} {
    return {}
  }

  set L [list]
  foreach row $rows {
  if {[regexp {^end$} $row]} { set row [expr [llength $table] -1] }
  if {[regexp {^end-([0-9]+)$} $row - num]} { set row [expr [llength $table] -1 - $num] }
  if {($row < 0) || ($row > [expr [llength $table] -1])} {
    puts " -W- row '$row' out of bound"
    continue
  }
    lappend L $row
  }
  set rows $L
  # Build the temporary fragment table that will make the
  # first rows of the final table
  set fragTable [list]
  foreach row $rows {
    lappend fragTable [lindex $table $row]
  }
  # Remove rows from current table
  foreach row [lsort -unique -integer -decreasing $rows] {
    if {[catch {
      # Remove row
      $self delrows $row
    } errorstring]} {
      puts " -W- $errorstring"
    } else {
    }
  }
  if {$options(-trim)} {
    # Discard rows that have not been specified
    set table $fragTable
  } else {
    # Merge the fragment table with the original table: fragment table first
    set table [concat $fragTable $table]
  }
  set numRows [llength $table]
  # Done
  return $self
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:version
#------------------------------------------------------------------------
# Usage: <prettyTableObject> version
#------------------------------------------------------------------------
# Return the version number
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:version {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Return the prettyTable version
  return $::tclapp::xilinx::designutils::prettyTable::version
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::expandRange
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Usage: ::tclapp::xilinx::designutils::prettyTable::expandRange <range> [-mode <value|coord|cell>] [-numeric <1|0>]
#------------------------------------------------------------------------
# Return a range of cells. Use '-mode <mode>' to control the returned format.
# The cells range is bounded to the table's dimensions. Multiple ranges Can
# be specified (coma separated).
# Use '-numeric 1' with '-mode value' to only return cell values that are
# numeroc (floating point).
# E.g:
#     +--------+------+-------+
#     | Name   | #    | %     |
#     +--------+------+-------+
#     | LUT    | 9754 | 66.51 |
#     | CARRY  | 2622 | 17.88 |
#     | FD     | 1541 | 10.51 |
#     | RAMB   | 421  | 2.87  |
#     | DSP    | 288  | 1.96  |
#     | URAM   | 36   | 0.25  |
#     | LUTRAM | 3    | 0.02  |
#     +--------+------+-------+
#  c1:2r1:6 (-mode cell) => c1r1 c1r2 c1r3 c1r4 c1r5 c1r6 c2r1 c2r2 c2r3 c2r4 c2r5 c2r6
#  c1:2r1:6 (-mode coord) => {1 1} {1 2} {1 3} {1 4} {1 5} {1 6} {2 1} {2 2} {2 3} {2 4} {2 5} {2 6}
#  c1:2r1:6 (-mode value) => 2622 17.88 1541 10.51 421 2.87 288 1.96 36 0.25 3 0.02
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::expandRange {self ranges args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Get a table cell value
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows

  array set defaults [list \
      -mode {value} \
      -numeric 0 \
    ]
  array set options [array get defaults]
  array set options $args

  set result [list]
  set visited [list]
  foreach range [split $ranges {,}] {
# puts "<range:$range>"
  #   set rmin 0 ; set rmax {end} ; set cmin 0 ; set cmax {end}
    set rmin 0 ; set rmax [expr [llength $table] -1] ; set cmin 0 ; set cmax [expr [llength $header] -1]
    if {[regexp {([cC]([0-9]+)(:([0-9]+))?)([rR]([0-9]+)(:([0-9]+))?)} $range - - cmin - cmax - rmin - rmax]} {
      # c12:3r4:5
      # c12:3
      foreach {cmin cmax} [list [min $cmin $cmax]  [max $cmin $cmax] ] {}
      foreach {rmin rmax} [list [min $rmin $rmax]  [max $rmin $rmax] ] {}

    } elseif {[regexp {[cC]([0-9]+)(:([0-9]+))?} $range - cmin - cmax]} {
      # c4:5
      foreach {cmin cmax} [list [min $cmin $cmax]  [max $cmin $cmax] ] {}
    } elseif {[regexp {[rR]([0-9]+)(:([0-9]+))?} $range - rmin - rmax]} {
      # r4:5
      foreach {rmin rmax} [list [min $rmin $rmax]  [max $rmin $rmax] ] {}
    } else {
      return [list]
    }
# puts "1:<cmin:$cmin><cmax:$cmax><rmin:$rmin><rmax:$rmax>"
    # Bound the values based on the table's dimensions
    foreach {cmin cmax} [list [max $cmin 0]  [min $cmax [expr [llength $header] -1]] ] {}
    foreach {rmin rmax} [list [max $rmin 0]  [min $rmax [expr [llength $table] -1]] ] {}
# puts "2:<cmin:$cmin><cmax:$cmax><rmin:$rmin><rmax:$rmax>"

    switch $options(-mode) {
      values -
      value {
        for {set c $cmin} {$c <= $cmax} {incr c} {
          for {set r $rmin} {$r <= $rmax} {incr r} {
            if {[lsearch $visited "c${c}r${r}"] == -1} {
              # Only add if cell has not been already visited
              set row [lindex $table $r]
              set value [lindex $row $c]
              if {$options(-numeric)} {
                if {[regexp {^[-+]?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][-+]?[0-9]+)?$} $value]} {
                  # Only return floating point numbers (-numeric 1)
                  lappend result $value
                }
              } else {
                lappend result $value
              }
              lappend visited "c${c}r${r}"
            }
          }
        }
      }
      coordonates -
      coordonate -
      coords -
      coord {
        # Return a list of cell coordonates: <column> <row>
        for {set c $cmin} {$c <= $cmax} {incr c} {
          for {set r $rmin} {$r <= $rmax} {incr r} {
            if {[lsearch $visited "c${c}r${r}"] == -1} {
              # Only add if cell has not been already visited
              lappend result [list $c $r]
              lappend visited "c${c}r${r}"
            }
          }
        }
      }
      cells -
      cell {
        # Return a list of cell coordonates: c<column>r<row>
        for {set c $cmin} {$c <= $cmax} {incr c} {
          for {set r $rmin} {$r <= $rmax} {incr r} {
            if {[lsearch $visited "c${c}r${r}"] == -1} {
              # Only add if cell has not been already visited
              lappend result "c${c}r${r}"
              lappend visited "c${c}r${r}"
            }
          }
        }
      }
      default {
        puts " -E- unknown mode '$options(-mode)'"
      }
    }
# puts "<cmin:$cmin><cmax:$cmax><rmin:$rmin><rmax:$rmax>"
  }

  return $result
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::expandExprRange
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Usage: ::tclapp::xilinx::designutils::prettyTable::expandExprRange <range>
#------------------------------------------------------------------------
# Return a range of cells. Only numeric values are returned.
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::expandExprRange {self range args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Return coma separated list (compatibility for 'expr')
  return [join [::tclapp::xilinx::designutils::prettyTable::expandRange $self $range {*}$args -mode value -numeric 1] {,} ]
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::expandNumericRange
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Usage: ::tclapp::xilinx::designutils::prettyTable::expandNumericRange <range>
#------------------------------------------------------------------------
# Return a numeric list based on a range.
# E.g:
#   2:10,3:end-30,end
#   => 2 3 4 5 6 7 8 9 10 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 64
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::expandNumericRange {self ranges args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Get a table cell value
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows

  array set defaults [list \
      -unique 0 \
    ]
  array set options [array get defaults]
  array set options $args

  set result [list]
  foreach range [split $ranges {,}] {
# puts "<range:$range>"
    if {[regexp {^([0-9]+):([0-9]+)$} $range - min max]} {
      foreach {min max} [list [min $min $max]  [max $min $max] ] {}
      for {set i $min} {$i <= $max} {incr i} {
        lappend result $i
      }
    } elseif {[regexp {^[0-9]+$} $range]} {
      lappend result $range
    } elseif {[regexp {^end$} $range]} {
      lappend result [expr [llength $header] -1]
    } elseif {[regexp {^end-([0-9]+)$} $range - num]} {
      lappend result [expr [llength $header] -1 - $num]
    } elseif {[regexp {^([0-9]+):end$} $range - min]} {
      set max [expr [llength $header] -1]
      foreach {min max} [list [min $min $max]  [max $min $max] ] {}
      for {set i $min} {$i <= $max} {incr i} {
        lappend result $i
      }
    } elseif {[regexp {^([0-9]+):end-([0-9]+)$} $range - min num]} {
      set max [expr [llength $header] -1 - $num]
      foreach {min max} [list [min $min $max]  [max $min $max] ] {}
      for {set i $min} {$i <= $max} {incr i} {
        lappend result $i
      }
    } elseif {[regexp {^end-([0-9]+):end$} $range - num]} {
      set min [expr [llength $header] -1 - $num]
      set max [expr [llength $header] -1]
      foreach {min max} [list [min $min $max]  [max $min $max] ] {}
      for {set i $min} {$i <= $max} {incr i} {
        lappend result $i
      }
    } elseif {[regexp {^end-([0-9]+):end-([0-9]+)$} $range - min max]} {
      set min [expr [llength $header] -1 - $min]
      set max [expr [llength $header] -1 - $max]
      foreach {min max} [list [min $min $max]  [max $min $max] ] {}
      for {set i $min} {$i <= $max} {incr i} {
        lappend result $i
      }
    } else {
      puts " -E- unknown range '$range'"
      return [list]
    }
  }

  if {$options(-unique)} {
    set result [lsort -real -unique $result]
  }

  return $result
}

#------------------------------------------------------------------------
# ::tcl::mathfunc::sum
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# New math operators
#------------------------------------------------------------------------
# Sum of all arguments
proc ::tcl::mathfunc::sum {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  ::tcl::mathop::+ {*}$args
}

# Square sum of all arguments
proc ::tcl::mathfunc::sum2 {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  set sum 0
  foreach i $args {set sum [expr {$sum+$i*$i}]}
  set sum
}

# Average of all arguments
proc ::tcl::mathfunc::average {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  expr {[llength $args] ? [::tcl::mathop::+ {*}$args] / double([llength $args]) : "!ERR"}
}

# Number of numeric arguments
proc ::tcl::mathfunc::count {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  expr {[llength $args] ? [llength $args] : "!ERR"}
}

# Median
proc ::tcl::mathfunc::median {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  if {[set len [llength $args]] % 2} then {
    return [lindex [lsort -real $args] [expr {($len - 1) / 2}]]
  } else {
    return [expr {([lindex [set sl [lsort -real $args]] [expr {($len / 2) - 1}]] \
                   + [lindex $sl [expr {$len / 2}]]) / 2.0}]
  }
}

# Arithmetic mean
proc ::tcl::mathfunc::mean {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  expr ([join $args +]+0)/[llength $args].
}

# Geometric mean
proc ::tcl::mathfunc::gmean {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  expr pow([join $args *],1./[llength $args])
}

# Quadratic mean
proc ::tcl::mathfunc::qmean {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  expr sqrt((pow([join $args ,2)+pow(],2))/[llength $args])
}

# Harmonic mean
proc ::tcl::mathfunc::hmean {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  expr [llength $args]/(1./[join $args +1./])
}

# Square mean
proc ::tcl::mathfunc::mean2 {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  set sum 0
  foreach i $args {set sum [expr {$sum+$i*$i}]}
  expr {double($sum)/[llength $args]}
}

# Standard deviation
proc ::tcl::mathfunc::stddev {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  set m [mean {*}$args]
  expr {sqrt([mean2 {*}$args]-$m*$m)}
}

# Variance
proc ::tcl::mathfunc::variance {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  set m [mean {*}$args]
  expr {[mean2 {*}$args]-$m*$m}
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:eval
#------------------------------------------------------------------------
# Usage: <prettyTableObject> eval [<options>]
#------------------------------------------------------------------------
# Evaluate an expression
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:eval {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Evaluate an expression (-help)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::params params
  upvar #0 ${self}::numRows numRows
  set expressions {}
  set evaluate 1
  set error 0
  set help 0
  set verbose 0
  set quiet 0
  if {[llength $args] == 0} { incr help }
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-expression$} -
      {^-e(x(p(r(e(s(s(i(on?)?)?)?)?)?)?)?)?$} {
        lappend expressions [lshift args]
      }
      {^-no_eval$} -
      {^-no(_(e(v(al?)?)?)?)?$} {
        set evaluate 0
      }
      {^-v(e(r(b(o(se?)?)?)?)?)?$} {
        set verbose 1
      }
      {^-q(u(i(et?)?)?)?$} {
        set quiet 1
      }
      {^\?$} -
      {^-h(e(lp?)?)?$} {
        set help 1
      }
      default {
        if {[string match "-*" $name]} {
          puts " -E- option '$name' is not a valid option."
          incr error
        } else {
          set expressions $name
#           puts " -E- option '$name' is not a valid option."
#           incr error
        }
      }
    }
  }

  if {$help} {
    puts [format {
  Usage: <prettyTableObject> eval
              -expression <expr>|<expr>
              [-no_eval]
              [-verbose|-v]
              [-help|-h]

  Description: Evaluate math expression on the table content

    Multiple expressions can be specified through multiple -expression

    -no_eval: return the expression without evaluation

  Example of operators:
          min            gmean (geometic mean)
          max            qmean (quadratic mean)
          sum            hmean (harmonic mean)
          average        mean2 (square mean)
          median         stddev (standard deviation)
          mean           variance
          count

  Example:
     <prettyTableObject> eval {sum(c2)}
     <prettyTableObject> eval {sum(c1r0:6,c2:3r7:8)}
     <prettyTableObject> eval -e sum(c1) -e min(c1) -e max(c1)
} ]
    # HELP -->
    return {}
  }

  if {$expressions == {}} {
    puts " -E- no expression specified (-expression)"
    incr error
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  set result {}
  foreach expression $expressions {
    # Ranges with cC&rR
    set res [regsub -all {(([cC][0-9]+(:[0-9]+)?)([rR][0-9]+(:[0-9]+)?))} $expression [format {[expandExprRange %s \1]} $self] ]
    set res [subst $res]
    # Ranges with cC only
    set res [regsub -all {([cC][0-9]+(:[0-9]+)?)} $res [format {[expandExprRange %s \1]} $self] ]
    set res [subst $res]
    # Ranges with rR only
    set res [regsub -all {([rR][0-9]+(:[0-9]+)?)} $res [format {[expandExprRange %s \1]} $self] ]
    set res [subst $res]

    if {$evaluate} {
      if {[catch {set _result [expr [subst $res]]} errorstring]} {
        if {!$quiet} {
          puts " -E- failed during evaluation: $errorstring"
          puts "     expression: $res"
        }
        lappend result {}
      } else {
        lappend result $_result
      }
    } else {
      lappend result $res
    }
  }

  return $result
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::applyMathOperator
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Apply a math operator to a list. Used to generate the pivot table
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::applyMathOperator {op L {quiet 0} {precision 3}} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  set res {#ERR}
  # Only keep numeric values
  set values [getNumericValues $L]
  if {$precision == -1} {
    # No limit
    set precision {%s}
  } else {
    # Number of digits after dot
    set precision "%.${precision}f"
  }
  if {[catch {set res [format $precision [$op {*}$values]] } errorcode]} {
    if {!$quiet} {
      puts " -E- '$op': $errorcode"
    }
  }
  return $res
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::truncateList
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Truncate list
#    -0.135 -0.136 -0.137 -0.138 -0.139 ... -0.391 -0.392 -0.393 -0.394 -0.395
#    -0.135 -0.136 -0.137 -0.138 -0.139 -0.140 -0.141 -0.142 -0.143 -0.144 ...
#    ... -0.135 -0.136 -0.137 -0.138 -0.139 -0.140 -0.141 -0.142 -0.143 -0.144
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::truncateList {L {max end} {type center}} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  if {$max == {end}} { return $L }
  if {[llength $L] > $max} {
    switch $type {
      end {
        # Insert '...' at the end of the list:
        #    -0.135 -0.136 -0.137 -0.138 -0.139 -0.140 -0.141 -0.142 -0.143 -0.144 ...
        set L [lrange $L 0 [expr $max -1]]
        lappend L {...}
      }
      start {
        # Insert '...' at the start of the list:
        #    ... -0.135 -0.136 -0.137 -0.138 -0.139 -0.140 -0.141 -0.142 -0.143 -0.144
        set L [concat {...} [lrange $L end-[expr $max -1] {end}] ]
      }
      center -
      default {
        # Insert '...' in the middle of the list:
        #     -0.135 -0.136 -0.137 -0.138 -0.139 ... -0.391 -0.392 -0.393 -0.394 -0.395
        set first [expr int($max / 2) -1]
        set last [expr $max - $first -2]
        set L [concat [lrange $L 0 $first] {...} [lrange $L end-$last end] ]
      }
    }
  }
  return $L
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::getNumericValues
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Exclude elements from the list that do not match a float
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::getNumericValues {L} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  set values [list]
  foreach el $L {
    if {[regexp {^[-+]?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][-+]?[0-9]+)?$} $el]} {
      # Only keep floating point numbers
      lappend values $el
    }
  }
  return $values
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::getHistogramDistribution
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Return histogram distribution
# E.g:
#   % ::tclapp::xilinx::designutils::prettyTable::getHistogramDistribution {0 1 2 3 4 5 6 7 8 9 10 11 16 21 26 31} <list_of_values>
#   => 0 2 0 0 0 0 47 25 83 75 42 16 287 93 0 0 0
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::getHistogramDistribution {limits values} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  if { [llength $limits] < 1 } {
    return -code error -errorcode ARG -errorinfo {No limits given} {No limits given}
  }

  set limits [lsort -real -decreasing $limits]

  for { set index 0 } { $index <= [llength $limits] } { incr index } {
    set buckets($index) 0
  }

  foreach value $values {
    if { $value == {} } {
      continue
    }

    set index [llength $limits]
    set found 0
    foreach limit $limits {
      if { $value >= $limit } {
        set found 1
        incr buckets($index)
        break
      }
      incr index -1
    }

    if { $found == 0 } {
      # Values that are smaller than the smallest limit
      incr buckets(0)
    }
  }

  set result {}
  for { set index 0 } { $index <= [llength $limits] } { incr index } {
    lappend result $buckets($index)
  }

  # Do not return the first bucket that is filled by values that are smaller
  # than the smallest limit
  return [lrange $result 1 end]
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::generatePivotTable
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Generate a pivot table from a source table, a list of rows and list
# of columns. Rows and columns can be specified by row/column index or
# names.
# With each row, a display type can be provided:
#    <column>[:<type>]
# <type>:
#    min
#    max
#    sum
#    average
#    median
#    mean
#    gmean (geometic mean)
#    qmean (quadratic mean)
#    hmean (harmonic mean)
#    mean2 (square mean)
#    stddev (standard deviation)
#    freq (frequency distribution)
#    count
#    default
#------------------------------------------------------------------------
# Example of pivot table with single column
#   % set pivot [$tbl createpivot -rows {sptype eptype} -columns {lvls} -max -1 -print -prec 2]
#   +------------+--------------+-------+----------+--------------------------------------------+
#   | spType     | epType       | count | count(%) | lvls                                       |
#   +------------+--------------+-------+----------+--------------------------------------------+
#   | FDRE       | FDRE         | 670   | 67.00    | 1 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 |
#   | RAMB18E2   | RAMB18E2     | 189   | 18.90    | 9 10 11 12                                 |
#   | FDRE       | RAMB18E2     | 60    | 6.00     | 9 10 11                                    |
#   | FDRE       | RAMB36E2     | 39    | 3.90     | 6 7 9                                      |
#   | FDSE       | FDRE         | 12    | 1.20     | 12 13                                      |
#   | DSP_M_DATA | FDRE         | 11    | 1.10     | 12                                         |
#   | FDRE       | RAMD32       | 9     | 0.90     | 8 9                                        |
#   | RAMB36E2   | FDRE         | 6     | 0.60     | 11 12                                      |
#   | FDRE       | URAM288      | 2     | 0.20     | 4                                          |
#   | RAMB18E2   | DSP_A_B_DATA | 1     | 0.10     | 6                                          |
#   | URAM288    | FDRE         | 1     | 0.10     | 6                                          |
#   +------------+--------------+-------+----------+--------------------------------------------+
#
# Example of pivot table with distribution table
#   % set pivot [$tbl createpivot -rows {sptype eptype} -columns {lvls} -max -1 -print -prec 2 -bins {0 1 2 3 4 5 6 7 8 9 10 11 16 21 26 31} -names {0 1 2 3 4 5 6 7 8 9 10 11-15 16-20 21-25 26-30 31+}]
#   +------------+--------------+-------+----------+---+---+---+---+---+---+----+----+----+----+----+-------+-------+-------+-------+-----+
#   | spType     | epType       | count | count(%) | 0 | 1 | 2 | 3 | 4 | 5 | 6  | 7  | 8  | 9  | 10 | 11-15 | 16-20 | 21-25 | 26-30 | 31+ |
#   +------------+--------------+-------+----------+---+---+---+---+---+---+----+----+----+----+----+-------+-------+-------+-------+-----+
#   | FDRE       | FDRE         | 670   | 67.00    | 0 | 2 | 0 | 0 | 0 | 0 | 47 | 25 | 83 | 75 | 42 | 16    | 287   | 93    | 0     | 0   |
#   | RAMB18E2   | RAMB18E2     | 189   | 18.90    | 0 | 0 | 0 | 0 | 0 | 0 | 0  | 0  | 0  | 2  | 93 | 23    | 71    | 0     | 0     | 0   |
#   | FDRE       | RAMB18E2     | 60    | 6.00     | 0 | 0 | 0 | 0 | 0 | 0 | 0  | 0  | 0  | 23 | 30 | 7     | 0     | 0     | 0     | 0   |
#   | FDRE       | RAMB36E2     | 39    | 3.90     | 0 | 0 | 0 | 0 | 0 | 0 | 5  | 30 | 0  | 4  | 0  | 0     | 0     | 0     | 0     | 0   |
#   | FDSE       | FDRE         | 12    | 1.20     | 0 | 0 | 0 | 0 | 0 | 0 | 0  | 0  | 0  | 0  | 0  | 0     | 12    | 0     | 0     | 0   |
#   | DSP_M_DATA | FDRE         | 11    | 1.10     | 0 | 0 | 0 | 0 | 0 | 0 | 0  | 0  | 0  | 0  | 0  | 0     | 11    | 0     | 0     | 0   |
#   | FDRE       | RAMD32       | 9     | 0.90     | 0 | 0 | 0 | 0 | 0 | 0 | 0  | 0  | 1  | 8  | 0  | 0     | 0     | 0     | 0     | 0   |
#   | RAMB36E2   | FDRE         | 6     | 0.60     | 0 | 0 | 0 | 0 | 0 | 0 | 0  | 0  | 0  | 0  | 0  | 1     | 5     | 0     | 0     | 0   |
#   | FDRE       | URAM288      | 2     | 0.20     | 0 | 0 | 0 | 0 | 2 | 0 | 0  | 0  | 0  | 0  | 0  | 0     | 0     | 0     | 0     | 0   |
#   | RAMB18E2   | DSP_A_B_DATA | 1     | 0.10     | 0 | 0 | 0 | 0 | 0 | 0 | 1  | 0  | 0  | 0  | 0  | 0     | 0     | 0     | 0     | 0   |
#   | URAM288    | FDRE         | 1     | 0.10     | 0 | 0 | 0 | 0 | 0 | 0 | 1  | 0  | 0  | 0  | 0  | 0     | 0     | 0     | 0     | 0   |
#   +------------+--------------+-------+----------+---+---+---+---+---+---+----+----+----+----+----+-------+-------+-------+-------+-----+
#
# Example of pivot table with distribution table
#   % set pivot [$tbl createpivot -rows {sptype eptype} -columns {skew} -max -1 -print -prec 2 -bins {-1.0 -0.55 -0.5 -0.4 -0.3 -0.2 -0.1 0 0.1 0.2 0.3}]
#   +------------+--------------+-------+----------+------+-------+------+------+------+------+------+----+-----+-----+-----+
#   | spType     | epType       | count | count(%) | -1.0 | -0.55 | -0.5 | -0.4 | -0.3 | -0.2 | -0.1 | 0  | 0.1 | 0.2 | 0.3 |
#   +------------+--------------+-------+----------+------+-------+------+------+------+------+------+----+-----+-----+-----+
#   | FDRE       | FDRE         | 670   | 67.00    | 35   | 145   | 14   | 14   | 40   | 149  | 191  | 75 | 6   | 1   | 0   |
#   | RAMB18E2   | RAMB18E2     | 189   | 18.90    | 0    | 3     | 36   | 56   | 45   | 20   | 28   | 0  | 1   | 0   | 0   |
#   | FDRE       | RAMB18E2     | 60    | 6.00     | 0    | 0     | 0    | 26   | 22   | 10   | 0    | 2  | 0   | 0   | 0   |
#   | FDRE       | RAMB36E2     | 39    | 3.90     | 2    | 0     | 8    | 6    | 0    | 0    | 0    | 23 | 0   | 0   | 0   |
#   | FDSE       | FDRE         | 12    | 1.20     | 0    | 0     | 0    | 0    | 2    | 2    | 3    | 5  | 0   | 0   | 0   |
#   | DSP_M_DATA | FDRE         | 11    | 1.10     | 0    | 0     | 0    | 0    | 0    | 3    | 8    | 0  | 0   | 0   | 0   |
#   | FDRE       | RAMD32       | 9     | 0.90     | 0    | 0     | 4    | 5    | 0    | 0    | 0    | 0  | 0   | 0   | 0   |
#   | RAMB36E2   | FDRE         | 6     | 0.60     | 0    | 0     | 0    | 0    | 6    | 0    | 0    | 0  | 0   | 0   | 0   |
#   | FDRE       | URAM288      | 2     | 0.20     | 0    | 0     | 0    | 0    | 2    | 0    | 0    | 0  | 0   | 0   | 0   |
#   | RAMB18E2   | DSP_A_B_DATA | 1     | 0.10     | 0    | 0     | 0    | 1    | 0    | 0    | 0    | 0  | 0   | 0   | 0   |
#   | URAM288    | FDRE         | 1     | 0.10     | 0    | 0     | 0    | 0    | 1    | 0    | 0    | 0  | 0   | 0   | 0   |
#   +------------+--------------+-------+----------+------+-------+------+------+------+------+------+----+-----+-----+-----+
proc ::tclapp::xilinx::designutils::prettyTable::generatePivotTable {srcTbl pivotTbl selRows selCols args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

#   upvar #0 ${srcTbl}::header srcHeader
#   upvar #0 ${srcTbl}::table srcTable
  upvar #0 ${pivotTbl}::header pvtHeader
  upvar #0 ${pivotTbl}::table pvtTable

  # Default options
  array set defaults [list \
      -quiet 0 \
      -max_list_size {end} \
      -precision 3 \
      -bins {} \
      -names {} \
      -hide_zeros 0 \
      -filter {} \
      -verbose 0 \
    ]
  array set options [array get defaults]
  array set options $args
  set verbose $options(-verbose)
  set quiet $options(-quiet)
  set maxListSize $options(-max_list_size)
  set precision $options(-precision)
  set filter $options(-filter)
  set distributionTableBins $options(-bins)
  set distributionTableCols $options(-names)
  set distributionHideZeroBins $options(-hide_zeros)
  if {($distributionTableBins != {}) && ([llength $selCols] != 1)} {
    # Distribution table is only valid when a single column has been specified
    set distributionTableBins {}
  }

  # The source for the pivot table should always refer to the original table
  # even when filtering has been defined
  set originalSrcTbl $srcTbl

  if {$filter != {}} {
    # If filtering has been specified, create new table
    if {[catch {set srcTbl [$srcTbl search {*}$filter -return_table]} errorstring]} {
      puts "$errorstring"
      puts " -W- filtering not applied"
      upvar #0 ${srcTbl}::header srcHeader
      upvar #0 ${srcTbl}::table srcTable
    } else {
      # Set variables based on filtered table
      set srcHeader [$srcTbl header]
      set srcTable [$srcTbl gettable]
    }
  } else {
    # Set variables based on source table
    upvar #0 ${srcTbl}::header srcHeader
    upvar #0 ${srcTbl}::table srcTable
  }

  # Build the list of column indexes that are used in the pivot table rows
  set pivotRows [list]
  foreach row $selRows {
    if {[regexp {^[0-9]+$} $row]} {
      # Row index
      lappend pivotRows $row
    } else {
      # Row specified by name. Need to convert it as an index
      set idx [lsearch -exact -nocase $srcHeader $row]
      if {$idx == -1} {
        if {!$quiet} {
          puts " -E- column '$row' does not match any table column"
        }
        continue
      }
      if {$verbose && !$quiet} {
        puts " -I- Row '$row' -> $idx"
      }
      lappend pivotRows $idx
    }
  }

  set pivotColumns [list]
  set pivotColumnXform [list]
  set pivotColumnHeader [list]
  # Build the list of column indexes that are used in the pivot table columns
  foreach column $selCols {
    # The column can be specified with a transformation type:
    #     <columnName>[:<type>]
    # E.g: -columns {slack:average}
    set columnName {}
    # Extract the column type. If none is specified, then assign 'default'
    if {[regexp {^(.+)(:(.+))$} $column - name - type]} {
      set column $name
    } else {
      set type {default}
    }
    if {[regexp {^[0-9]+$} $column]} {
      # Column index
      set columnName [lindex $srcHeader $column]
      lappend pivotColumns $column
    } else {
      # Column specified by name. Need to convert it as an index
      set idx [lsearch -exact -nocase $srcHeader $column]
      if {$idx == -1} {
        if {!$quiet} {
          puts " -E- column '$column' does not match any table column"
        }
        continue
      }
      if {$verbose && !$quiet} {
        puts " -I- Column '$column' -> $idx"
      }
      set columnName [lindex $srcHeader $idx]
      lappend pivotColumns $idx
    }
    if {$distributionTableBins != {}} {
      # For distribution table, force the type to 'dist'
      set type {dist}
    }
    # Save the transformation for the column
    lappend pivotColumnXform [string tolower $type]
    # Build the column header name based on the transformation type
    if {$type == {default}} {
      lappend pivotColumnHeader [format {%s} $columnName]
    } else {
      lappend pivotColumnHeader [format {%s(%s)} [string tolower $type] $columnName]
    }
  }

  if {![llength $pivotRows]} {
    if {!$quiet} {
      puts " -E- no valid row specified"
    }
    return -code ok
  }

  if {($distributionTableBins != {}) && ([llength $selCols] == 1)} {
    # Distribution table is only valid when a single column has been specified
    if {[regexp -nocase {^auto(:([0-9]+))?$} $distributionTableBins - - numBins]} {
      # Generate the number of sizes of bins automatically
      if {$numBins == {}} {
        # Default number of bins
        set numBins 10
      }
      # Get all the numeric values from the column
      set values [getNumericValues [$srcTbl getcolumns $pivotColumns]]
      set min [lindex [lsort -real -increasing $values] 0]
      set max [lindex [lsort -real -increasing $values] end]
      set distributionTableBins [list]
      for {set idx 0} {$idx < $numBins} {incr idx} {
        # Are all the values integers?
        if {[regexp {\.} $values]} {
          # No, some value(s) are float
          lappend distributionTableBins [format {%.3f} [expr $min + $idx * ($max - $min) / [expr $numBins + 1.0] ] ]
        } else {
          # Yes, all values are integer => keep all the bin values as integer
          lappend distributionTableBins [format {%s} [expr int($min + $idx * ($max - $min) / [expr $numBins + 1.0]) ] ]
        }
      }
    }

    # Adjust the columns names of the distribution table
    if {$distributionTableCols == {}} {
      # If the column names for the distribution buckets have not been specified,
      # use the values specified for the buckets
      set distributionTableCols $distributionTableBins
    } elseif {[llength $distributionTableCols] < [llength $distributionTableBins]} {
      set distributionTableCols [concat $distributionTableCols \
                                        [lrange $distributionTableBins [llength $distributionTableCols] end] \
                                ]
    } elseif {[llength $distributionTableCols] > [llength $distributionTableBins]} {
      set distributionTableCols [lrange $distributionTableCols 0 [expr [llength $distributionTableBins] -1] ]
    }

  }

  $pivotTbl reset
  # Copy the source table inside the pivot table
  set pvtHeader $srcHeader
  set pvtTable $srcTable
#   $pivotTbl header [$srcTbl header]
#   $pivotTbl settable [$srcTbl gettable]
  # Remove all the columns that have not be specified in the list of rows
  $pivotTbl reordercols $pivotRows -trim 1
  # Generate the frequency distribution
  set rows [$pivotTbl gettable]
  set distribution [getFrequencyDistribution $rows]
  # Adding the columns 'count' and 'count(%)'
  set pivotTblHeader [concat $pvtHeader {count} {count(%)} $pivotColumnHeader]

  if {$distributionTableBins != {}} {
    # For distribution table: the header should include all the column names of the buckets
    set pivotTblHeader [concat $pvtHeader {count} {count(%)} $pivotColumnHeader $distributionTableCols]
  }

  # Reset the pivot table and build the final pivot table
  $pivotTbl reset
  $pivotTbl header $pivotTblHeader
  $pivotTbl set_param {template} {pivottable}
  $pivotTbl set_param {methods} {method pivottable}
  $pivotTbl set_param {pivotSource} $originalSrcTbl
  $pivotTbl set_param {pivotMaxListSize} $maxListSize
  $pivotTbl set_param {pivotPrecision} $precision
  $pivotTbl set_param {pivotFilter} $filter
  $pivotTbl set_param {pivotRows} $selRows
  $pivotTbl set_param {pivotColumns} $selCols
  $pivotTbl set_param {pivotDistributionBins} $distributionTableBins
  $pivotTbl set_param {pivotDistributionNames} $distributionTableCols
  $pivotTbl set_param {pivotDistributionNoEmptyBins} $distributionHideZeroBins
  if {$filter != {}} {
    # For information
#     $pivotTbl title [format {filter: %s} $filter]
  }

  # Build data structure:
  # Key for associative array: table values for each column selected as the 'pivot table rows'
  #  + column index selected as the 'pivot table columns'
  catch { unset data }
  foreach row $srcTable {
    set L [list]
    foreach idx $pivotRows {
      lappend L [lindex $row $idx]
    }
    set key [join $L \0]
    # Build the data only once for each unique column
    foreach column [lsort -unique $pivotColumns] {
      lappend data(${key}\1${column}) [lindex $row $column]
    }
  }

  # Populate pivot table
  foreach el $distribution {
    set row [list]
    foreach col [concat [lindex $el 0] [lindex $el 1]] {
      # The first columns of the pivot table are the columns specified as
      # the 'pivot table rows' + the 'count' column
      lappend row $col
    }
    # The last value for $col represent the 'count' column. The value for 'count(%)' is
    # calculated as a percent based on the number of samples
    if {[llength $srcTable]} {
      lappend row [format {%.2f} [expr 100.0 * $col / [llength $srcTable]]]
    } else {
      lappend row {-}
    }
    set key [join [lindex $el 0] \0]
    # Add columns specified as the 'pivot table columns'
    foreach column $pivotColumns xform $pivotColumnXform {
      if {[info exists data(${key}\1${column})]} {
        set values $data(${key}\1${column})
        if {[catch {
          switch $xform {
            max {
              lappend row [lindex [lsort -real [getNumericValues $values]] end]
            }
            min {
              lappend row [lindex [lsort -real [getNumericValues $values]] 0]
            }
            sum {
              lappend row [applyMathOperator ::tcl::mathfunc::sum [getNumericValues $values] $quiet $precision]
            }
            sum2 {
              lappend row [applyMathOperator ::tcl::mathfunc::sum2 [getNumericValues $values] $quiet $precision]
            }
            average {
              lappend row [applyMathOperator ::tcl::mathfunc::average [getNumericValues $values] $quiet $precision]
            }
            median {
              lappend row [applyMathOperator ::tcl::mathfunc::median [getNumericValues $values] $quiet $precision]
            }
            mean {
              lappend row [applyMathOperator ::tcl::mathfunc::mean [getNumericValues $values] $quiet $precision]
            }
            gmean {
              lappend row [applyMathOperator ::tcl::mathfunc::gmean [getNumericValues $values] $quiet $precision]
            }
            qmean {
              lappend row [applyMathOperator ::tcl::mathfunc::qmean [getNumericValues $values] $quiet $precision]
            }
            hmean {
              lappend row [applyMathOperator ::tcl::mathfunc::hmean [getNumericValues $values] $quiet $precision]
            }
            mean2 {
              lappend row [applyMathOperator ::tcl::mathfunc::mean2 [getNumericValues $values] $quiet $precision]
            }
            stddev {
              lappend row [applyMathOperator ::tcl::mathfunc::stddev [getNumericValues $values] $quiet $precision]
            }
            var -
            variance {
              lappend row [applyMathOperator ::tcl::mathfunc::variance [getNumericValues $values] $quiet $precision]
            }
            freq {
              lappend row [truncateList [getFrequencyDistribution $values] $maxListSize]
            }
            count {
              lappend row [llength $values]
            }
            dist {
              # For distribution table only
              #                                                   |-> distribution table ->
              #    +------------+--------------+-------+----------+---+---+---+---+---+---+----+----+----+----+----+-------+-------+-------+-------+-----+
              #    | spType     | epType       | count | count(%) | 0 | 1 | 2 | 3 | 4 | 5 | 6  | 7  | 8  | 9  | 10 | 11-15 | 16-20 | 21-25 | 26-30 | 31+ |
              #    +------------+--------------+-------+----------+---+---+---+---+---+---+----+----+----+----+----+-------+-------+-------+-------+-----+
              #    | FDRE       | FDRE         | 670   | 67.00    | 0 | 2 | 0 | 0 | 0 | 0 | 47 | 25 | 83 | 75 | 42 | 16    | 287   | 93    | 0     | 0   |
              #    | RAMB18E2   | RAMB18E2     | 189   | 18.90    | 0 | 0 | 0 | 0 | 0 | 0 | 0  | 0  | 0  | 2  | 93 | 23    | 71    | 0     | 0     | 0   |
              #    | FDRE       | RAMB18E2     | 60    | 6.00     | 0 | 0 | 0 | 0 | 0 | 0 | 0  | 0  | 0  | 23 | 30 | 7     | 0     | 0     | 0     | 0   |
              #    ...
              #    +------------+--------------+-------+----------+---+---+---+---+---+---+----+----+----+----+----+-------+-------+-------+-------+-----+
              lappend row [lsort -dictionary $values]
              # Add each column of the distribution table
              foreach el [::tclapp::xilinx::designutils::prettyTable::getHistogramDistribution $distributionTableBins $values] {
                if {$distributionHideZeroBins && ($el == 0)} {
                  # Hide the value when it's '0'
                  lappend row {}
                } else {
                  lappend row $el
                }
              }
            }
            "default" {
              lappend row [truncateList [lsort -dictionary -unique $values] $maxListSize]
            }
            default {
              puts " -W- unknown column transform type '$xform'"
              lappend row [truncateList [lsort -dictionary -unique $values] $maxListSize]
            }
          }
        } errorstring]} {
          if {!$quiet} {
            puts " -E- $errorstring"
          }
          lappend row [truncateList [lsort -dictionary -unique $values] $maxListSize]
        }
      } else {
        puts " -E- cannot find '[lindex $el 0]' for column $column"
      }
    }
    $pivotTbl addrow $row
  }

  if {$distributionTableBins != {}} {
    # For distribution table. Remove column index that is the column used to
    # build the distribution table: 2 + number of columns for the table rows
    $pivotTbl delcolumns [expr [llength $selRows] +2]
  }

  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:createpivot
#------------------------------------------------------------------------
# Usage: <prettyTableObject> createpivot [<options>]
#------------------------------------------------------------------------
# Create a pivot table from the table object. The original object is not
# modified. The new pivot table is returned
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:createpivot {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Create a pivot table (-help)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows
  set rows [list]
  set columns [list]
  set maxListSize {end}
  set precision 3
  set distributionTableBins [list]
  set distributionHideZeroBins 0
  set histogramNames [list]
  set filter {}
  set print 0
  set error 0
  set help 0
  set verbose 0
  set quiet 0
  if {[llength $args] == 0} { incr help }
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-r(o(ws?)?)?$} {
        set rows [lshift args]
      }
      {^-c(o(l(u(m(ns?)?)?)?)?)?$} {
        set columns [lshift args]
      }
      {^-m(ax?)?$} {
        set maxListSize [lshift args]
      }
      {^-pre(c(i(s(i(on?)?)?)?)?)?$} {
        set precision [lshift args]
      }
      {^-bins$} -
      {^-bi(ns?)?$} {
        set distributionTableBins [lshift args]
      }
      {^-names$} -
      {^-na(m(es?)?)?$} {
        set histogramNames [lshift args]
      }
      {^-filter$} -
      {^-f(i(l(t(er?)?)?)?)?$} {
        set filter [lshift args]
      }
      {^-hide_zeros$} -
      {^-hi(d(e(_(z(e(r(os?)?)?)?)?)?)?)?$} {
        set distributionHideZeroBins 1
      }
      {^-pri(nt?)?$} {
        set print 1
      }
      {^-q(u(i(et?)?)?)?$} {
        set quiet 1
      }
      {^-v(e(r(b(o(se?)?)?)?)?)?$} {
        set verbose 1
      }
      {^\?$} -
      {^-h(e(lp?)?)?$} {
        set help 1
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
  Usage: <prettyTableObject> createpivot
              -rows <row(s)>
              [-columns <column(s)>]
              [-max <max_list_size>]
              [-precision <number>]
              [-filter <options>]
              [-bins <list_histogram_bins>|-bins auto[:<number_of_bins]]
              [-names <list_histogram_column_names>]
              [-hide_zeros]
              [-print]
              [-quiet]
              [-verbose|-v]
              [-help|-h]

  Description: Create a pivot table

    -rows: tables columns to be used for the pivot table rows. Columns names or
      columns indexes can be specified
    -columns: tables columns to be used for the pivot table columns. Columns
      names or columns indexes can be specified
        Format: <column>[:<type>]
          <type>: min           gmean (geometic mean)
                  max           qmean (quadratic mean)
                  sum           hmean (harmonic mean)
                  average       mean2 (square mean)
                  median        stddev (standard deviation)
                  mean          variance
                  count         freq (frequency distribution)
                  default (uniquify values)
    -max: maximum length for lists (-1: no limit)
    -precision: numeric precision. Default 3 digits (-1 to remove limit)
    -filter: filtering applied to the source data prior creating the pivot table
      Same options that can be specified for method 'search'
    -bins: list of bins for the distribution table. A single column (-columns) must be specified
      The specified values represent the minimal values for each bin.
    -names: header names for the distribution table. A single column (-columns) must be specified
    -hide_zeros: hide distribution table bins with 0

  Example:
     <prettyTableObject> createpivot -rows {sptype eptype}
     <prettyTableObject> createpivot -rows {sptype eptype} -filter {-columns 3 -gt 2.0}
     <prettyTableObject> createpivot -rows {sptype eptype} -columns {maxfo slack:min slack:max}
     <prettyTableObject> createpivot -rows {1 2} -columns {4 5:min 5:max slack:average} -precision -1
     <prettyTableObject> createpivot -rows {sptype eptype} -columns {lvls} -bins {0 1 2 3 4 5 6 7 8 9 10 11 16 21 26 31}
     <prettyTableObject> createpivot -rows {sptype eptype} -columns {lvls} -bins {0 1 2 3 4 5 6 7 8 9 10 11 16 21 26 31} -names {0 1 2 3 4 5 6 7 8 9 10 11-15 16-10 21-25 26-30 31+}
     <prettyTableObject> createpivot -rows {sptype eptype} -columns {lvls} -bins auto
     <prettyTableObject> createpivot -rows {sptype eptype} -columns {lvls} -bins auto:15 -hide_zeros
} ]
    # HELP -->
    return {}
  }

  if {$rows == {}} {
    puts " -E- no row selected (-rows)"
    incr error
  }

  if {([llength $columns] != 1) && ([llength $distributionTableBins])} {
    puts " -E- distribution table (-bin) can only be used when a single column has been specified (-columns)"
    incr error
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  if {$maxListSize == -1} {
    set maxListSize {end}
  }

  set pivotTbl [::tclapp::xilinx::designutils::prettyTable::Create]

  ::tclapp::xilinx::designutils::prettyTable::generatePivotTable $self $pivotTbl $rows $columns \
                                        -filter $filter \
                                        -bins $distributionTableBins -names $histogramNames \
                                        -max_list_size $maxListSize -precision $precision \
                                        -hide_zeros $distributionHideZeroBins \
                                        -quiet $quiet -verbose $verbose
  if {$print} {
    puts [$pivotTbl print]
  }

  return $pivotTbl
}

###########################################################################
##
## Methods for template 'pivottable'
##
###########################################################################

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::pivottable:refreshtable
#------------------------------------------------------------------------
# Usage: <prettyTableObject> refreshtable [<options>]
#------------------------------------------------------------------------
# Clone the object and return the cloned object. The original object
# is not modified
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::pivottable:refreshtable {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Refresh the pivot table (-help)
  set print 0
  set error 0
  set help 0
  set verbose 0
  set quiet 0
#   if {[llength $args] == 0} { incr help }
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-r(o(ws?)?)?$} {
        $self set_param {pivotRows} [lshift args]
      }
      {^-c(o(l(u(m(ns?)?)?)?)?)?$} {
        $self set_param {pivotColumns} [lshift args]
      }
      {^-m(ax?)?$} {
        $self set_param {pivotMaxListSize} [lshift args]
      }
      {^-s(o(u(r(ce?)?)?)?)?$} {
        $self set_param {pivotSource} [lshift args]
      }
      {^-pre(c(i(s(i(on?)?)?)?)?)?$} {
        $self set_param {pivotPrecision} [lshift args]
      }
      {^-bins$} -
      {^-bi(ns?)?$} {
        $self set_param {pivotDistributionBins} [lshift args]
        # Reset the column names
        $self set_param {pivotDistributionNames} {}
      }
      {^-names$} -
      {^-na(m(es?)?)?$} {
        $self set_param {pivotDistributionNames} [lshift args]
      }
      {^-filter$} -
      {^-f(i(l(t(er?)?)?)?)?$} {
        $self set_param {pivotFilter} [lshift args]
      }
      {^-hide_zeros$} -
      {^-hi(d(e(_(z(e(r(os?)?)?)?)?)?)?)?$} {
        $self set_param {pivotDistributionNoEmptyBins} 1
      }
      {^-show_zeros$} -
      {^-sh(o(w(_(z(e(r(os?)?)?)?)?)?)?)?$} {
        $self set_param {pivotDistributionNoEmptyBins} 0
      }
      {^-pri(nt?)?$} {
        set print 1
      }
      {^-q(u(i(et?)?)?)?$} {
        set quiet 1
      }
      {^-v(e(r(b(o(se?)?)?)?)?)?$} {
        set verbose 1
      }
      {^\?$} -
      {^-h(e(lp?)?)?$} {
        set help 1
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
  Usage: <prettyTableObject> refreshtable
              [-rows <row(s)>]
              [-columns <column(s)>]
              [-max <max_list_size>]
              [-precision <number>]
              [-filter <options>]
              [-bins <list_histogram_bins>|-bins auto[:<number_of_bins]]
              [-names <list_histogram_column_names>]
              [-hide_zeros][-show_zeros]
              [-source <prettyTableObject>]
              [-print]
              [-quiet]
              [-verbose|-v]
              [-help|-h]

  Description: Refresh a pivot table

    -rows: tables columns to be used for the pivot table rows. Columns names or
      columns indexes can be specified
    -columns: tables columns to be used for the pivot table columns. Columns
      names or columns indexes can be specified
    -max: maximum length for lists (-1: no limit)
    -precision: numeric precision. Default 3 digits (-1 to remove limit)
    -filter: filtering applied to the source data prior creating the pivot table
      Same options that can be specified for method 'search'
    -source: change the source to build the pivot table
    -bins: list of bins for the distribution table. A single column (-columns) must be specified
      The specified values represent the minimal values for each bin.
    -names: header names for the distribution table. A single column (-columns) must be specified
    -hide_zeros: hide distribution table bins with 0
    -show_zeros: show distribution table bins with 0

  Example:
     <prettyTableObject> refreshtable
     <prettyTableObject> refreshtable -source <prettyTableObject> -filter {-columns 3 -gt 2.0}
     <prettyTableObject> refreshtable -rows {sptype eptype} -columns {maxfo slack:min slack:max}
     <prettyTableObject> refreshtable -rows {1 2} -columns {4 5:min 5:max slack:average} -precision -1
     <prettyTableObject> refreshtable -rows {1 2} -columns {4 5:min 5:max slack:average} -precision -1
     <prettyTableObject> refreshtable -columns {maxfo} -bins {0 10 50 100 300 500 1000 10000}
     <prettyTableObject> refreshtable -columns {maxfo} -bins auto
     <prettyTableObject> refreshtable -columns {maxfo} -bins auto:15 -show_zeros
} ]
    # HELP -->
    return {}
  }

  if {[$self get_param {pivotRows}] == {}} {
    puts " -E- no row selected (-rows)"
    incr error
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  if {[$self get_param {pivotMaxListSize}] == -1} {
    $self set_param {pivotMaxListSize} {end}
  }

  if {!$quiet} {
    puts " -I- refreshing pivot table from '[$self get_param {pivotSource}]'"
    if {[$self get_param {pivotFilter}] != {}} {
      puts " -I- filtering: [$self get_param {pivotFilter}]"
    }
  }
  ::tclapp::xilinx::designutils::prettyTable::generatePivotTable [$self get_param {pivotSource}] \
                                        $self \
                                        [$self get_param {pivotRows}] \
                                        [$self get_param {pivotColumns}] \
                                        -filter [$self get_param {pivotFilter}] \
                                        -bins [$self get_param {pivotDistributionBins}] -names [$self get_param {pivotDistributionNames}] \
                                        -hide_zeros [$self get_param {pivotDistributionNoEmptyBins}] \
                                        -max_list_size [$self get_param {pivotMaxListSize}] \
                                        -precision [$self get_param {pivotPrecision}] \
                                        -quiet $quiet -verbose $verbose

  if {$print} {
    puts [$self print]
  }
  return $self
}

###########################################################################
##
## Helper procs for template 'deviceview'
##
###########################################################################

eval [list namespace eval ::tclapp::xilinx::designutils::prettyTable::deviceview {}]

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::deviceview::region2XY
#------------------------------------------------------------------------
# Convert a S*X*Y* region into X/Y cell coordonnates
# Assumption: the table origin is bottom/left with -offsetx 1 -offsety 0
#------------------------------------------------------------------------
# E.g:
#   $tbl incrcell {*}[::tclapp::xilinx::designutils::prettyTable::deviceview::region2XY $tbl S0X3Y0]
#   foreach {X Y} [::tclapp::xilinx::designutils::prettyTable::deviceview::region2XY $tbl $region] { break }

#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::deviceview::region2XY {self region} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  set cellX -1
  set cellY -1
  # For monolithic SSI devices: maxX/maxY represent the size of the entire device
  # For 2x2 SLR devices: maxX/maxY represent the size of a single SLR. All other SLRs are expected to have a similar footprint
  set maxX [subst $${self}::params(deviceMaxX)]
  set maxY [subst $${self}::params(deviceMaxY)]
  if {[regexp {^(S([0-9]))?X([0-9]+)Y([0-9]+)$} $region - - S X Y]} {
    # E.g: 2x2 SLR device
    #  +----+----+----+----+----+----+----+----+----+----+----+-----+-----+-----+-----+----+----+----+----+----+----+----+----+----+----+
    #  |    | X0 | X1 | X2 | X3 | X4 | X5 | X6 | X7 | X8 | X9 | X10 | X11 | X11 | X10 | X9 | X8 | X7 | X6 | X5 | X4 | X3 | X2 | X1 | X0 |
    #  +----+----+----+----+----+----+----+----+----+----+----+-----+-----+-----+-----+----+----+----+----+----+----+----+----+----+----+
    #  | Y0 |    |    |    |    |    |    |    |    |    |    |     |     |     |     |    |    |    |    |    |    |    |    |    |    |
    #  | Y1 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
    #  | Y2 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
    #  | Y3 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
    #  | Y4 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
    #  | Y5 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
    #  | Y6 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
    #  +----+----+----+----+----+----+----+----+----+----+----+-----+-----+-----+-----+----+----+----+----+----+----+----+----+----+----+
    #  | Y6 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
    #  | Y5 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
    #  | Y4 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
    #  | Y3 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
    #  | Y2 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
    #  | Y1 |    |    |    |    |    |    |    |    |    |  x |   x |   x |   x |   x |  x |    |    |    |    |    |    |    |    |    |
    #  | Y0 |    |    |    |    |    |    |    |    |    |    |     |     |     |     |    |    |    |    |    |    |    |    |    |    |
    #  +----+----+----+----+----+----+----+----+----+----+----+-----+-----+-----+-----+----+----+----+----+----+----+----+----+----+----+
    switch $S {
      0 {
        # SLR0 - 2x2
        set cellX $X
        set cellY $Y
      }
      1 {
        # SLR1 - 2x2
        set cellX $X
        set cellY [expr $maxY + ($maxY - $Y +1)]
      }
      2 {
        # SLR2 - 2x2
        set cellX [expr $maxX + ($maxX - $X +1)]
        set cellY [expr $maxY + ($maxY - $Y +1)]
      }
      3 {
        # SLR3 - 2x2
        set cellX [expr $maxX + ($maxX - $X +1)]
        set cellY $Y
      }
      "" {
        # For SSI/monolithic
        set cellX $X
        set cellY $Y
      }
      default {
#         puts " -W- unrecognized region $region"
      }
    }
  } else {
#     puts " -W- unrecognized region $region"
  }
  return [list $cellX $cellY]
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::deviceview::updateOrigin
#------------------------------------------------------------------------
# Update the table origin based on the clock region
# Note: The table params origin/offsetx/offsety are modified
#------------------------------------------------------------------------
# Example usage:
#   # Save settings
#   set tmpOrigin [subst $${self}::params(origin)]
#   set tmpOffsetX [subst $${self}::params(offsetx)]
#   set tmpOffsetY [subst $${self}::params(offsety)]
#   ...
#   if {[regexp {^(S([0-9]))?X([0-9]+)Y([0-9]+)$} $region - - S X Y]} {
#     ::tclapp::xilinx::designutils::prettyTable::deviceview::updateOrigin $self $region
#     ::tclapp::xilinx::designutils::prettyTable::method:incrcells $self $X $Y
#   }
#   ...
#   # Restore settings
#   set ${self}::params(origin) $tmpOrigin
#   set ${self}::params(offsetx) $tmpOffsetX
#   set ${self}::params(offsety) $tmpOffsetY
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::deviceview::updateOrigin {self region} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # For monolithic SSI devices: origin is bottom/left
  # For 2x2 SLR devices: the origin depends on the SLR. The assumption is
  # that the user will not attemp to specify X/Y beyond the SLR boundaries
  if {[regexp {^(S([0-9]))?X([0-9]+)Y([0-9]+)$} $region - - S X Y]} {
    switch $S {
      0 {
        # SLR0 - 2x2
        $self configure -origin bottomleft -offsetx 1 -offsety 0
      }
      1 {
        # SLR1 - 2x2
        $self configure -origin topleft -offsetx 1 -offsety 0
      }
      2 {
        # SLR2 - 2x2
        $self configure -origin topright -offsetx 0 -offsety 0
      }
      3 {
        # SLR3 - 2x2
        $self configure -origin bottomright -offsetx 0 -offsety 0
      }
      "" {
        # For SSI
        $self configure -origin bottomleft -offsetx 1 -offsety 0
      }
      default {
#         puts " -W- unrecognized region $region"
      }
    }
  } else {
#     puts " -W- unrecognized region $region"
  }
  return -code ok
}

###########################################################################
##
## Methods for template 'deviceview'
##
###########################################################################

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::deviceview:cleardevice
#------------------------------------------------------------------------
# Usage: <prettyTableObject> cleardevice
#------------------------------------------------------------------------
# Clear the device view (and restore the invalid clock regions)
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::deviceview:cleardevice {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Clear the device view (?)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows

  if {([llength $args] != 0) && ([llength $args] != 1)} { set args {-help} }
  if {[lsearch {-h -help ?} [lindex $args 0]] != -1} {
    puts [format {  Usage: <prettyTableObject> cleardevice [<char>]}]
    puts [format {  Default: x }]
    return -code ok
  }
  set char {x}
  if {[llength $args]} {
    set char [lindex $args 0]
  }

  # Clear the table
  $self cleartable

  # Restore the invalid clock regions
  set invalidClockRegions [subst $${self}::params(deviceInvalidCRs)]
  foreach region $invalidClockRegions {
    if {[regexp {^(S([0-9]))?X([0-9]+)Y([0-9]+)$} $region - - S X Y]} {
      ::tclapp::xilinx::designutils::prettyTable::deviceview:setregion $self $region $char
    } else {
      puts " -W- unrecognized region $region"
    }
  }

  return $self
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::deviceview:getregion
#------------------------------------------------------------------------
# Usage: <prettyTableObject> getregion <region>
#------------------------------------------------------------------------
# Get a clock region value (for template 'deviceview')
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::deviceview:getregion {self region} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Get a clock region value
  foreach {X Y} [::tclapp::xilinx::designutils::prettyTable::deviceview::region2XY $self $region] { break }
  set value [::tclapp::xilinx::designutils::prettyTable::method:getcells $self $X $Y]
  return $value
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::deviceview:setregion
#------------------------------------------------------------------------
# Usage: <prettyTableObject> setregion <region> <value>
#------------------------------------------------------------------------
# Set a clock region to a value (for template 'deviceview')
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::deviceview:setregion {self region value} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Set a clock region value
  foreach {X Y} [::tclapp::xilinx::designutils::prettyTable::deviceview::region2XY $self $region] { break }
  ::tclapp::xilinx::designutils::prettyTable::method:setcells $self $X $Y $value
  return $self
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::deviceview:incrregion
#------------------------------------------------------------------------
# Usage: <prettyTableObject> incrregion <region> [<value>]
#------------------------------------------------------------------------
# Increment a clock region to a value (for template 'deviceview')
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::deviceview:incrregion {self region {value 1}} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Increment a clock region value
  foreach {X Y} [::tclapp::xilinx::designutils::prettyTable::deviceview::region2XY $self $region] { break }
  ::tclapp::xilinx::designutils::prettyTable::method:incrcells $self $X $Y $value
  return $self
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::deviceview:plotregions
#------------------------------------------------------------------------
# Usage: <prettyTableObject> plotregions [<list>]
#------------------------------------------------------------------------
# Plot a list of clock regions for template 'deviceview'
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::deviceview:plotregions {self L args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Plot a list of clock regions
  array set defaults [list \
      -clear 1 \
      -char {x} \
    ]
  array set options [array get defaults]
  array set options $args
  if {$options(-clear)} {
    ::tclapp::xilinx::designutils::prettyTable::deviceview:cleardevice $self $options(-char)
#     ::tclapp::xilinx::designutils::prettyTable::method:cleartable $self
  }

  foreach el $L {
    if {$el == {}} { continue }
    if {[regexp {^(S([0-9]))?X([0-9]+)Y([0-9]+)$} $el - - S X Y]} {
      ::tclapp::xilinx::designutils::prettyTable::deviceview:incrregion $self $el
    } else {
      puts " -W- unrecognized region $el"
    }
  }

  return $self
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::deviceview:plotcells
#------------------------------------------------------------------------
# Usage: <prettyTableObject> plotcells [<list>]
#------------------------------------------------------------------------
# Plot a list of cells for template 'deviceview'
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::deviceview:plotcells {self cells args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Plot a list of cells
  array set defaults [list \
      -clear 1 \
      -char {x} \
    ]
  array set options [array get defaults]
  array set options $args
  if {$options(-clear)} {
    ::tclapp::xilinx::designutils::prettyTable::deviceview:cleardevice $self $options(-char)
#     ::tclapp::xilinx::designutils::prettyTable::method:cleartable $self
  }
  set L [list]
  foreach cell [filter [get_cells -quiet $cells] {IS_PRIMITIVE}] {
    lappend L [get_clock_regions -quiet -of $cell]
  }
  if {[llength $L]} {
#     $self plotregions $L
    ::tclapp::xilinx::designutils::prettyTable::deviceview:plotregions $self $L -clear 0
  }
  return $self
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::deviceview:plotnets
#------------------------------------------------------------------------
# Usage: <prettyTableObject> plotnets [<list>]
#------------------------------------------------------------------------
# Plot a list of nets (loads + driver) for template 'deviceview'
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::deviceview:plotnets {self nets args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  # Plot a list of nets
  array set defaults [list \
      -clear 1 \
      -char {x} \
    ]
  array set options [array get defaults]
  array set options $args
  if {$options(-clear)} {
    ::tclapp::xilinx::designutils::prettyTable::deviceview:cleardevice $self $options(-char)
#     ::tclapp::xilinx::designutils::prettyTable::method:cleartable $self
  }
  set nets [get_nets -quiet $nets -segments -top_net_of_hierarchical_group -filter {TYPE != POWER && TYPE != GROUND}]
  set drivers [list]
  foreach net $nets {
    set driver [get_cells -quiet -of [get_pins -quiet -of $net -leaf -filter {DIRECTION == OUT}]] ; llength $driver
    lappend drivers $driver
    set loads [get_cells -quiet -of [get_pins -quiet -of $net -leaf -filter {DIRECTION == IN}]] ; llength $loads
    if {[llength $loads]} {
#       $self plotcells $loads
      ::tclapp::xilinx::designutils::prettyTable::deviceview:plotcells $self $loads -clear 0
    }
  }
  # Keep track of how many drivers in each clock region
  set drvs [dict create]
  foreach cell $drivers {
    set region [get_clock_regions -quiet -of $cell]
    dict incr drvs $region
  }
  foreach region [dict keys $drvs] {
    set num [dict get $drvs $region]
    if {[regexp {^(S([0-9]))?X([0-9]+)Y([0-9]+)$} $region - - S X Y]} {
      set val [::tclapp::xilinx::designutils::prettyTable::deviceview:getregion $self $region]
      if {$num >= 2} {
        set val [format {(%s D) %s} $num $val]
      } elseif {$val == {}} {
        set val [format {(D)}]
      } else {
        set val [format {(D) %s} $val]
      }
      ::tclapp::xilinx::designutils::prettyTable::deviceview:setregion $self $region $val
    }
  }
  return $self
}

###########################################################################
##
## Examples Scripts
##
###########################################################################

if 0 {
  set tbl [::tclapp::xilinx::designutils::prettyTable {This is the title of the table}]
  $tbl header [list "name" "#Pins" "case_value" "user_case_value"]
  $tbl addrow [list A/B/C/D/E/F 12 - -]
  $tbl addrow [list A/B/C/D/E/G 24 1 -]
  $tbl addrow [list A/B/C/D/E/H 48 0 1]
  $tbl addrow [list A/B/C/D/E/H 46 0 1]
  $tbl addrow [list A/B/C/D/E/H 44 1 0]
  $tbl addrow [list A/B/C/D/E/H 42 1 0]
  $tbl addrow [list A/B/C/D/E/H 40 1 0]
  $tbl separator
  $tbl separator
  $tbl separator
  $tbl addrow [list A/I1 10 1 0]
  $tbl addrow [list A/I2 12 0 1]
  $tbl addrow [list A/I3 8 - -]
  $tbl addrow [list A/I4 6 - -]
  $tbl separator
  $tbl separator
  $tbl print
  $tbl indent 2
  $tbl print
  # $tbl reset
  $tbl header [list "name" "#Pins" "case_value" "user_case_value" "HEAD1" "HEAD2" "HEAD3" "HEAD4"]
  $tbl print
  $tbl sizeof
  set new [$tbl clone]
  $new print
  $new sort -#Pins
  $new print
  ::tclapp::xilinx::designutils::prettyTable sizeof
  ::tclapp::xilinx::designutils::prettyTable info
  # ::tclapp::xilinx::designutils::prettyTable destroyall
  # $tbl destroy
}

if 0 {
  set tbl [::tclapp::xilinx::designutils::prettyTable]
  $tbl configure -limit -1
  $tbl configure -display_limit -1
  set Header [list NAME CLASS DIRECTION IS_LEAF IS_CLOCK LOGIC_VALUE SETUP_SLACK HOLD_SLACK]
  $tbl header $Header
  foreach pin [get_pins -hier *] {
    set row [list]
    foreach prop $Header {
      lappend row [get_property $prop $pin]
    }
    $tbl addrow $row
  }
  $tbl sort -SETUP_SLACK
  $tbl print -file table.rpt
}

if {0} {

  proc plot {cells args} {
    set defaults [list -marker 0 -file {}]
    array set options $defaults
    array set options $args

    set channel {stdout}
    if {$options(-file) != {}} {
      set channel [open $options(-file) {w}]
    }

    set tbl [::tclapp::xilinx::designutils::prettyTable template deviceview]

    foreach cell [get_cells -quiet [lsort -unique $cells]] {

      set net [get_nets -of [get_pins -of $cell -filter {DIRECTION == OUT}]]
      set driver [get_pins -of $net -leaf -filter {DIRECTION == OUT}] ; llength $driver
      set loads [get_pins -of $net -leaf -filter {DIRECTION == IN}] ; llength $loads

      $tbl cleartable
      $tbl configure -align_right

      foreach load [get_cells -quiet -of $loads] {
        set region [get_clock_regions -quiet -of $load]
        regexp {^(S([0-9]))?X([0-9]+)Y([0-9]+)$} $region - - S X Y
        $tbl incrcells $X $Y
      }

      foreach c [get_cells -quiet -of $driver] {
        set region [get_clock_regions -quiet -of $c]
        regexp {^(S([0-9]))?X([0-9]+)Y([0-9]+)$} $region - - S X Y
      #   $tbl appendcells $X $Y " (D)"
        $tbl prependcells $X $Y "(D) "
      }

      set clockRoot [get_property -quiet CLOCK_ROOT $net]
      set userClockRoot [get_property -quiet USER_CLOCK_ROOT $net]

      if {$clockRoot != {}} {
        regexp {^(S([0-9]))?X([0-9]+)Y([0-9]+)$} $clockRoot - - S X Y
        $tbl prependcells $X $Y "(R) "
      }

      if {$userClockRoot != {}} {
        regexp {^(S([0-9]))?X([0-9]+)Y([0-9]+)$} $userClockRoot - - S X Y
        $tbl prependcells $X $Y "(U) "
      }

      if {$clockRoot != {}} {
        set clockRoot [format { (CLOCK_ROOT: %s)} $clockRoot]
      }
      $tbl title "$cell\n[get_property -quiet REF_NAME $cell]${clockRoot}\nFanout: [expr [get_property FLAT_PIN_COUNT $net] -1]"
      puts $channel [$tbl print]

      # +------------------------------------------------------------------+
      # | PTM_RESERVED_FOR_ENMAPPING_mapped_SCG_SST_logic_4_0/PTM_RESERVED_FOR_ENMAPPING_mapped_SCG_slrn_buf_out[0]_BUFGCE |
      # | BUFGCE (CLOCK_ROOT: X7Y7)                                        |
      # | Fanout: 16549                                                    |
      # +-----+----+-----+-----+-----+------+------+-----+-----------+-----+
      # |     | X0 | X1  | X2  | X3  | X4   | X5   | X6  | X7        | X8  |
      # +-----+----+-----+-----+-----+------+------+-----+-----------+-----+
      # | Y14 | 14 |  42 |  58 |  33 |  146 |   12 |     |           |     |
      # | Y13 | 29 | 117 |  96 |  91 |  133 |  106 |   1 |         1 |     |
      # | Y12 |  8 |  77 |  67 | 267 |  406 |  214 |  72 |         1 |     |
      # | Y11 | 22 |  99 | 126 |  58 |  108 |  329 |  28 |           |     |
      # | Y10 | 16 |  41 | 102 |  78 |  186 |  200 |  45 |           |     |
      # +-----+----+-----+-----+-----+------+------+-----+-----------+-----+
      # |  Y9 |    |  93 |  36 |     |      |      | 106 |       176 | 190 |
      # |  Y8 |    | 325 | 408 | 278 |  556 |   76 |  11 |        19 |  18 |
      # |  Y7 |    | 177 |   8 |     |  286 | 1161 | 435 | (R) (D) 1 |     |
      # |  Y6 | 10 | 143 |  51 | 153 | 1040 | 1244 | 256 |         2 |     |
      # |  Y5 |    |     | 263 | 236 |  524 |  426 |   3 |           |     |
      # +-----+----+-----+-----+-----+------+------+-----+-----------+-----+
      # |  Y4 |    |   5 | 118 | 454 |  468 |    5 |  50 |        37 |     |
      # |  Y3 |    |     |  17 | 561 |  254 |    1 |  40 |         3 |   1 |
      # |  Y2 |    |     |   8 | 271 |  214 |  107 |  78 |        66 |     |
      # |  Y1 |    |     |     |     |   13 |    3 | 134 |       350 |     |
      # |  Y0 |    |     |  50 | 244 |  409 |  257 |     |       104 |  87 |
      # +-----+----+-----+-----+-----+------+------+-----+-----------+-----+

      if {$options(-marker)} {
        mark_objects -color red $driver
        mark_objects -color green $loads
      }
    }
    if {$channel != {stdout}} {
      close $channel
      puts " -I- Generated file '[file normalize $options(-file)]'"
    }
    catch {$tbl destroy}
    return -code ok
  }

}

