package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export prettyTable
}

########################################################################################
##
## Company:        Xilinx, Inc.
## Created by:     David Pefourque
##
## Version:        2016.08.23
## Tool Version:   Vivado 2013.1
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

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils::prettyTable {
  variable n 0
#   set params [list indent 0 maxNumRows 10000 maxNumRowsToDisplay 50 title {} ]
  variable params [list indent 0 title {} tableFormat {classic} cellAlignment {left} maxNumRows -1 maxNumRowsToDisplay -1 columnsToDisplay {} origin {topleft} offsetx 0 offsety 0 template {} methods {method}]
  variable version {2016.08.23}
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
  set error 0
  set show_help 0
  set method [lshift args]
  switch -exact -- $method {
    sizeof {
      return [eval [concat ::tclapp::xilinx::designutils::prettyTable::Sizeof] ]
    }
    info {
      return [eval [concat ::tclapp::xilinx::designutils::prettyTable::Info] ]
    }
    destroyall {
      return [eval [concat ::tclapp::xilinx::designutils::prettyTable::DestroyAll] ]
    }
    -u -
    -us -
    -usa -
    -usag -
    -usage -
    -h -
    -he -
    -hel -
    -help {
      incr show_help
    }
    create {
      return [eval [concat ::tclapp::xilinx::designutils::prettyTable::Create $args] ]
    }
    template {
      # Create table based on template
      return [eval [concat ::tclapp::xilinx::designutils::prettyTable::Template $args] ]
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
                  [sizeof]                 - Provides the memory consumption of all the prettyTable objects
                  [info]                   - Provides a summary of all the prettyTable objects that have been created
                  [destroyall]             - Destroy all the prettyTable objects and release the memory
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
      foreach slr [lsort [get_slrs -quiet]] {
        foreach region [get_clock_regions -quiet -of $slr] {
          regexp {^X([0-9]+)Y([0-9]+)$} $region - X Y
          if {$X > $maxX} { set maxX $X }
          if {$Y > $maxY} { set maxY $Y }
          lappend ar(${slr}:X) $X
          lappend ar(${slr}:Y) $Y
        }
      }
      set column0 [list]
      set header [list {}]
      for {set i 0} {$i <= $maxX} {incr i} {
        lappend header "X$i"
      }
      for {set i $maxY} {$i >= 0} {incr i -1} {
        lappend column0 "Y$i"
      }
      set tbl [::tclapp::xilinx::designutils::prettyTable]
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
# Convert coordonates for getcell/setcell/appendcell
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
# ::tclapp::xilinx::designutils::prettyTable::exportToTCL
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Dump the content of the prettyTable object as Tcl code
# The result is returned as a single string or through upvar
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::exportToTCL {self args} {
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
$tbl configure -title {%s} -indent %s -limit %s -display_limit %s -display_columns {%s}
$tbl header [list %s]} $params(title) $params(indent) $params(maxNumRows) $params(maxNumRowsToDisplay) $params(columnsToDisplay) $header]
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
# ::tclapp::xilinx::designutils::prettyTable::exportToCSV
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Dump the content of the prettyTable object as CSV format
# The result is returned as a single string or through upvar
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::exportToCSV {self args} {
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
# ::tclapp::xilinx::designutils::prettyTable::exportToLIST
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Dump the content of the prettyTable object as "list" with one
# line per row
# The result is returned as a single string or throug upvar
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::exportToLIST {self args} {
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
# ::tclapp::xilinx::designutils::prettyTable::exportToTCLArray
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Dump the content of the prettyTable object as a fragment Tcl code to
# set a Tcl array
# The result is returned as a single string or through upvar
# The result can be used as, for example: array set myarray [source res.ftcl]
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::exportToArray {self args} {
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


  upvar #0 ${self}::table table
  upvar #0 ${self}::indent indent
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
    eval ::tclapp::xilinx::designutils::prettyTable::${methods}:${method} $self $args
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
        set method [lindex [dict get $match $keys] end]
        eval $method $self $args
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


  # Add a row to the table
  set maxNumRows [subst $${self}::params(maxNumRows)]
  if {([subst $${self}::numRows] >= $maxNumRows) && ($maxNumRows != -1)} {
    error " -E- maximum number of rows reached ([subst $${self}::params(maxNumRows)]). Failed adding new row"
  }
  eval lappend ${self}::table $args
  incr ${self}::numRows
  return 0
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


  # Append a row to the previous row
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows
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
  return -code ok
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
  if {$col_idx == {end}} {
    set col_idx [llength $header]
  } elseif {$col_idx > [llength $header]} {
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
  return -code ok
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
  foreach col [lsort -integer -decreasing $columns] {
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
  return -code ok
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
  foreach pos [lsort -integer -decreasing $rows] {
    if {[catch {
      set table [lreplace $table $pos $pos]
    } errorstring]} {
      puts " -W- $errorstring"
    } else {
      incr numRows -1
    }
  }
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:getcell
#------------------------------------------------------------------------
# Usage: <prettyTableObject> getcell <col> <row>
#------------------------------------------------------------------------
# Return a cell by its <col> and <row> index
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:getcell {self column row} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils


  # Get a table cell value
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows
  if {($column == {}) || ($row == {})} {
    return {}
  }
  if {$column > [expr [llength $header] -1]} {
    puts " -W- column '$column' out of bound"
    return {}
  }
  if {$row > [expr [llength $table] -1]} {
    puts " -W- row '$row' out of bound"
    return {}
  }
  # Convert coordinates based on origin
  foreach {column row} [convertCoordinates $self $column $row] { break }
  set res [lindex [lindex $table $row] $column]
  return $res
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:setcell
#------------------------------------------------------------------------
# Usage: <prettyTableObject> setcell <col> <row>
#------------------------------------------------------------------------
# Set a cell value directly by its <col> and <row> index
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:setcell {self column row value} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils


  # Set a table cell value
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows
  if {($column == {}) || ($row == {})} {
    return {}
  }
  if {$column > [expr [llength $header] -1]} {
    puts " -W- column '$column' out of bound"
    return {}
  }
  if {$row > [expr [llength $table] -1]} {
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
# ::tclapp::xilinx::designutils::prettyTable::method:appendcell
#------------------------------------------------------------------------
# Usage: <prettyTableObject> appendcell <col> <row>
#------------------------------------------------------------------------
# Append to a cell value directly by its <col> and <row> index
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:appendcell {self column row value} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils


  # Append to a table cell value
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows
  if {($column == {}) || ($row == {})} {
    return {}
  }
  if {$column > [expr [llength $header] -1]} {
    puts " -W- column '$column' out of bound"
    return {}
  }
  if {$row > [expr [llength $table] -1]} {
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
# ::tclapp::xilinx::designutils::prettyTable::method:prependcell
#------------------------------------------------------------------------
# Usage: <prettyTableObject> prependcell <col> <row>
#------------------------------------------------------------------------
# Prepend to a cell value directly by its <col> and <row> index
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:prependcell {self column row value} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils


  # Prepend to a table cell value
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows
  if {($column == {}) || ($row == {})} {
    return {}
  }
  if {$column > [expr [llength $header] -1]} {
    puts " -W- column '$column' out of bound"
    return {}
  }
  if {$row > [expr [llength $table] -1]} {
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
# ::tclapp::xilinx::designutils::prettyTable::method:incrcell
#------------------------------------------------------------------------
# Usage: <prettyTableObject> incrcell <col> <row> <value>
#------------------------------------------------------------------------
# Incerment cell value directly by its <col> and <row> index
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:incrcell {self column row {value 1}} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils


  # Increment a table cell value
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::numRows numRows
  if {($column == {}) || ($row == {})} {
    return {}
  }
  if {$column > [expr [llength $header] -1]} {
    puts " -W- column '$column' out of bound"
    return {}
  }
  if {$row > [expr [llength $table] -1]} {
    puts " -W- row '$row' out of bound"
    return {}
  }
  set currentvalue [$self getcell $column $row]
  if {$currentvalue == {}} {
    set currentvalue 0
  }
  if {[catch {set newvalue [expr $currentvalue + $value]} errorstring]} {
    puts " -E- $errorstring"
    return -code ok
  }
  $self setcell $column $row $newvalue
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
# Usage: <prettyTableObject> setcolumn <col> <row>
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
  return [subst $${self}::numRows]
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
# Usage: <prettyTableObject> separator
#------------------------------------------------------------------------
# Add a separator after the last inserted row
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:separator {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils


  # Add a row separator
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
  return -code ok
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
  set ${self}::columnsToDisplay [list]
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
  set ${self}::columnsToDisplay [list]
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
  set printHeader 1
  set printTitle 1
#   set align {-} ; # '-' for left cell alignment and '' for right cell alignment
  if {$params(cellAlignment) == {left}} { set align {-} } else { set align {} } ; # '-' for left cell alignment and '' for right cell alignment
#   set format {classic} ; # table format: classic|lean
  set format $params(tableFormat) ; # table format: classic|lean
  set append 0
  set returnVar {}
  set columnsToDisplay $params(columnsToDisplay)
  while {[llength $args]} {
    set name [lshift args]
    switch -exact -- $name {
      -f -
      -file {
           set filename [lshift args]
      }
      -a -
      -append {
           set append 1
      }
      -from {
           set startRow [lshift args]
      }
      -return_var {
           set returnVar [lshift args]
      }
      -column -
      -columns {
           set columnsToDisplay [lshift args]
      }
      -noheader {
           set printHeader 0
      }
      -left -
      -align_left {
           set align {-}
      }
      -right -
      -align_right {
           set align {}
      }
      -lean {
           set format {lean}
      }
      -classic {
           set format {classic}
      }
      -format {
           set format [lshift args]
      }
      -indent {
           set indent [lshift args]
      }
      -notitle {
           set printTitle 0
      }
      -h -
      -help {
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
  Usage: <prettyTableObject> print
              [-file <filename>]
              [-append]
              [-return_var <tcl_var_name>]
              [-columns <list_of_columns_to_display>]
              [-from <start_row_number>]
              [-align_left|-left]
              [-align_right|-right]
              [-format classic|lean][-lean][-classic]
              [-indent <indent_level>]
              [-noheader]
              [-notitle]
              [-help|-h]

  Description: Return table content.

  Example:
     <prettyTableObject> print
     <prettyTableObject> print -columns {0 2 5}
     <prettyTableObject> print -return_var report
     <prettyTableObject> print -file output.rpt -append
} ]
    # HELP -->
    return {}
  }

  switch $format {
    lean -
    classic {
    }
    default {
      puts " -E- invalid format '$format'. The valid formats are: classic|lean"
      incr error
    }
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

  set maxs {}
  foreach item $header {
      lappend maxs [string length $item]
  }
  set numCols [llength $header]
  set count 0
  set maxNumRowsToDisplay [subst $${self}::params(maxNumRowsToDisplay)]
  foreach row $table {
      incr count
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
      lean {
        append separator "[string repeat - [lindex $maxs $index]]  "
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
          lean {
            append res " \n"
          }
          classic {
            append res " |\n"
          }
        }
      }
      switch $format {
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
        lean {
          append res [format "%-[lindex $maxs $index]s  " [lindex $header $index]]
        }
        classic {
          append res [format " %-[lindex $maxs $index]s |" [lindex $header $index]]
        }
      }
    }
    append res "\n"
  }
  append res "${separator}\n"
  # Generate the table rows
  set count 0
  foreach row $table {
      incr count
      if {($count > $maxNumRowsToDisplay) && ($maxNumRowsToDisplay != -1)} {
        # Did we reach the maximum of rows to be displayed?
        break
      }
      switch $format {
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
           lean {
             append res [format "%${align}[lindex $maxs $index]s  " [lindex $row $index]]
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
      lean {
      }
      classic {
        append res $separator
      }
    }
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
  puts [format {    Header: %s} $header]
  puts [format {    # Cols: %s} [llength $header]]
  puts [format {    # Rows: %s} [subst $${self}::numRows] ]
  foreach param [lsort [array names params]] {
    puts [format {    Param[%s]: %s} $param $params($param)]
  }
  puts [format {    Memory footprint: %d bytes} [::tclapp::xilinx::designutils::prettyTable::method:sizeof $self]]
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
    if {[regexp {^(\-h(elp)?)$} $elm]} {
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
    if {$command == {}} {
      set command "lsort $direction $sortType -index $index \$table"
    } else {
      set command "lsort $direction $sortType -index $index \[$command\]"
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
    switch -exact -- $name {
      -title {
           set ${self}::params(title) [lshift args]
      }
      -left -
      -align_left {
           set ${self}::params(cellAlignment) {left}
      }
      -right -
      -align_right {
           set ${self}::params(cellAlignment) {right}
      }
      -lean {
           set ${self}::params(tableFormat) {lean}
      }
      -classic {
           set ${self}::params(tableFormat) {classic}
      }
      -format {
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
      -indent {
           set ${self}::params(indent) [lshift args]
      }
      -limit {
           set ${self}::params(maxNumRows) [lshift args]
      }
      -display -
      -display_limit {
           set ${self}::params(maxNumRowsToDisplay) [lshift args]
      }
      -origin {
           set origin [lshift args]
           if {[lsearch [list topleft topright bottomleft bottomright ] $origin] != -1} {
             set ${self}::params(origin) $origin
           } else {
             puts " -W- invalid value '$origin' for -origin. Valid values are: topleft topright bottomleft bottomright"
           }
      }
      -offsetx {
           set ${self}::params(offsetx) [lshift args]
      }
      -offsety {
           set ${self}::params(offsety) [lshift args]
      }
      -remove_separator -
      -remove_separators {
           set ${self}::separators [list]
      }
      -display_column -
      -display_columns {
           set ${self}::params(columnsToDisplay) [lshift args]
      }
      -h -
      -help {
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

    -origin: set the origin of coordinates for setcell/getcell/appendcell
      Valid values are: topleft|topright|bottomleft|bottomright
      Default value is: topleft
    -offsetx/-offsety: offset added to coordinates for setcell/getcell/appendcell

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
# ::tclapp::xilinx::designutils::prettyTable::method:import
#------------------------------------------------------------------------
# Usage: <prettyTableObject> import [<options>]
#------------------------------------------------------------------------
# Create the table from a CSV file
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:import {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils


  # Create table from CSV file (-help)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::params params
  upvar #0 ${self}::separators separators
  upvar #0 ${self}::numRows numRows

  set error 0
  set help 0
  set filename {}
  set csvDelimiter {,}
  if {[llength $args] == 0} { incr help }
  while {[llength $args]} {
    set name [lshift args]
    switch -exact -- $name {
      -d -
      -delimiter {
           set csvDelimiter [lshift args]
      }
      -f -
      -file {
           set filename [lshift args]
      }
      -h -
      -help {
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
              -file <filename>
              [-delimiter <csv_delimiter>]
              [-help|-h]

  Description: Create table from CSV file.

  Example:
     <prettyTableObject> import -file table.csv
     <prettyTableObject> import -file table.csv -delimiter ,
} ]
    # HELP -->
    return {}
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  if {![file exists $filename]} {
    error " -E- file '$filename' does not exist"
  }

  # Reset object but preserve some of the parameters
  set limit $params(maxNumRows)
#   set displayLimit $params(maxNumRowsToDisplay)
  eval $self reset
  set params(maxNumRows) $limit
#   set params(maxNumRowsToDisplay) $displayLimit

  set FH [open $filename]
  set first 1
  set count 0
  while {![eof $FH]} {
    gets $FH line
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
  close $FH
  puts " -I- Header: $header"
  puts " -I- Number of imported row(s): $count"
  return 0
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


  # Export table (table/list/CSV format/tcl script) (-help)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::separators separators
  upvar #0 ${self}::params params
  upvar #0 ${self}::numRows numRows

  set error 0
  set help 0
  set verbose 0
  set filename {}
  set append 0
  set printHeader 1
  set returnVar {}
  set format {table}
#   set tableFormat {classic}
  set tableFormat $params(tableFormat) ; # table format: classic|lean
  set csvDelimiter {,}
  set columnsToDisplay $params(columnsToDisplay)
  if {[llength $args] == 0} { incr help }
  while {[llength $args]} {
    set name [lshift args]
    switch -exact -- $name {
      -f -
      -format {
           set format [lshift args]
      }
      -d -
      -delimiter {
           set csvDelimiter [lshift args]
      }
      -file -
      -file {
           set filename [lshift args]
      }
      -a -
      -append {
           set append 1
      }
      -return_var {
           set returnVar [lshift args]
      }
      -column -
      -columns {
           set columnsToDisplay [lshift args]
      }
      -table {
           set tableFormat [lshift args]
      }
      -noheader {
           set printHeader 0
      }
      -v -
      -verbose {
           set verbose 1
      }
      -h -
      -help {
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
  Usage: <prettyTableObject> export
              -format table|csv|tcl|list|array
              [-table classic|lean]
              [-delimiter <csv_delimiter>]
              [-file <filename>]
              [-append]
              [-return_var <tcl_var_name>]
              [-columns <list_of_columns_to_display>]
              [-noheader]
              [-verbose|-v]
              [-help|-h]

  Description: Export table content. The -columns argument is only available for the
               'list' and 'table' export formats.

    -verbose: applicable with -format csv. Add some configuration information as comment

  Example:
     <prettyTableObject> export -format csv
     <prettyTableObject> export -format csv -return_var report
     <prettyTableObject> export -file output.rpt -append -columns {0 2 3 4}
} ]
    # HELP -->
    return {}
  }

  switch $tableFormat {
    lean -
    classic {
    }
    default {
      puts " -E- invalid table format '$tableFormat'. The valid formats are: classic|lean"
      incr error
    }
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  # No header has been defined
  if {[lsearch [list {table} {tcl} {csv} {list} {array}] $format] == -1} {
    error " -E- invalid format '$format'. The valid formats are: table | csv | tcl | list | array"
  }

  # The -return_var option provides the variable name from the caller's environment
  # that should receive the report
  if {$returnVar != {}} {
    # The caller's environment is 2 levels up
    upvar 2 $returnVar res
  }
  set res {}

  switch $format {
    table {
      if {$returnVar != {}} {
        if {$printHeader} {
          $self print -return_var res -columns $columnsToDisplay -format $tableFormat
        } else {
          $self print -return_var res -columns $columnsToDisplay -format $tableFormat -noheader
        }
      } else {
        if {$printHeader} {
          set res [$self print -columns $columnsToDisplay -format $tableFormat]
        } else {
          set res [$self print -columns $columnsToDisplay -format $tableFormat -noheader]
        }
      }
    }
    csv {
      if {$returnVar != {}} {
        if {$printHeader} {
          ::tclapp::xilinx::designutils::prettyTable::exportToCSV $self -delimiter $csvDelimiter -return_var res -verbose $verbose
        } else {
          ::tclapp::xilinx::designutils::prettyTable::exportToCSV $self -delimiter $csvDelimiter -return_var res -verbose $verbose -header 0
        }
      } else {
        if {$printHeader} {
          set res [::tclapp::xilinx::designutils::prettyTable::exportToCSV $self -delimiter $csvDelimiter -verbose $verbose]
        } else {
          set res [::tclapp::xilinx::designutils::prettyTable::exportToCSV $self -delimiter $csvDelimiter -verbose $verbose -header 0]
        }
      }
    }
    tcl {
      if {$returnVar != {}} {
        ::tclapp::xilinx::designutils::prettyTable::exportToTCL $self -return_var res
      } else {
        set res [::tclapp::xilinx::designutils::prettyTable::exportToTCL $self]
      }
    }
    list {
      if {$returnVar != {}} {
        ::tclapp::xilinx::designutils::prettyTable::exportToLIST $self -delimiter $csvDelimiter -return_var res -columns $columnsToDisplay
      } else {
        set res [::tclapp::xilinx::designutils::prettyTable::exportToLIST $self -delimiter $csvDelimiter -columns $columnsToDisplay]
      }
    }
    array {
      if {$returnVar != {}} {
        ::tclapp::xilinx::designutils::prettyTable::exportToArray $self -return_var res -columns $columnsToDisplay
      } else {
        set res [::tclapp::xilinx::designutils::prettyTable::exportToArray $self -columns $columnsToDisplay]
      }
    }
    default {
    }
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
  set str {}
  set matchStyle {-glob}
  set caseStyle {}
  set all {}
  set returnformat {rowidx}
  set columns {}
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
      {^-all?$} {
        set all {-all}
      }
      {^-pr(i(nt?)?)?$} {
        set print 1
      }
      {^-co(l(u(m(ns?)?)?)?)?$} {
        set columns [lshift args]
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
      {^-h(e(lp?)?)?$} {
        set help 1
      }
      default {
        if {[string match "-*" $name]} {
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
              [-glob][-exact][-regexp]
              [-columns <list_of_columns_to_search>]
              [-return_row_column_indexes]
              [-return_column_indexes]
              [-return_row_indexes]
              [-return_matching_strings]
              [-return_matching_rows]
              [-return_table]
              [-print]
              [-verbose|-v]
              [-help|-h]

  Description: Search for values inside the table

    Returns by default the row index(es) (-return_row_indexes)

  Example:
     <prettyTableObject> search -pattern {foo*} -nocase -glob
     <prettyTableObject> search {foo.+} -regexp -return_matching_rows -columns {0 2 3 4}
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

  set rowidx -1
  set res [list]
  set matchrows [list]
  # Search for pattern for each row
  foreach row $table {
    incr rowidx
    set match [lsearch {*}$all {*}$caseStyle {*}$matchStyle $row $str]
    if {($match != {}) && ($match != {-1})} {
      foreach colidx $match {
        if {($columns != {}) && ([lsearch $columns $colidx] == -1)} {
          # The column that has match is not in the list of columns specified by -columns
          continue
        }
        lappend res [list $rowidx $colidx [lindex $row $colidx]]
      }
      lappend matchrows $row
      if {$print} {
        $tbl addrow $row
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
  set print 0
  if {[llength $args] == 0} { incr help }
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-co(m(m(a(nd?)?)?)?)?$} {
        set procname [lshift args]
      }
      {^-ar(gs?)?$} {
        set procargs [lshift args]
      }
      {^-pr(i(nt?)?)?$} {
        set print 1
      }
      {^-v(e(r(b(o(se?)?)?)?)?)?$} {
        set verbose 1
      }
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
              -command <proc>|<proc>
              [-args <list_of_arguments>]
              [-print]
              [-verbose|-v]
              [-help|-h]

  Description: Filter table content

    The filter proc should be defined as: proc <procname> {row args} { ... ; return $row }

  Example:
     <prettyTableObject> filter myprocname
     <prettyTableObject> filter myprocname -args {-arg1 ... -argN}
} ]
    # HELP -->
    return {}
  }

  if {$procname == {}} {
    puts " -E- no proc name specified (-command)"
    incr error
  } elseif { [uplevel #0 [list info proc $procname]] == {} } {
    puts " -E- proc '$procname' does not exists<[info proc $procname]>"
    incr error
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
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
      # Tcl Error => the row shold not be prserved
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

  return -code ok
}

###########################################################################
##
## Methods for template 'deviceview'
##
###########################################################################

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
    ]
  array set options [array get defaults]
  array set options $args
  if {$options(-clear)} {
    ::tclapp::xilinx::designutils::prettyTable::method:cleartable $self
  }
  foreach el $L {
    if {$el == {}} { continue }
    if {[regexp {^X([0-9]+)Y([0-9]+)$} $el - X Y]} {
#       $self incrcell $X $Y
      ::tclapp::xilinx::designutils::prettyTable::method:incrcell $self $X $Y
    }
  }
  return -code ok
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
    ]
  array set options [array get defaults]
  array set options $args
  if {$options(-clear)} {
    ::tclapp::xilinx::designutils::prettyTable::method:cleartable $self
  }
  set L [list]
  foreach cell [filter [get_cells -quiet $cells] {IS_PRIMITIVE}] {
    lappend L [get_clock_regions -quiet -of $cell]
  }
  if {[llength $L]} {
#     $self plotregions $L
    ::tclapp::xilinx::designutils::prettyTable::deviceview:plotregions $self $L -clear 0
  }
  return -code ok
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
    ]
  array set options [array get defaults]
  array set options $args
  if {$options(-clear)} {
    ::tclapp::xilinx::designutils::prettyTable::method:cleartable $self
  }
  set nets [get_nets -quiet $nets -filter {TYPE != POWER && TYPE != GROUND}]
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
    if {[regexp {^X([0-9]+)Y([0-9]+)$} $region - X Y]} {
#       $self appendcell $X $Y " (D)"
      set val [::tclapp::xilinx::designutils::prettyTable::method:getcell $self $X $Y]
      if {$num >= 2} {
#         set val [format {(%sxD) %s} $num $val]
        set val [format {(%s D) %s} $num $val]
#         ::tclapp::xilinx::designutils::prettyTable::method:prependcell $self $X $Y "(${num} D) "
#         ::tclapp::xilinx::designutils::prettyTable::method:appendcell $self $X $Y " (${num} D)"
      } else {
        set val [format {(D) %s} $val]
#         ::tclapp::xilinx::designutils::prettyTable::method:prependcell $self $X $Y "(D) "
#         ::tclapp::xilinx::designutils::prettyTable::method:appendcell $self $X $Y " (D)"
      }
      ::tclapp::xilinx::designutils::prettyTable::method:setcell $self $X $Y $val
    }
  }
  return -code ok
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

    set tbl [tb::prettyTable template deviceview]

    foreach cell [get_cells -quiet [lsort -unique $cells]] {

      set net [get_nets -of [get_pins -of $cell -filter {DIRECTION == OUT}]]
      set driver [get_pins -of $net -leaf -filter {DIRECTION == OUT}] ; llength $driver
      set loads [get_pins -of $net -leaf -filter {DIRECTION == IN}] ; llength $loads

      $tbl cleartable
      $tbl configure -align_right

      foreach load [get_cells -quiet -of $loads] {
        set region [get_clock_regions -quiet -of $load]
        regexp {^X([0-9]+)Y([0-9]+)$} $region - X Y
        $tbl incrcell $X $Y
      }

      foreach c [get_cells -quiet -of $driver] {
        set region [get_clock_regions -quiet -of $c]
        regexp {^X([0-9]+)Y([0-9]+)$} $region - X Y
      #   $tbl appendcell $X $Y " (D)"
        $tbl prependcell $X $Y "(D) "
      }

      set clockRoot [get_property -quiet CLOCK_ROOT $net]
      set userClockRoot [get_property -quiet USER_CLOCK_ROOT $net]

      if {$clockRoot != {}} {
        regexp {^X([0-9]+)Y([0-9]+)$} clockRoot - X Y
        $tbl prependcell $X $Y "(R) "
      }

      if {$userClockRoot != {}} {
        regexp {^X([0-9]+)Y([0-9]+)$} userClockRoot - X Y
        $tbl prependcell $X $Y "(U) "
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

