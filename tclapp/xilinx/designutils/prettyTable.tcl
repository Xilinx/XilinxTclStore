package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export prettyTable
}

########################################################################################
##
## Company:        Xilinx, Inc.
## Created by:     David Pefourque
##
## Version:        2016.01.27
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
  variable params [list indent 0 title {} tableFormat {classic} cellAlignment {left} maxNumRows -1 maxNumRowsToDisplay -1 columnsToDisplay {} ]
  variable version {2016.01.27}
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
                  [[create] [<title>]]     - Create a new prettyTable object (optional table title)
                  [create|create <title>]  - Create a new prettyTable object (optional table title)
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
  append res "[::tclapp::xilinx::designutils::prettyTable::list2csv $header $sepChar]\n"
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
  if {[info proc ::tclapp::xilinx::designutils::prettyTable::method:${method}] == "::tclapp::xilinx::designutils::prettyTable::method:${method}"} {
    eval ::tclapp::xilinx::designutils::prettyTable::method:${method} $self $args
  } else {
    # Search for a unique matching method among all the available methods
    set match [list]
    foreach procname [info proc ::tclapp::xilinx::designutils::prettyTable::method:*] {
      if {[string first $method [regsub {::tclapp::xilinx::designutils::prettyTable::method:} $procname {}]] == 0} {
        lappend match [regsub {::tclapp::xilinx::designutils::prettyTable::method:} $procname {}]
      }
    }
    switch [llength $match] {
      0 {
        error " -E- unknown method $method"
      }
      1 {
        set method $match
        eval ::tclapp::xilinx::designutils::prettyTable::method:${method} $self $args
      }
      default {
        error " -E- multiple methods match '$method': $match"
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
  foreach procname [lsort [info proc ::tclapp::xilinx::designutils::prettyTable::method:*]] {
    regsub {::tclapp::xilinx::designutils::prettyTable::method:} $procname {} method
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
# Usage: <prettyTableObject> title <string>
#------------------------------------------------------------------------
# Set the table title
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:title {self title} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils


  # Set the title of the table
  set ${self}::params(title) $title
  set title
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::method:header
#------------------------------------------------------------------------
# Usage: <prettyTableObject> header <list>
#------------------------------------------------------------------------
# Set the table header
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:header {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils


  # Set the header of the table
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
# ::tclapp::xilinx::designutils::prettyTable::method:numrows
#------------------------------------------------------------------------
# Usage: <prettyTableObject> numrows <list>
#------------------------------------------------------------------------
# Return the number of rows of the table
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:numrows {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils


  # Add a row to the table
  return [subst $${self}::numRows]
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
  set ${self}::params([lindex $args 0]) [lrange $args 1 end]
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
    # Add the current row number to the list of separators
    eval lappend ${self}::separators [subst $${self}::numRows]
  }
  return 0
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
              [-help|-h]

  Description: Configure some of the internal parameters.

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
              -format table|csv|tcl|list
              [-table classic|lean]
              [-delimiter <csv_delimiter>]
              [-file <filename>]
              [-append]
              [-return_var <tcl_var_name>]
              [-columns <list_of_columns_to_display>]
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
  if {[lsearch [list {table} {tcl} {csv} {list}] $format] == -1} {
    error " -E- invalid format '$format'. The valid formats are: table | csv | tcl | list"
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
        $self print -return_var res -columns $columnsToDisplay -format $tableFormat
      } else {
        set res [$self print -columns $columnsToDisplay -format $tableFormat]
      }
    }
    csv {
      if {$returnVar != {}} {
        ::tclapp::xilinx::designutils::prettyTable::exportToCSV $self -delimiter $csvDelimiter -return_var res -verbose $verbose
      } else {
        set res [::tclapp::xilinx::designutils::prettyTable::exportToCSV $self -delimiter $csvDelimiter -verbose $verbose]
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
