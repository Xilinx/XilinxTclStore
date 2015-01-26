
########################################################################################
## 02/03/2014 - Updated the namespace and definition of the command line arguments 
##              for the Tcl App Store
## 09/17/2013 - Minor update to the progressBar proc to hide it in GUI/Batch modes
## 09/10/2013 - Table object: added the 'sort' method to be able to sort the table content
## 09/09/2013 - Various enhancements
## 09/06/2013 - Added package for parsing Vivado report files
## 08/30/2013 - Added various common procs
##              Few enhancements
## 08/23/2013 - Initial release
########################################################################################

###########################################################################
##
## Procedures for the checklist for the UltraFast Methodology
##
###########################################################################

package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::ultrafast {
}

proc ::tclapp::xilinx::ultrafast::lshift {inputlist} {
  # Summary :
  # Argument Usage:
  # Return Value:

  upvar $inputlist argv
  set arg  [lindex $argv 0]
  set argv [lrange $argv 1 end]
  return $arg
}

# Alias to make lshift easy to find/use from other namespaces
# interp alias {} lshift {} ::tclapp::xilinx::ultrafast::lshift

proc ::tclapp::xilinx::ultrafast::progressBar {cur tot} {
  # Summary :
  # Argument Usage:
  # Return Value:

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
 
proc ::tclapp::xilinx::ultrafast::getArchitecture {} {
  # Summary :
  # Argument Usage:
  # Return Value:

  # Example of returned value: artix7 diabloevalarch elbertevalarch kintex7 kintexu kintexum olyevalarch v7evalarch virtex7 virtex9 virtexu virtexum zynq zynque ...
  #    7-Serie    : artix7 kintex7 virtex7 zynq
  #    UltraScale : kintexu kintexum virtexu virtexum
  #    Diablo (?) : virtex9 virtexum zynque
  return [get_property -quiet ARCHITECTURE [get_property -quiet PART [current_project]]]
}

proc ::tclapp::xilinx::ultrafast::generate_file_header {cmd} {
  # Summary :
  # Argument Usage:
  # Return Value:

  # Get the version of the script by using the --version command line argument
  if {[catch {set version [$cmd --version]} errorstring]} {
    set version {?}
  } else {
  }
  
  set header [format {######################################################
##
## %s (%s)
##} $cmd $version]

  foreach line [split [version] \n] {
    append header "\n## $line"
  }

  append header [format {
##
## Generated on %s
##
######################################################
} [clock format [clock seconds]] ]
  return $header
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

proc ::tclapp::xilinx::ultrafast::duration { int_time } {
  # Summary :
  # Argument Usage:
  # Return Value:

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


#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::lflatten
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Flatten a nested list
#------------------------------------------------------------------------
proc ::tclapp::xilinx::ultrafast::lflatten {inputlist} {
  # Summary :
  # Argument Usage:
  # Return Value:

  while { $inputlist != [set inputlist [join $inputlist]] } { }
  return $inputlist
}


###########################################################################
##
## Simple package to handle parsing of Vivado report files
##
###########################################################################

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::ultrafast::Parse { 
  set n 0 
} ]


#------------------------------------------------------------------------
# ::tclapp::xilinx::ultrafast::extract_columns
#------------------------------------------------------------------------
# Extract position of columns based on the column separator string
#  str:   string to be used to extract columns
#  match: column separator string
#------------------------------------------------------------------------
proc ::tclapp::xilinx::ultrafast::Parse::extract_columns { str match } {
  # Summary :
  # Argument Usage:
  # Return Value:

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

#------------------------------------------------------------------------
# ::tclapp::xilinx::ultrafast::extract_row
#------------------------------------------------------------------------
# Extract all the cells of a row (string) based on the position
# of the columns
#------------------------------------------------------------------------
proc ::tclapp::xilinx::ultrafast::Parse::extract_row {str columns} {
  # Summary :
  # Argument Usage:
  # Return Value:

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
# ::tclapp::xilinx::ultrafast::Parse::report_clock_interaction
#------------------------------------------------------------------------
# Extract the clock table from report_clock_interaction and return
# a Tcl list
#------------------------------------------------------------------------
proc ::tclapp::xilinx::ultrafast::Parse::report_clock_interaction {report} {
  # Summary :
  # Argument Usage:
  # Return Value:

  set columns [list]
  set table [list]
  set report [split $report \n]
  set SM {header}
  for {set index 0} {$index < [llength $report]} {incr index} {
    set line [lindex $report $index]
    switch $SM {
      header {
        if {[regexp {^\-+\s+\-+\s+\-+} $line]} {
#           set columns [::tclapp::xilinx::ultrafast::extract_columns $line { }]
#           set columns [::tclapp::xilinx::ultrafast::Parse::extract_columns [string trimright $line] { }]
          set columns [extract_columns [string trimright $line] { }]
#           puts "Columns: $columns"
#           set header1 [::tclapp::xilinx::ultrafast::Parse::extract_row [lindex $report [expr $index -2]] $columns]
#           set header2 [::tclapp::xilinx::ultrafast::Parse::extract_row [lindex $report [expr $index -1]] $columns]
          set header1 [extract_row [lindex $report [expr $index -2]] $columns]
          set header2 [extract_row [lindex $report [expr $index -1]] $columns]
          set row [list]
          foreach h1 $header1 h2 $header2 {
            lappend row [string trim [format {%s %s} [string trim [format {%s} $h1]] [string trim [format {%s} $h2]]] ]
          }
#           puts "header:$row"
          lappend table $row
          set SM {table}
        }
      }
      table {
        # Check for empty line or for line that match '<empty>'
        if {(![regexp {^\s*$} $line]) && (![regexp -nocase {^\s*No clocks found.\s*$} $line])} {
#           set row [::tclapp::xilinx::ultrafast::Parse::extract_row $line $columns]
          set row [extract_row $line $columns]
          lappend table $row
#           puts "row:$row"
        }
      }
      end {
      }
    }
  }
  return $table
}


###########################################################################
##
## Simple package to handle printing of tables
##
## %> set tbl [Table::Create {this is my title}]
## %> $tbl header [list "name" "#Pins" "case_value" "user_case_value"]
## %> $tbl addrow [list A/B/C/D/E/F 12 - -]
## %> $tbl addrow [list A/B/C/D/E/F 24 1 -]
## %> $tbl separator
## %> $tbl addrow [list A/B/C/D/E/F 48 0 1]
## %> $tbl indent 0
## %> $tbl print
## +-------------+-------+------------+-----------------+
## | name        | #Pins | case_value | user_case_value |
## +-------------+-------+------------+-----------------+
## | A/B/C/D/E/F | 12    | -          | -               |
## | A/B/C/D/E/F | 24    | 1          | -               |
## +-------------+-------+------------+-----------------+
## | A/B/C/D/E/F | 48    | 0          | 1               |
## +-------------+-------+------------+-----------------+
## %> $tbl indent 2
## %> $tbl print
##   +-------------+-------+------------+-----------------+
##   | name        | #Pins | case_value | user_case_value |
##   +-------------+-------+------------+-----------------+
##   | A/B/C/D/E/F | 12    | -          | -               |
##   | A/B/C/D/E/F | 24    | 1          | -               |
##   +-------------+-------+------------+-----------------+
##   | A/B/C/D/E/F | 48    | 0          | 1               |
##   +-------------+-------+------------+-----------------+
## %> $tbl sort {-index 1 -increasing} {-index 2 -dictionary}
## %> $tbl print
## %> $tbl destroy
##
###########################################################################

# namespace eval ::tclapp::xilinx::ultrafast::Table { set n 0 }

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::ultrafast::Table { 
  set n 0 
} ]

proc ::tclapp::xilinx::ultrafast::Table::Create { {title {}} } { #-- constructor
  # Summary :
  # Argument Usage:
  # Return Value:

  variable n
  set instance [namespace current]::[incr n]
  namespace eval $instance { variable tbl [list]; variable header [list]; variable indent 0; variable title {}; variable numrows 0 }
  interp alias {} $instance {} ::tclapp::xilinx::ultrafast::Table::do $instance
  # Set the title
  $instance title $title
  set instance
}

proc ::tclapp::xilinx::ultrafast::Table::do {self method args} { #-- Dispatcher with methods
  # Summary :
  # Argument Usage:
  # Return Value:

  upvar #0 ${self}::tbl tbl
  upvar #0 ${self}::header header
  upvar #0 ${self}::numrows numrows
  switch -- $method {
      header {
        set header [lindex $args 0]
        return 0
      }
      addrow {
        eval lappend tbl $args
        incr numrows
        return 0
      }
      separator {
        eval lappend tbl {%%SEPARATOR%%}
        return 0
      }
      title {
        set ${self}::title [lindex $args 0]
        return 0
      }
      indent {
        set ${self}::indent $args
        return 0
      }
      print {
        eval ::tclapp::xilinx::ultrafast::Table::print $self
      }
      length {
        return $numrows
      }
      sort {
        # Each argument is a list of: <lsort arguments>
        set command {}
        while {[llength $args]} {
          if {$command == {}} {
            set command "lsort [[namespace parent]::lshift args] \$tbl"
          } else {
            set command "lsort [[namespace parent]::lshift args] \[$command\]"
          }
        }
        if {[catch { set tbl [eval $command] } errorstring]} {
          puts " -E- $errorstring"
        } else {
        }
      }
      reset {
        set ${self}::tbl [list]
        set ${self}::header [list]
        set ${self}::indent 0
        set ${self}::title {}
        return 0
      }
      destroy {
        set ${self}::tbl [list]
        set ${self}::header [list]
        set ${self}::indent 0
        set ${self}::title {}
        namespace delete $self
        return 0
      }
      default {error "unknown method $method"}
  }
}

proc ::tclapp::xilinx::ultrafast::Table::print {self} {
  # Summary :
  # Argument Usage:
  # Return Value:

   upvar #0 ${self}::tbl table
   upvar #0 ${self}::header header
   upvar #0 ${self}::indent indent
   upvar #0 ${self}::title title
   set maxs {}
   foreach item $header {
       lappend maxs [string length $item]
   }
   set numCols [llength $header]
   foreach row $table {
       if {$row eq {%%SEPARATOR%%}} { continue }
       for {set j 0} {$j<$numCols} {incr j} {
            set item [lindex $row $j]
            set max [lindex $maxs $j]
            if {[string length $item]>$max} {
               lset maxs $j [string length $item]
           }
       }
   }
  set head " [string repeat " " [expr $indent * 4]]+"
  foreach max $maxs {append head -[string repeat - $max]-+}

  # Generate the title
  if {$title ne {}} {
    # The upper separator should something like +----...----+
    append res " [string repeat " " [expr $indent * 4]]+[string repeat - [expr [string length [string trim $head]] -2]]+\n"
    # Suports multi-lines title
    foreach line [split $title \n] {
      append res " [string repeat " " [expr $indent * 4]]| "
      append res [format "%-[expr [string length [string trim $head]] -4]s" $line]
      append res " |\n"
    }
  }

  # Generate the table header
  append res $head\n
  # Generate the table rows
  set first 1
  foreach row [concat [list $header] $table] {
      if {$row eq {%%SEPARATOR%%}} { 
        append res $head\n
        continue 
      }
      append res " [string repeat " " [expr $indent * 4]]|"
      foreach item $row max $maxs {append res [format " %-${max}s |" $item]}
      append res \n
      if {$first} {
        append res $head\n
        set first 0
      }
  }
  append res $head
  set res
}

