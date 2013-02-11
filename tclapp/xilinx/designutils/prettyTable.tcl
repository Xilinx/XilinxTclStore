package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export prettyTable
}

proc ::tclapp::xilinx::designutils::prettyTable { args } {
    # Summary : utility to easily create and print tables
    
    # Argument Usage:
    # args : sub-command. The supported sub-commands are: create | info | sizeof | destroyall
    
    # Return Value:
    # returns a new prettyTable object

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
  set n 0 
#   set params [list indent 0 maxNumRows 10000 maxNumRowsToDisplay 50 title {} ]
  set params [list indent 0 maxNumRows -1 maxNumRowsToDisplay -1 title {} ]
  set version {02-01-2013}
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
    -h -
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
                  [-h|-help]               - This help message
                  
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

  foreach child [lsort [namespace children]] {
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

  if {[info proc $procname] ne $procname} { return }
  # reports a proc's args and leading comments.
  # Multiple documentation lines are allowed.
  set res ""
  # This comment should not appear in the docstring
  foreach line [split [uplevel 1 [list info body $procname]] \n] {
      if {[string trim $line] eq ""} continue
      # Skip comments that have been added to support rdi::register_proc command
      if {[regexp -nocase -- {^\s*#\s*(Summary|Argument Usage|Return Value)\s*\:} $line]} continue
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

  upvar $inputlist argv
  set arg  [lindex $argv 0]
  set argv [lrange $argv 1 end]
  return $arg
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
# The result is returned as a single string
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::exportToTCL {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:

  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::params params
  upvar #0 ${self}::separators separators
  upvar #0 ${self}::numRows numRows
  set res {}
  append res [format {set tbl [::tclapp::xilinx::designutils::prettyTable]
$tbl configure -title {%s} -indent %s -limit %s -display_limit %s
$tbl header [list %s]} $params(title) $params(indent) $params(maxNumRows) $params(maxNumRowsToDisplay) $header]
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
  return $res
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::prettyTable::exportToCSV
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Dump the content of the prettyTable object as CSV format
# The result is returned as a single string
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::exportToCSV {self {sepChar ,}} {
  # Summary :
  # Argument Usage:
  # Return Value:

  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::params params
  upvar #0 ${self}::separators separators
  upvar #0 ${self}::numRows numRows
  set res {}
  append res "# title${sepChar}[::tclapp::xilinx::designutils::prettyTable::list2csv [list $params(title)] $sepChar]\n"
  append res "# header${sepChar}[::tclapp::xilinx::designutils::prettyTable::list2csv $header $sepChar]\n"
  append res "# indent${sepChar}[::tclapp::xilinx::designutils::prettyTable::list2csv $params(indent) $sepChar]\n"
  append res "# limit${sepChar}[::tclapp::xilinx::designutils::prettyTable::list2csv $params(maxNumRows) $sepChar]\n"
  append res "# display_limit${sepChar}[::tclapp::xilinx::designutils::prettyTable::list2csv $params(maxNumRowsToDisplay) $sepChar]\n"
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
  return $res
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

  # Reset object and empty all the data
  set ${self}::header [list]
  set ${self}::table [list]
  set ${self}::separators [list]
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

  # Destroy object
  set ${self}::header [list]
  set ${self}::table [list]
  set ${self}::separators [list]
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
proc ::tclapp::xilinx::designutils::prettyTable::method:print {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:

  # Print table. The output can be captured in a variable
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
  set append 0
  set returnVar {}
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
              [-from <start_row_number>]
              [-help|-h]
              
  Description: Return table content.
  
  Example:
     <prettyTableObject> print
     <prettyTableObject> print -return_var report
     <prettyTableObject> print -file output.rpt -append
} ]
    # HELP -->
    return {}
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
  set separator "${indentString}+"
  foreach max $maxs { append separator "-[string repeat - $max]-+" }
  # Generate the title
  if {$params(title) ne {}} {
    # The upper separator should something like +----...----+
    append res "${indentString}+[string repeat - [expr [string length $separator] - [string length $indentString] -2]]+\n"
    append res "${indentString}| "
    append res [format "%-[expr [string length $separator] - [string length $indentString] -4]s" $params(title)]
    append res " |"
  }
  # Generate the table header
  append res "\n${separator}\n"
  append res "${indentString}|"
  foreach item $header max $maxs {append res [format " %-${max}s |" $item]}
  append res "\n${separator}\n"
  # Generate the table rows
  set count 0
  foreach row $table {
      incr count
      if {($count > $maxNumRowsToDisplay) && ($maxNumRowsToDisplay != -1)} {
        # Did we reach the maximum of rows to be displayed?
        break
      }
      append res "${indentString}|"
      foreach item $row max $maxs {append res [format " %-${max}s |" $item]}
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
    append res $separator
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
# Usage: <prettyTableObject> [<COLUMN_HEADER>] [+<COLUMN_HEADER>] [-<COLUMN_HEADER>] 
#------------------------------------------------------------------------
# Sort the table based on the specified column header. The table can
# be sorted ascending or descending
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::prettyTable::method:sort {self args} {
  # Summary :
  # Argument Usage:
  # Return Value:

  # Sort the table based on one or more column headers
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::params params
  foreach elm $args {
    set direction {increasing}
    set column {}
    if {[regexp {^(\+)(.+)$} $elm -- - column]} {
      set direction {increasing}
    } elseif {[regexp {^(\-)(.+)$} $elm -- - column]} {
      set direction {decreasing}
    } elseif {[regexp {^(.+)$} $elm -- column]} {
      set direction {increasing}
    } else {
      continue
    }
    set index [lsearch $header $column]
    if {$index == -1} {
      puts " -E- unknown column header '$column'"
      continue
    }
    if {[catch { set table [lsort -$direction -dictionary -index $index $table] } errorstring]} {
      puts " -E- Sorting by column '$column': $errorstring"
    } else {
      # Since the rows are sorted, the separators don't mean anything anymore, so remove them
      set ${self}::separators [list]
      puts " -I- Sorting ($direction) by column '$column' completed"
    }
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

  # Configure object
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
              [-indent <indent_level>]
              [-limit <max_number_of_rows>]
              [-display_limit <max_number_of_rows_to_display>]
              [-remove_separators]
              [-help|-h]
              
  Description: Configure some of the internal parameters.
  
  Example:
     <prettyTableObject> configure -indent 2
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

  # Create table from CSV file
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
      -file -
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

  # Export table (stdout / CSV format / tcl script)
  upvar #0 ${self}::header header
  upvar #0 ${self}::table table
  upvar #0 ${self}::separators separators
  upvar #0 ${self}::params params
  upvar #0 ${self}::numRows numRows

  set error 0
  set help 0
  set filename {}
  set append 0
  set returnVar {}
  set format {table}
  set csvDelimiter {,}
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
              -format table|csv|tcl
              [-delimiter <csv_delimiter>] 
              [-file <filename>]
              [-append]
              [-return_var <tcl_var_name>]
              [-help|-h]
              
  Description: Export table content.
  
  Example:
     <prettyTableObject> export -format csv
     <prettyTableObject> export -format csv -return_var report
     <prettyTableObject> export -file output.rpt -append
} ]
    # HELP -->
    return {}
  }
  
  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }
  
  # No header has been defined
  if {[lsearch [list table tcl csv] $format] == -1} {
    error " -E- invalid format '$format'. The valid format are: table | csv | tcl"
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
#       set res [::tclapp::xilinx::designutils::prettyTable::method::print $self]
#       set res [$self print]
      if {$returnVar != {}} {
        $self print -return_var res
      } else {
        set res [$self print]
      }
    }
    csv {
      set res [::tclapp::xilinx::designutils::prettyTable::exportToCSV $self $csvDelimiter]
    }
    tcl {
      set res [::tclapp::xilinx::designutils::prettyTable::exportToTCL $self]
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
