########################################################################################
##
## Company:        Advanced Micro Devices, Inc
## Created by:     David Pefourque
##
## Version:        2023.05.05
## Description:    This package provides a simple profiler for Vivado commands
##
########################################################################################

########################################################################################
## 2023.05.05 - Updated for Tcl Store
## 2020.03.30 - Added support for -file/-append/-no_header to method 'summmary'
##            - Code improvements
## 2018.11.07 - Improved robustness
## 2018.10.26 - Added support for tracking scoping information
##            - Added -indent/-no_scope to method 'summary'
## 2018.10.19 - Added -limit to method 'summary'
## 2018.10.15 - Fixed empty "Top 10 Collections" when the detailed list of objects
##              is enabled
##            - Fixed objects ordering when the detailed list of objects is enabled
## 2018.10.01 - Added -time_more_than/-gain_more_than/-byte/-topnth to
##              method 'summary'
##            - Added -cmdline/-no_cmdline to method 'configure'
## 2018.09.11 - Fixed issue with the number of objects caped at 501 with Vivado 2018.3
## 2018.09.07 - Added -summary to method 'summary'
## 2018.09.05 - Added -hms/-format/-ignored_commands/-profiled_commands/-hide_ignored
##              to method 'summary'
##            - Added internal procs loadstate/savestate to load/save the profiler state
##            - Improved command line options handling
## 2018.04.03 - Fixed stack level for method 'time'
## 2018.03.24 - Improved the log file CSV format
## 2018.02.10 - Added the top 10 largest collections of objects in the log file
## 2018.01.29 - Added the number of returned objects in the "Top 50 Runtimes" summary
## 2017.11.21 - Modified output format for method 'summary' with -csv:
##              the detailed summary is now reported as CSV
## 2017.11.17 - Switch tables generation to prettyTable
##            - Added option -csv to method 'summary'
## 2016.07.29 - Added method 'configure'
##            - Added tuncation of long command lines inside log file
##              (improved performance and better support for very large XDC)
## 2014.07.03 - Fixed issue with clock formating that prevented the script from running
##              under Windows
## 2014.05.13 - Updated package requirement to Vivado 2014.1
## 2013.10.03 - Changed version format to 2013.10.03 to be compatible with 'package' command
##            - Added version number to namespace
## 09/16/2013 - Updated 'docstring' to support meta-comment 'Categories' for linter
## 03/29/2013 - Minor fix
## 03/26/2013 - Reformated the log file and added the top 50 worst runtimes
##            - Renamed subcommand 'exec' to 'time'
##            - Removed 'read_xdc' from the list of commands that contribute to the
##              total runtime
##            - Added subcommand 'version'
##            - Added subcommand 'configure'
##            - Added options -collection_display_limit & -src_info to subcommand 'start'
##            - Modified the subcommand 'time' to accept the same command line arguments
##              as the subcommand 'start'
## 03/21/2013 - Initial release
########################################################################################

# Profiler usage:
#    profiler add *    (-help for additional help)
#    profiler start    (-help for additional help)
#      <execute code>
#    profiler stop
#    profiler summary  (-help for additional help)
#
# OR
#
#    profiler add *    (-help for additional help)
#    profiler time { ... }

package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export profiler_tcl
    namespace export profiler_summary
    namespace export profiler
}

proc ::tclapp::xilinx::designutils::profiler { args } {
  # Summary : Tcl profiler (advanced)

  # Argument Usage:
  # args : sub-command. The supported sub-commands are: start | stop | summary | add | remove | reset | status
  # [-sc_help]: Sub-command help. To be specified after the sub-command

  # Return Value:
  # returns the status or an error code

  return [uplevel [concat ::tclapp::xilinx::designutils::profiler::profiler $args]]
}

proc ::tclapp::xilinx::designutils::profiler_tcl { script } {
  # Summary : Profile Tcl script (recommended)

  # Argument Usage:
  # script : Tcl script to profile

  # Return Value:
  # returns the status or an error code

  if {[llength $::tclapp::xilinx::designutils::profiler::cmdlist]==0} {
    # Silence "Common 17-210"
    set_msg_config -id {[Common 17-210]} -suppress
    # Add Vivado commands
    ::tclapp::xilinx::designutils::profiler::method:add *
    # Un-silence "Common 17-210"
    reset_msg_config -id {[Common 17-210]} -suppress
  } else {
  }
  ::tclapp::xilinx::designutils::profiler::profiler start
  uplevel $script
  ::tclapp::xilinx::designutils::profiler::profiler stop
  ::tclapp::xilinx::designutils::profiler::profiler summary
  return -code ok
}

proc ::tclapp::xilinx::designutils::profiler_summary { args } {
  # Summary : Generate the profiler summary from profiler_tcl

  # Argument Usage:
  # [-file <arg>]: Output log file name
  # [-csv]: Output in CSV format

  # Return Value:
  # returns the status or an error code

  if {([llength $::tclapp::xilinx::designutils::profiler::tmstart] == 0) || ([llength $::tclapp::xilinx::designutils::profiler::tmend] == 0)} {
    error " -E- xilinx::designutils::profiler_tcl has not been run. No summary available."
  }

  return [::tclapp::xilinx::designutils::profiler::method:summary {*}$args]
}


###########################################################################
##
## Package for profiling Tcl code
##
###########################################################################

#------------------------------------------------------------------------
# Namespace for the package
#------------------------------------------------------------------------

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils::profiler {
#   if {1 || ![info exists ::tclapp::xilinx::designutils::profiler::params]} {}
  if {1} {
    # Only reset the variables if they have not been set yet
    variable version {2023.05.05}
    variable cmdlist [list]
    variable tmstart [list]
    variable tmend [list]
    variable params
    variable db [list]
    catch {unset params}
    array set params [list mode {stopped} topNth 50 formatDelay {default} formatMemory {default} profileMemory 1 reportMemory 1 expandObjects 0 trackCmdline 1 collectionResultDisplayLimit -1 ]
    array set params [list commands {}]
    variable level 0
    variable levels [list]
    # Default aliases
    interp alias {} ::tclapp::xilinx::designutils::profiler::mem {} ::tclapp::xilinx::designutils::profiler::mem2
    interp alias {} ::tclapp::xilinx::designutils::profiler::leave {} ::tclapp::xilinx::designutils::profiler::leave5
  } else {
    # Use method 'reset' to reset the parameters
    variable version
    variable cmdlist
    variable tmstart
    variable tmend
    variable params
    variable db
    variable level
    variable levels
  }
} ]

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::profiler
#------------------------------------------------------------------------
# Main function
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::profiler { args } {
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
    dump {
      return [eval [concat ::tclapp::xilinx::designutils::profiler::dump] ]
    }
    ? -
    -h -
    -help {
      incr show_help
    }
    default {
      return [eval [concat ::tclapp::xilinx::designutils::profiler::do ${method} $args] ]
    }
  }

  if {$show_help} {
    # <-- HELP
    puts ""
    ::tclapp::xilinx::designutils::profiler::method:?
    puts [format {
   Description: Utility to profile Vivado commands

   Example 1:
      xilinx::designutils::profiler add *
      xilinx::designutils::profiler start -incr
          <execute some Tcl code with Vivado commands>
      xilinx::designutils::profiler stop
      xilinx::designutils::profiler summary
      xilinx::designutils::profiler reset

   Example 2:
      xilinx::designutils::profiler add *
      xilinx::designutils::profiler time { <execute some Tcl code with Vivado commands> }
      xilinx::designutils::profiler summary
      xilinx::designutils::profiler reset

    } ]
    # HELP -->
    return
  }

}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::lshift
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Stack function
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::lshift {inputlist} {
  # Summary :
  # Argument Usage:
  # Return Value:

  upvar $inputlist argv
  set arg  [lindex $argv 0]
  set argv [lrange $argv 1 end]
  return $arg
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::lflatten
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Flatten a nested list
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::lflatten {inputlist} {
  # Summary :
  # Argument Usage:
  # Return Value:

  while { $inputlist != [set inputlist [join $inputlist]] } { }
  return $inputlist
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::lremove
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Remove element from a list
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::lremove {_inputlist element} {
  # Summary :
  # Argument Usage:
  # Return Value:

  upvar 1 $_inputlist inputlist
  set pos [lsearch -exact $inputlist $element]
  set inputlist [lreplace $inputlist $pos $pos]
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::duration
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Convert a milisecond time into a HMS format
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::duration { int_time } {
  # Summary :
  # Argument Usage:
  # Return Value:

  if {$int_time < 1000} {
    # If less than 1000ms, return "<1s"
    return {<1s}
  }
  # Convert miliseconds into seconds
  set int_time [expr int($int_time / 1000)]
  set timeList [list]
  if {$int_time == 0} { return "0sec" }
  foreach div {86400 3600 60 1} mod {0 24 60 60} name {day hr min sec} {
    set n [expr {$int_time / $div}]
    if {$mod > 0} {set n [expr {$n % $mod}]}
    if {$n > 1} {
      lappend timeList "${n} ${name}s"
    } elseif {$n == 1} {
      lappend timeList "${n} $name"
    }
  }
  return [join $timeList { }]
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::loadstate
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Load profiler state
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::loadstate { filename } {
  # Summary :
  # Argument Usage:
  # Return Value:

  if {[regexp {.gz$} $filename]} {
    # gzip-ed file
    set content {}
    set FH [open "| zcat $filename" {r}]
    while {![eof $FH]} {
      gets $FH line
      append content $line
      if {[info complete $content]} {
        if {[catch {eval $content} errorstring]} {
          puts " -E- $errorstring"
        }
        set content {}
      }
    }
    close $FH
  } else {
    if {[catch {source $filename} errorstring]} {
      puts " -E- $errorstring"
    }
  }
  puts " -I- finished loading file [file normalize $filename]"
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::savestate
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Save profiler state
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::savestate { filename {expanded 0} } {
  # Summary :
  # Argument Usage:
  # Return Value:

  variable db
  variable cmdlist
  variable tmend
  variable tmstart
  variable params
  set FH [open $filename {w}]
  puts $FH "# To reload the saved state:"
  puts $FH "#   tb::profiler::loadstate <filename>"
  puts $FH [format {array set ::tclapp::xilinx::designutils::profiler::params {%s}} [array get params] ]
  # Write out the $DB variable (1 entry per line)
  puts $FH "set ::tclapp::xilinx::designutils::profiler::db \[list\]"
  foreach i $db {
    lassign $i memory clk enter level levels cmdline code result src_info
    if {$expanded} {
      # Expanded form, write the command name with its arguments
      puts $FH [format {lappend ::tclapp::xilinx::designutils::profiler::db [list {%s} {%s} {%s} {%s} {%s} {%s} {%s} {%s} {%s} ]} $memory $clk $enter $level $levels $cmdline $code $result $src_info]
    } else {
      # Only write the command name, not the arguments
      puts $FH [format {lappend ::tclapp::xilinx::designutils::profiler::db [list {%s} {%s} {%s} {%s} {%s} {%s} {%s} {%s} {%s} ]} $memory $clk $enter $level $levels [lindex $cmdline 0] $code $result $src_info]
    }
  }

  puts $FH [format {set ::tclapp::xilinx::designutils::profiler::cmdlist {%s}} $cmdlist]
  puts $FH [format {set ::tclapp::xilinx::designutils::profiler::tmstart {%s}} $tmstart]
  puts $FH [format {set ::tclapp::xilinx::designutils::profiler::tmend {%s}} $tmend]
  close $FH
  puts " -I- generated file [file normalize $filename]"
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::formatDelay
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Convert a milisecond time into a different format (HMS, seconds, ms)
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::formatDelay { int_time } {
  # Summary :
  # Argument Usage:
  # Return Value:

  variable params
  switch $params(formatDelay) {
    hms {
      # hours/minutes/seconds
      return [duration [expr $int_time / 1000.0]]
    }
    ms {
      # miliseconds
      return [format {%.0fms} [expr $int_time / 1000.0]]
    }
    s -
    sec {
      # seconds
      return [format {%.0fs} [expr $int_time / 1000000.0]]
    }
    default {
      return [format {%.3fms} [expr $int_time / 1000.0]]
    }
  }
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::formatMemory
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Convert a memory size in byte into a human readable format
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::formatMemory { int_byte {mode 0}} {
  # Summary :
  # Argument Usage:
  # Return Value:

  # $mode: define the formating for negative numbers. For example if int_byte=-16:
  #    0: -16
  #    1: (16)
  variable params
  switch $params(formatMemory) {
    byte {
      # Return value as byte - no transformation
      return $int_byte
    }
    default {
      # Return formatted string. For example:
      #   formatMemory 123456
      #   => 120.6KB
      set sign 1
      if {$int_byte < 0} {
        set sign -1
        set int_byte [expr -$int_byte]
      }
      set len [string length $int_byte]
      if {$int_byte < 1024} {
        if {$sign == -1} {
          # Negative number
          if {$mode} {
            return [format "(%s)" $int_byte ]
          } else {
            return [format "%s" [expr $sign * $int_byte] ]
          }
        } else {
          return [format "%s" $int_byte ]
        }
      } else {
        set unit [expr {($len - 1) / 3}]
        if {$sign == -1} {
          # Negative number
          if {$mode} {
            return [format "(%.1f%s)" [expr {$int_byte / pow(1024,$unit)}] [lindex \
                        [list B KB MB GB TB PB EB ZB YB] $unit] ]
          } else {
            return [format "%.1f%s" [expr $sign * {$int_byte / pow(1024,$unit)}] [lindex \
                        [list B KB MB GB TB PB EB ZB YB] $unit] ]
          }
        } else {
          return [format "%.1f%s" [expr {$int_byte / pow(1024,$unit)}] [lindex \
                      [list B KB MB GB TB PB EB ZB YB] $unit] ]
        }
      }
    }
  }
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::docstring
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Return the embedded help of a proc
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::docstring {procname} {
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
      if {[regexp -nocase -- {^\s*#\s*(Summary|Argument Usage|Return Value|Categories)\s*\:} $line]} continue
      if {![regexp {^\s*#(.+)} $line -> line]} break
      lappend res [string trim $line]
  }
  join $res \n
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::do
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Dispatcher with methods
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::do {args} {
  # Summary :
  # Argument Usage:
  # Return Value:

  if {[llength $args] == 0} {
#     error " -E- wrong number of parameters: profiler <sub-command> \[<arguments>\]"
    set method {?}
  } else {
    # The first argument is the method
    set method [lshift args]
  }
  if {[info proc ::tclapp::xilinx::designutils::profiler::method:${method}] == "::tclapp::xilinx::designutils::profiler::method:${method}"} {
    eval ::tclapp::xilinx::designutils::profiler::method:${method} $args
  } else {
    # Search for a unique matching method among all the available methods
    set match [list]
    foreach procname [info proc ::tclapp::xilinx::designutils::profiler::method:*] {
      if {[string first $method [regsub {::tclapp::xilinx::designutils::profiler::method:} $procname {}]] == 0} {
        lappend match [regsub {::tclapp::xilinx::designutils::profiler::method:} $procname {}]
      }
    }
    switch [llength $match] {
      0 {
        error " -E- unknown sub-command $method"
      }
      1 {
        set method $match
        return [eval ::tclapp::xilinx::designutils::profiler::method:${method} $args]
      }
      default {
        error " -E- multiple sub-commands match '$method': $match"
      }
    }
  }
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::method:?
#------------------------------------------------------------------------
# Usage: profiler ?
#------------------------------------------------------------------------
# Return all the available methods. The methods with no embedded help
# are not displayed (i.e hidden)
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::method:? {args} {
  # Summary :
  # Argument Usage:
  # Return Value:

  # This help message
  puts "   Usage: profiler <sub-command> \[<arguments>\]"
  puts "   Where <sub-command> is:"
  foreach procname [lsort [info proc ::tclapp::xilinx::designutils::profiler::method:*]] {
    regsub {::tclapp::xilinx::designutils::profiler::method:} $procname {} method
    set help [::tclapp::xilinx::designutils::profiler::docstring $procname]
    if {$help ne ""} {
      puts "         [format {%-12s%s- %s} $method \t $help]"
    }
  }
  puts ""
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::mem
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Returned memory usage
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::mem2 {} {
  # Summary :
  # Argument Usage:
  # Return Value:

  return 0
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::enter
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Called before a profiled command is executed
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::enter {cmd op} {
  # Summary :
  # Argument Usage:
  # Return Value:

  variable db
  variable level
  variable levels
  lappend levels [lindex $cmd 0]
  lappend db [list [mem] [clock microseconds] 1 [incr level] $levels $cmd]
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::leave1
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Called after a profiled command is executed
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::leave1 {cmd code result op} {
  # Summary :
  # Argument Usage:
  # Return Value:

  variable db
  variable params
  variable level
  variable levels
  set mem [mem]
  set time [clock microseconds]
  if [catch {
    if {$params(expandObjects)} {
      # Save the list of return objects
      lappend db [list $mem $time 0 $level $levels $cmd $code $result]
    } else {
      # Only save the number of return objects
      lappend db [list $mem $time 0 $level $levels $cmd $code [list [format {%d objects} [llength $result]]] ]
    }
  }] {
    # In case of unlikely failure ... keept it simple
    lappend db [list $mem $time 0 $level $levels [lindex $cmd 0] $code [list [format {n/a objects} ]] ]
  }
  incr level -1
  set levels [lreplace $levels end end]
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::leave2
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Verbose version of ::tclapp::xilinx::designutils::profiler::leave1
# Save the source information inside the database
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::leave2 {cmd code result op} {
  # Summary :
  # Argument Usage:
  # Return Value:

  variable db
  variable params
  variable level
  variable levels
  set mem [mem]
  set time [clock microseconds]
  if [catch {
    # Create temp variable in case [current_design] does not exist
    set src_info {}
    catch { set src_info [get_property -quiet src_info [current_design -quiet]] }
    if {$params(expandObjects)} {
      # Save the list of return objects
      lappend db [list $mem $time 0 $level $levels $cmd $code $result $src_info ]
    } else {
      # Only save the number of return objects
      lappend db [list $mem $time 0 $level $levels $cmd $code [list [format {%d objects} [llength $result]]] $src_info]
    }
  }] {
    # In case of unlikely failure ... keept it simple
    lappend db [list $mem $time 0 $level $levels [lindex $cmd 0] $code [list [format {n/a objects} ]] {n/a} ]
  }
  incr level -1
  set levels [lreplace $levels end end]
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::leave3
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Called after a profiled command is executed
# Version of ::tclapp::xilinx::designutils::profiler::leave1 that only save the command name
# without the command line options
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::leave3 {cmd code result op} {
  # Summary :
  # Argument Usage:
  # Return Value:

  variable db
  variable params
  variable level
  variable levels
  set mem [mem]
  set time [clock microseconds]
  if [catch {
    if {$params(expandObjects)} {
      # Save the list of return objects
      lappend db [list $mem $time 0 $level $levels [lindex $cmd 0] $code $result]
    } else {
      # Only save the number of return objects
      lappend db [list $mem $time 0 $level $levels [lindex $cmd 0] $code [list [format {%d objects} [llength $result]]] ]
    }
  }] {
    # In case of unlikely failure ... keept it simple
    lappend db [list $mem $time 0 $level $levels [lindex $cmd 0] $code [list [format {n/a objects} ]] ]
  }
  incr level -1
  set levels [lreplace $levels end end]
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::leave4
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Called after a profiled command is executed
# Version of ::tclapp::xilinx::designutils::profiler::leave4 that only save the command name
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::leave4 {cmd code result op} {
  # Summary :
  # Argument Usage:
  # Return Value:

  variable db
  variable params
  variable level
  variable levels
  set mem [mem]
  set time [clock microseconds]
  if [catch {
    # Create temp variable in case [current_design] does not exist
    set src_info {}
    catch { set src_info [get_property -quiet src_info [current_design -quiet]] }
    if {$params(expandObjects)} {
      # Save the list of return objects
      lappend db [list $mem $time 0 $level $levels [lindex $cmd 0] $code $result $src_info ]
    } else {
      # Only save the number of return objects
      lappend db [list $mem $time 0 $level $levels [lindex $cmd 0] [list [format {%d objects} [llength $result]]] $src_info]
    }
  }] {
    # In case of unlikely failure ... keept it simple
    lappend db [list $mem $time 0 $level $levels [lindex $cmd 0] $code [list [format {n/a objects} ]] {n/a} ]
  }
  incr level -1
  set levels [lreplace $levels end end]
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::leave5
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Dummy proc
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::leave5 {args} {
  # Summary :
  # Argument Usage:
  # Return Value:

  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::trace_off
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Remove all 'trace' commands
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::trace_off {args} {
  # Summary :
  # Argument Usage:
  # Return Value:

  variable cmdlist
  if {[set L [lflatten $args]] == {}} {
    # If no list is provided as argument, use $cmdlist
    set L $cmdlist
  }
  foreach cmd $L {
    catch { trace remove execution $cmd enter ::tclapp::xilinx::designutils::profiler::enter }
    catch { trace remove execution $cmd leave ::tclapp::xilinx::designutils::profiler::leave }
  }
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::trace_on
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Add all 'trace' commands
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::trace_on {args} {
  # Summary :
  # Argument Usage:
  # Return Value:

  variable cmdlist
  if {[set L [lflatten $args]] == {}} {
    # If no list is provided as argument, use $cmdlist
    set L $cmdlist
  }
  # For safety, tries to remove any existing 'trace' commands
  ::tclapp::xilinx::designutils::profiler::trace_off $L
  # Now adds 'trace' commands
  foreach cmd $L {
    catch { trace add execution $cmd enter ::tclapp::xilinx::designutils::profiler::enter }
    catch { trace add execution $cmd leave ::tclapp::xilinx::designutils::profiler::leave }
  }
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::dump
#------------------------------------------------------------------------
# Usage: profiler dump
#------------------------------------------------------------------------
# Dump profiler status
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::dump {args} {
  # Summary :
  # Argument Usage:
  # Return Value:

  # Dump 'trace' information
  ::tclapp::xilinx::designutils::profiler::trace_info
  # Dump non-array variables
  foreach var [lsort [info var ::tclapp::xilinx::designutils::profiler::*]] {
    if {![info exists $var]} { continue }
    if {![array exists $var]} {
      puts "   $var: [subst $$var]"
    }
  }
  # Dump array variables
  foreach var [lsort [info var ::tclapp::xilinx::designutils::profiler::*]] {
    if {![info exists $var]} { continue }
    if {[array exists $var]} {
      parray $var
    }
  }
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::trace_info
#------------------------------------------------------------------------
# **INTERNAL**
#------------------------------------------------------------------------
# Dump the 'trace' information on each command
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::trace_info {args} {
  # Summary :
  # Argument Usage:
  # Return Value:

  variable cmdlist
  if {[set L [lflatten $args]] == {}} {
    # If no list is provided as argument, use $cmdlist
    set L $cmdlist
  }
  foreach cmd $L {
    if {[catch { puts "   $cmd:[trace info execution $cmd]" } errorstring]} {
       puts "   $cmd: <ERROR: $errorstring>"
    }
  }
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::method:version
#------------------------------------------------------------------------
# Usage: profiler version
#------------------------------------------------------------------------
# Return the version of the profiler
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::method:version {args} {
  # Summary :
  # Argument Usage:
  # Return Value:

  # Version of the profiler
  variable version
#   puts " -I- Profiler version $version"
  return -code ok "Profiler version $version"
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::method:add
#------------------------------------------------------------------------
# Usage: profiler add [<options>]
#------------------------------------------------------------------------
# Add Vivado command(s) to the profiler
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::method:add {args} {
  # Summary :
  # Argument Usage:
  # Return Value:

  # Add Vivado command(s) to the profiler (-help)
  variable cmdlist
  variable params
  if {$params(mode) == {started}} {
    error " -E- cannot add command(s) when the profiler is running. Use 'profiler stop' to stop the profiler"
  }
  if {[llength $args] == 0} {
    error " -E- no argument provided"
  }

  set error 0
  set commands [list]
  set force 0
  set tmp_args [list]
  set help 0
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-force$} -
      {^-f(o(r(ce?)?)?)?$} {
        set force 1
      }
      {^-sc_help$} -
      {^-sc(_(h(e(lp?)?)?)?)?$} -
      {^-h(e(lp?)?)?$} -
      {^--h(e(lp?)?)?$} {
        set help 1
      }
      default {
        if {[string match "-*" $name]} {
          puts " -E- option '$name' is not a valid option."
          incr error
        } else {
          lappend tmp_args $name
        }
      }
    }
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  if {$help} {
    puts [format {
  Usage: xilinx::designutils::profiler add
              <pattern_of_commands>
              [<pattern_of_commands>]
              [-f|-force]
              [-help|-h]

  Description: Add commands to the profiler

  Example:
     xilinx::designutils::profiler add *
     xilinx::designutils::profiler add get_*
     xilinx::designutils::profiler add -force *
} ]
    # HELP -->
    return {}
  }

  # Restore 'args'
  set args $tmp_args

  foreach pattern [::tclapp::xilinx::designutils::profiler::lflatten $args] {
    if {[string first {*} $pattern] != -1} {
      # If the pattern contains an asterix '*' then the next 'foreach' loop
      # should not generate some of the warning messages since the user
      # just provided a pattern
      set verbose 0
    } else {
      # A specific command name has been provided, so the code below has to
      # be a little more verbose
      set verbose 1
    }
    foreach cmd [lsort [uplevel #0 [list info commands $pattern]]] {
      if {$force} {
        # If -force has been used, then trace any command, no question asked!
        lappend commands $cmd
        continue
      }
      # Otherwise, only trace Vivado commands
      if {[catch "set tmp \[help $cmd\]" errorstring]} {
        continue
      }
      if {[regexp -nocase -- {Tcl Built-In Commands} $tmp]} {
        if {$verbose} { puts " -W- the Tcl command '$cmd' cannot be profiled. Skipped" }
        continue
      }
#       if {[regexp -nocase -- {^(help|source|add|undo|redo|rename_ref|start_gui|stop_gui|show_objects|show_schematic|startgroup|end|endgroup)$} $cmd]} { }
#       if {[regexp -nocase -- {^(help|source|read_checkpoint|open_run|add|undo|redo|rename_ref|start_gui|stop_gui|show_objects|show_schematic|startgroup|end|endgroup)$} $cmd]} { }
      if {[regexp -nocase -- {^(help|source|add|undo|redo|rename_ref|start_gui|stop_gui|show_objects|show_schematic|startgroup|end|endgroup)$} $cmd]} {
        if {$verbose} { puts " -W- the Vivado command '$cmd' cannot be profiled. Skipped" }
        continue
      }
      lappend commands $cmd
    }
  }
  if {[llength $commands] == 0} {
    error " -E- no Vivado command matched '$args'"
  }
  puts " -I- [llength $commands] command(s) added to the profiler"
  puts " -I- Command(s): $commands"
  set cmdlist [concat $cmdlist $commands]
  set cmdlist [lsort -unique $cmdlist]
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::method:remove
#------------------------------------------------------------------------
# Usage: profiler remove <list>
#------------------------------------------------------------------------
# Remove Vivado command(s) from the profiler
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::method:remove {args} {
  # Summary :
  # Argument Usage:
  # Return Value:

  # Remove Vivado command(s) from the profiler
  variable cmdlist
  variable params
  if {$params(mode) == {started}} {
    error " -E- cannot remove command(s) when the profiler is running. Use 'profiler stop' to stop the profiler"
  }
  if {[llength $args] == 0} {
    error " -E- no argument provided"
  }
  set commands [list]
  foreach pattern [::tclapp::xilinx::designutils::profiler::lflatten $args] {
    foreach cmd [lsort [uplevel #0 [list info commands $pattern]]] {
      lappend commands $cmd
    }
  }
  set count 0
  set removed [list]
  foreach cmd $commands {
    if {[lsearch $cmdlist $cmd] != -1} {
      incr count
    }
    ::tclapp::xilinx::designutils::profiler::lremove cmdlist $cmd
    lappend removed $cmd
  }
  set cmdlist [lsort -unique $cmdlist]
  puts " -I- $count command(s) have been removed"
  puts " -I- Removed command(s): [lsort -unique $removed]"
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::method:reset
#------------------------------------------------------------------------
# Usage: profiler reset
#------------------------------------------------------------------------
# Reset the profiler
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::method:reset {args} {
  # Summary :
  # Argument Usage:
  # Return Value:

  # Reset the profiler
  variable cmdlist
  variable tmstart
  variable tmend
  variable params
  variable db
  variable level
  variable levels
  if {$params(mode) == {started}} {
    error " -E- cannot reset the profiler when running. Use 'profiler stop' to stop the profiler"
  }
#   set cmdlist [list]
  set tmstart [list]
  set tmend [list]
  set db [list]
#   set params(collectionResultDisplayLimit) -1
  array set params [list topNth 50 formatDelay {default} formatMemory {default} profileMemory 1 reportMemory 1 collectionResultDisplayLimit -1 ]
#   array set params [list mode {stopped} formatDelay {default} expandObjects 0 trackCmdline 1 collectionResultDisplayLimit -1 ]
  set level 0
  set levels [list]
  puts " -I- profiler reset"
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::method:status
#------------------------------------------------------------------------
# Usage: profiler status
#------------------------------------------------------------------------
# Return the status of the profiler
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::method:status {args} {
  # Summary :
  # Argument Usage:
  # Return Value:

  # Status of the profiler
  variable cmdlist
  variable params
  if {$params(mode) == {started}} {
    puts " -I- the profiler is started"
  } else {
    puts " -I- the profiler is stopped"
  }
  puts " -I- [llength $cmdlist] command(s) are traced:"
  puts " -I- Command(s): $cmdlist"
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::method:start
#------------------------------------------------------------------------
# Usage: profiler start [<options>]
#------------------------------------------------------------------------
# Start the profiler:
#   - adds the 'trace' commands
#   - starts the timer
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::method:start {args} {
  # Summary :
  # Argument Usage:
  # Return Value:

  # Start the profiler (-help)
  variable cmdlist
  variable tmstart
  variable tmend
  variable params
  if {$params(mode) == {started}} {
    error " -E- the profiler is already running. Use 'profiler stop' to stop the profiler"
  }

  set error 0
  set incremental 0
  set src_info 0
  set profile_memory 0
  set collection_display_limit $params(collectionResultDisplayLimit)
  set help 0
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-incr$} -
      {^-in(cr?)?$} {
        set incremental 1
      }
      {^-src_info$} -
      {^-sr(c(_(i(n(fo?)?)?)?)?)?$} {
        set src_info 1
      }
      {^-limit$} -
      {^-li(m(it?)?)?$} -
      {^-collection_display_limit$} -
      {^-co(l(l(e(c(t(i(o(n(_(d(i(s(p(l(a(y(_(l(i(m(it?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?$} {
        set collection_display_limit [lshift args]
      }
      {^-sc_help$} -
      {^-sc(_(h(e(lp?)?)?)?)?$} -
      {^-h(e(lp?)?)?$} -
      {^--h(e(lp?)?)?$} {
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

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  if {$help} {
    puts [format {
  Usage: xilinx::designutils::profiler start
              [-incr]
              [-src_info]
              [-collection_display_limit|-limit <num>]
              [-help|-h]

  Description: Start the profiler

    Use -src_info to track the src_info information

  Example:
     xilinx::designutils::profiler start
     xilinx::designutils::profiler start -incr -src_info -collection_display_limit 500
} ]
    # HELP -->
    return {}
  }

  if {[llength $cmdlist] == 0} {
    error " -E- no command has been added to the profiler. Use 'profiler add' to add Vivado commands"
  }

  if {!$incremental} {
    # Reset the profiler
    ::tclapp::xilinx::designutils::profiler::method:reset
  }
  # Used the -src_info to show detailed information on each XDC constraint
  if {$src_info} {
    if {[lsearch $cmdlist get_property] != -1} {
      puts " -W- Removing 'get_property' from the list of commands to be traced (uncompatible with -src_info)"
      ::tclapp::xilinx::designutils::profiler::lremove cmdlist get_property
    }
    if {[lsearch $cmdlist current_design] != -1} {
      puts " -W- Removing 'current_design' from the list of commands to be traced (uncompatible with -src_info)"
      ::tclapp::xilinx::designutils::profiler::lremove cmdlist current_design
    }
    if {$params(trackCmdline)} {
      interp alias {} ::tclapp::xilinx::designutils::profiler::leave {} ::tclapp::xilinx::designutils::profiler::leave2
    } else {
      interp alias {} ::tclapp::xilinx::designutils::profiler::leave {} ::tclapp::xilinx::designutils::profiler::leave4
    }
  } else {
    if {$params(trackCmdline)} {
      interp alias {} ::tclapp::xilinx::designutils::profiler::leave {} ::tclapp::xilinx::designutils::profiler::leave1
    } else {
      interp alias {} ::tclapp::xilinx::designutils::profiler::leave {} ::tclapp::xilinx::designutils::profiler::leave3
    }
  }
  # Profiling memory - not supported
  interp alias {} ::tclapp::xilinx::designutils::profiler::mem {} ::tclapp::xilinx::designutils::profiler::mem2
  set params(profileMemory) 0
  # Set the parameter tcl.collectionResultDisplayLimit if necessary
  catch {
    # Catching if the profiler is run outside of Vivado
    if {$collection_display_limit != [get_param tcl.collectionResultDisplayLimit]} {
      # Save the current parameter value so that it can be restored
      # Catch the following code as 'get_param' only works if a project is already opened
      catch {
        puts " -I- setting the parameter 'tcl.collectionResultDisplayLimit' to '$collection_display_limit'"
        set params(collectionResultDisplayLimit:ORG) [get_param tcl.collectionResultDisplayLimit]
        set_param tcl.collectionResultDisplayLimit $collection_display_limit
      }
    }
  }
  # Add 'trace' on the commands
  ::tclapp::xilinx::designutils::profiler::trace_on
  # Start the timer
  lappend tmstart [clock microseconds]
  set params(mode) {started}
  if {!$incremental} {
    puts " -I- profiler started on [clock format [expr [lindex $tmstart end] / 1000000]]"
  } else {
    puts " -I- profiler started in incremental mode on [clock format [expr [lindex $tmstart end] / 1000000]]"
  }
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::method:stop
#------------------------------------------------------------------------
# Usage: profiler stop
#------------------------------------------------------------------------
# Stop the profiler
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::method:stop {args} {
  # Summary :
  # Argument Usage:
  # Return Value:

  # Stop the profiler
  variable tmend
  variable params
  if {$params(mode) == {stopped}} {
    error " -E- the profiler is not running. Use 'profiler start' to start the profiler"
  }
  lappend tmend [clock microseconds]
  set params(mode) {stopped}
  # Remove 'trace' from the commands
  ::tclapp::xilinx::designutils::profiler::trace_off
  # Restoring the parameter tcl.collectionResultDisplayLimit
  if {[info exists params(collectionResultDisplayLimit:ORG)]} {
    # Catch the following code as 'get_param' only works if a project is already opened
    catch {
      puts " -I- restoring the parameter 'tcl.collectionResultDisplayLimit' to '$params(collectionResultDisplayLimit:ORG)'"
      set_param tcl.collectionResultDisplayLimit $params(collectionResultDisplayLimit:ORG)
      unset params(collectionResultDisplayLimit:ORG)
    }
  }
  # Default aliases
  interp alias {} ::tclapp::xilinx::designutils::profiler::mem {} ::tclapp::xilinx::designutils::profiler::mem2
  interp alias {} ::tclapp::xilinx::designutils::profiler::leave {} ::tclapp::xilinx::designutils::profiler::leave5
  puts " -I- profiler stopped on [clock format [expr [lindex $tmend end] / 1000000]]"
  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::method:summary
#------------------------------------------------------------------------
# Usage: profiler summary [<options>]
#------------------------------------------------------------------------
# Print the profiler summary
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::method:summary {args} {
  # Summary :
  # Argument Usage:
  # Return Value:

  # Return the profiler summary (-help)
  variable cmdlist
  variable tmstart
  variable tmend
  variable params
  variable db
  variable version
  if {$params(mode) == {started}} {
    error " -E- the profiler is still running. Use 'profiler stop' to stop the profiler"
  }
  if {([llength $tmstart] == 0) || ([llength $tmend] == 0)} {
    error " -E- the profiler has not been run. Use 'profiler start' to start the profiler"
  }

  set error 0
  set return_string 0
  set logfile {}
  set filemode {w}
  set printHeader 1
  # Only save summary table inside log file?
  set detailedTables 1
  set format {table}
  # Format to display delay numbers
  set formatDelay {default}
  # Format to display memory numbers
  set formatMemory {default}
  # Default number of worst runtime/memory intensive commands
  set topNth 50
  # Only the commands that should contribute in the total runtime
  set profiledCommands {}
  # Commands that do not contribute to the total runtime
#   set ignoredCommands [list {open_checkpoint} {read_checkpoint} {read_xdc} {open_run} {open_project}]
  set ignoredCommands {}
  # -ignored_commands specified? yes:1 / no:0
  set userIgnoredCommandsOption 0
  # -profiled_commands specified? yes:1 / no:0
  set userProfiledCommandsOption 0
  # Hide commands that do not contribute to the total runtime
  set hideIgnoredCommands 0
  set reportMemory 1
  # Minimum memory gain for a command to be reported
  set minMemoryGain 0
  # Minimum runtime for a command to be reported
  set minRuntimeDelta 0
  # Maximum number of objects to be reported inside log file with 'configure -details'
  set maxNumObjects {end}
  # Indentation
  set indentString {    }
  set showIndent 0
  # Report scoping information
  set reportScoping 1
  set help 0
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-r(e(t(u(r(n(_(s(t(r(i(ng?)?)?)?)?)?)?)?)?)?)?)?$} -
      {^-return_string$} {
        set return_string 1
      }
      {^-file$} -
      {^-f(i(le?)?)?$} -
      {^-l(og?)?$} -
      {^-log$} {
        set logfile [lshift args]
      }
      {^-c(sv?)?$} -
      {^-csv$} {
        set format {csv}
      }
      {^-profiled_commands$} -
      {^-p(r(o(f(i(l(e(d(_(c(o(m(m(a(n(ds?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?$} {
        set profiledCommands [concat $profiledCommands [lshift args]]
        set userProfiledCommandsOption 1
      }
      {^-ignored_commands$} -
      {^-i(g(n(o(r(e(d(_(c(o(m(m(a(n(ds)?)?)?)?)?)?)?)?)?)?)?)?)?)?$} {
        set ignoredCommands [concat $ignoredCommands [lshift args]]
        set userIgnoredCommandsOption 1
      }
      {^-hide_ignored$} -
      {^-hi(d(e(_(i(g(n(o(r(ed?)?)?)?)?)?)?)?)?)?$} {
        set hideIgnoredCommands 1
      }
      {^-hms$} -
      {^-hms?$} {
        set formatDelay {hms}
      }
      {^-f(o(r(m(at?)?)?)?)?$} -
      {^-format$} {
        set formatDelay [lshift args]
      }
      {^-topnth$} -
      {^-to(p(n(th?)?)?)?$} {
        set topNth [lshift args]
      }
      {^-summary$} -
      {^-su(m(m(a(ry?)?)?)?)?$} {
        set detailedTables 0
      }
      {^-time_more_than$} -
      {^-ti(m(e(_(m(o(r(e(_(t(h(an?)?)?)?)?)?)?)?)?)?)?)?$} {
        # Convert milliseconds to microseconds (internal use)
        set minRuntimeDelta [expr 1000 * [lshift args]]
      }
      {^-limit$} -
      {^-li(m(it?)?)?$} {
        set maxNumObjects [lshift args]
      }
      {^-indent$} -
      {^-in(d(e(nt?)?)?)?$} {
        set showIndent 1
      }
      {^-no_scope$} -
      {^-no(_(s(c(o(pe?)?)?)?)?)?$} {
        set reportScoping 0
      }
      {^-no_header$} -
      {^-no_h(e(a(d(er?)?)?)?)?$} {
        set printHeader 0
      }
      {^-append$} -
      {^-ap(p(e(nd?)?)?)?$} {
        set filemode {a}
      }
      {^-sc_help$} -
      {^-sc(_(h(e(lp?)?)?)?)?$} -
      {^-h(e(lp?)?)?$} -
      {^--h(e(lp?)?)?$} {
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

  switch $formatDelay {
    hms -
    sec -
    ms -
    s -
    "default" {
    }
    default {
      incr error
      puts "-E- invalid format. Valid formats are: sec | ms | hms | default"
    }
  }

  if {$userIgnoredCommandsOption && $userProfiledCommandsOption} {
    incr error
    puts "-E- options -profiled_commands and -ignored_commands are exclusive"
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  if {$help} {
    puts [format {
  Usage: xilinx::designutils::profiler summary
              [-return_string]
              [-log <filename>|-file <filename>]
              [-append][-no_header]
              [-summary]
              [-hms][-format <hms|sec|ms|default>]
              [-topnth <num>]
              [-csv]
              [-ignored_commands <list_commands>][-profiled_commands <list_commands>]
              [-hide_ignored]
              [-time_more_than <ms>]
              [-limit <num>]
              [-indent]
              [-no_scope]
              [-help|-h]

  Description: Generate the profiler summary

    Use -hms/-format to change the format of reported delays
    Use -topnth to change the number of worst runtime reported inside the log file
      Default: 50
    Use -ignored_commands to list commands that should not contribute to the total runtime
      Default: open_checkpoint read_checkpoint read_xdc open_run open_project
    Use -profiled_commands to list commands that should contribute to the total runtime
      Default: all registered commands
    Use -hide_ignored to hide commands that are ignored
    Use -summary with -log to only save the summary table inside the log file. By default, the
      log file include the detailed tables
    Use -time_more_than to define the minimum runtime for a command to be reported (in ms)
      Default: 0
    Use -limit to reduce the number of reported objects. This option should be used when the
      detailed collections of objects are tracked (configure -details)
      Default: all objects are reported
    Use -indent to indent commands inside the detailed report based on their level
    Use -no_scope to suppress scoping information inside the detailed log file

  Example:
     xilinx::designutils::profiler summary
     xilinx::designutils::profiler summary -return_string -format hms
     xilinx::designutils::profiler summary -log profiler.log -csv
     xilinx::designutils::profiler summary -profiled_commands {get.+ .+_design} -hide_ignored
} ]
    # HELP -->
    return {}
  }

  if {$params(profileMemory) == 0} {
    set params(reportMemory) 0
  } else {
    set params(reportMemory) $reportMemory
  }

  set params(topNth) $topNth
  set params(formatMemory) $formatMemory
  set params(formatDelay) $formatDelay
  switch ${userIgnoredCommandsOption}${userProfiledCommandsOption} {
    00 {
      # All commands should be profiled
      set profiledCommands {.+}
      # Default list of Vivado commands that should not contribute to the total runtime
      set ignoredCommands [list {open_checkpoint} {read_checkpoint} {read_xdc} {open_run} {open_project}]
    }
    01 {
      # Default list of Vivado commands that should not contribute to the total runtime
      set ignoredCommands {}
    }
    10 {
      # All commands should be profiled
      set profiledCommands {.+}
    }
    11 {
      # Not supported - should not reach this condition
    }
  }

  set output [list]
  if {$format == {csv}} {
    lappend output "# --------- PROFILER STATS ---------------------------------------------"
  } else {
    lappend output "--------- PROFILER STATS ---------------------------------------------"
  }
  array set tmp {}
  array set mem {}
  set commands [list]
  # Total time inside the traced commands
  set totaltime 0
  # Total runtime
  set totalruntime 0
  # Multiple runs if 'profiler start -incr' has been used
  foreach t_start $tmstart t_end $tmend {
    incr totalruntime [expr $t_end - $t_start]
  }

  if {[llength $params(commands)] != 0} {
    # Method 'summary' can be called by providing the list of commands through $params(commands)
    set commands $params(commands)
    set params(commands) {}
  } else {
    # Otherwise, extract the list of commands from the internal data structure
    set ID 0
    foreach i $db {
      lassign $i memory clk enter level levels cmdline code result src_info
      set cmd [lindex $cmdline 0]
      # Skip commands that do not belong anymore to the list of commands to be traced
      # This can happen if the user remove some commands with 'profiler remove' after
      # the profiler was run
      if {[lsearch $cmdlist $cmd] == -1} {
        continue
      }
      if {$enter} {
        lappend tmp($cmd) $clk
        lappend mem($cmd) $memory
      } else {
        set delta [expr {$clk-[lindex $tmp($cmd) end]}]
        if {[llength $tmp($cmd)] == 1} {
          unset tmp($cmd)
        } else {
          set tmp($cmd) [lrange $tmp($cmd) 0 end-1]
        }
        # Some commands should not contribute to the total runtime
  #       if {![regexp {^(open_checkpoint|read_checkpoint|read_xdc|open_run|open_project)$} $cmd]} {}
        if {[regexp [format {^(%s)$} [join $profiledCommands {|}]] $cmd]
            && ![regexp [format {^(%s)$} [join $ignoredCommands {|}]] $cmd]} {
          incr totaltime $delta
        } else {
          if {$hideIgnoredCommands} {
            # Hide inside the log file the commands that are ignored
            continue
          }
        }
        # Memory related information
        set gain [expr {$memory-[lindex $mem($cmd) end]}]
        set peak $memory
  #       set peak [lindex $mem($cmd) end]
        if {[llength $mem($cmd)] == 1} {
          unset mem($cmd)
        } else {
          set mem($cmd) [lrange $mem($cmd) 0 end-1]
        }
        # Save the command inside the Tcl variable
        lappend commands [list $ID $level $levels $delta $gain $peak $cmdline $code $result $src_info]
        incr ID
      }
    }
  }

  if {[llength $tmstart] > 1} {
    if {$format == {csv}} {
      lappend output "# Number of profiler runs: [llength $tmstart]"
    } else {
      lappend output "Number of profiler runs: [llength $tmstart]"
    }
  }
  if {$format == {csv}} {
    set pct [format {%.2f} [expr {$totaltime*100.0/$totalruntime}]]
    lappend output "# Total time: [formatDelay $totalruntime] (${pct}% profiled + [format {%.2f} [expr 100-$pct]]% non-profiled commands)"
  } else {
    set pct [format {%.2f} [expr {$totaltime*100.0/$totalruntime}]]
    lappend output "Total time: [formatDelay $totalruntime] (${pct}% profiled + [format {%.2f} [expr 100-$pct]]% non-profiled commands)"
  }

  ################################################
  # Generate the table for runtime stats
  ################################################
  catch {unset runtime}
  set totalruntime 0
  set numunreported 0
  set ncalls 0
  foreach i $commands {
    lassign $i ID level levels delta gain peak cmdline code result src_info
    set cmd [lindex $cmdline 0]
    if {$delta < $minRuntimeDelta} {
      # If the runtime for this command is below the threshold, then skip it
      incr numunreported
      continue
    }
    # Some commands should not contribute to the total memory
    if {[regexp [format {^(%s)$} [join $profiledCommands {|}]] $cmd]
        && ![regexp [format {^(%s)$} [join $ignoredCommands {|}]] $cmd]} {
      incr totalruntime $delta
    } else {
      if {$hideIgnoredCommands} {
        # Hide inside the log file the commands that are ignored
        continue
      }
    }
    lappend runtime($cmd) $delta
  }

  set tbl [::tclapp::xilinx::designutils::prettyTable create]
  $tbl header [list {command:} {min} {max} {avg} {total} {ncalls} {%runtime}]
  foreach cmd [lsort [array names runtime]] {
    set pct [format {%.2f} [expr (100.0 * ([join $runtime($cmd) +])) / $totalruntime]]
    # Formatting of negative numbers
    if {[regexp {^-} $pct]} {
      # Negative number: catches numbers like -0.00
      set pct "([expr -1 * $pct]%)"
    } else {
      set pct "${pct}%"
    }
    # The commands that do not contribute to the total runtime are formatted differently
    if {[regexp [format {^(%s)$} [join $profiledCommands {|}]] $cmd]
        && ![regexp [format {^(%s)$} [join $ignoredCommands {|}]] $cmd]} {
      $tbl addrow [list $cmd \
                      [formatDelay [lindex [lsort -integer -increasing $runtime($cmd)] 0] ] \
                      [formatDelay [lindex [lsort -integer -increasing $runtime($cmd)] end] ] \
                      [formatDelay [expr int( (1.0 * ([join $runtime($cmd) +])) / [llength $runtime($cmd)] )] ] \
                      [formatDelay [expr [join $runtime($cmd) +]] ] \
                      [llength $runtime($cmd)] \
                      $pct \
                      ]
      incr ncalls [llength $runtime($cmd)]
    } else {
      if {$hideIgnoredCommands} {
        # Hide commands that are ignored
        continue
      }
      $tbl addrow [list [format {(%s)} $cmd] \
                      [format {(%s)} [formatDelay [lindex [lsort -integer -increasing $runtime($cmd)] 0] ] ] \
                      [format {(%s)} [formatDelay [lindex [lsort -integer -increasing $runtime($cmd)] end] ] ] \
                      [format {(%s)} [formatDelay [expr int( (1.0 * ([join $runtime($cmd) +])) / [llength $runtime($cmd)] )] ] ] \
                      [format {(%s)} [formatDelay [expr [join $runtime($cmd) +]] ] ] \
                      [format {(%s)} [llength $runtime($cmd)] ] \
                      {-} \
                      ]
    }
  }
  $tbl separator
  $tbl addrow [list {TOTAL} {} {} {} [formatDelay $totalruntime] $ncalls {100%}]
  if {$format == {table}} {
    lappend output [$tbl print -format lean]
    if {$numunreported} {
      lappend output [format {Note: %s commands with runtime below %s have been excluded from the above table} $numunreported [formatDelay $minRuntimeDelta] ]
      lappend output {}
    }
  } else {
    lappend output [$tbl export -format csv]
    # Include a tabular format of the table below the CSV report
    foreach i [split [$tbl print -format lean] \n] {
      lappend output [format {#  %s} $i]
    }
    if {$numunreported} {
      lappend output [format {# Note: %s commands with runtime below %s have been excluded from the above table} $numunreported [formatDelay $minRuntimeDelta]]
      lappend output {}
    }
  }
  # Destroy the table
  catch {$tbl destroy}

  ################################################
  # Generate the table for memory stats
  # Similar format as for runtime stats
  ################################################
  if {$params(reportMemory)} {
    catch {unset mem}
    set totalgain 0
    set numunreported 0
    set ncalls 0
    foreach i $commands {
      lassign $i ID level levels delta gain peak cmdline code result src_info
      set cmd [lindex $cmdline 0]
      if {$gain < $minMemoryGain} {
        # If the memory gain for this command is below the threshold, then skip it
        incr numunreported
        continue
      }
      # Some commands should not contribute to the total memory
      if {[regexp [format {^(%s)$} [join $profiledCommands {|}]] $cmd]
          && ![regexp [format {^(%s)$} [join $ignoredCommands {|}]] $cmd]} {
        incr totalgain $gain
      } else {
        if {$hideIgnoredCommands} {
          # Hide inside the log file the commands that are ignored
          continue
        }
      }
      lappend mem($cmd) $gain
    }
    if {$format == {csv}} {
      lappend output "# --------- MEMORY STATS -----------------------------------------------"
    } else {
      lappend output "--------- MEMORY STATS -----------------------------------------------"
    }
    set tbl [::tclapp::xilinx::designutils::prettyTable create]
    $tbl header [list {command:} {min} {max} {avg} {total} {ncalls} {%gain}]
    foreach cmd [lsort [array names mem]] {
      set pct [format {%.2f} [expr (100.0 * ([join $mem($cmd) +])) / $totalgain]]
      # Formatting of negative numbers
      if {[regexp {^-} $pct]} {
        # Negative number: catches numbers like -0.00
        set pct "([expr -1 * $pct]%)"
      } else {
        set pct "${pct}%"
      }
      # The commands that do not contribute to the total runtime are formatted differently
      if {[regexp [format {^(%s)$} [join $profiledCommands {|}]] $cmd]
          && ![regexp [format {^(%s)$} [join $ignoredCommands {|}]] $cmd]} {
        $tbl addrow [list $cmd \
                        [formatMemory [lindex [lsort -integer -increasing $mem($cmd)] 0] 0 ] \
                        [formatMemory [lindex [lsort -integer -increasing $mem($cmd)] end] 0 ] \
                        [formatMemory [expr int( (1.0 * ([join $mem($cmd) +])) / [llength $mem($cmd)] )] 0 ] \
                        [formatMemory [expr [join $mem($cmd) +]] ] \
                        [llength $mem($cmd)] \
                        $pct \
                        ]
        incr ncalls [llength $mem($cmd)]
      } else {
        if {$hideIgnoredCommands} {
          # Hide commands that are ignored
          continue
        }
        $tbl addrow [list [format {(%s)} $cmd] \
                        [format {(%s)} [formatMemory [lindex [lsort -integer -increasing $mem($cmd)] 0] 0 ] ] \
                        [format {(%s)} [formatMemory [lindex [lsort -integer -increasing $mem($cmd)] end] 0 ] ] \
                        [format {(%s)} [formatMemory [expr int( (1.0 * ([join $mem($cmd) +])) / [llength $mem($cmd)] )] 0 ] ] \
                        [format {(%s)} [formatMemory [expr [join $mem($cmd) +]] ] ] \
                        [format {(%s)} [llength $mem($cmd)] ] \
                        {-} \
                        ]
      }
    }
    $tbl separator
    $tbl addrow [list {TOTAL} {} {} {} [formatMemory $totalgain 0] $ncalls {100%}]
    if {$format == {table}} {
      lappend output [$tbl print -format lean]
      if {$numunreported} {
        lappend output [format {Note: %s commands with memory gain below %s have been excluded from the above table} $numunreported [formatMemory $minMemoryGain] ]
      }
    } else {
      lappend output [$tbl export -format csv]
      # Include a tabular format of the table below the CSV report
      foreach i [split [$tbl print -format lean] \n] {
        lappend output [format {#  %s} $i]
      }
      if {$numunreported} {
        lappend output [format {# Note: %s commands with memory gain below %s have been excluded from the above table} $numunreported [formatMemory $minMemoryGain] ]
      }
    }
    # Destroy the table
    catch {$tbl destroy}
  }

  if {$logfile != {}} {
    if {[catch {
      set FH [open $logfile $filemode]
      if {$printHeader} {
        puts $FH "# ---------------------------------------------------------------------------"
        puts $FH [format {# Created on %s with Tcl Profiler (%s)} [clock format [clock seconds]] $version ]
        puts $FH "# ---------------------------------------------------------------------------\n"
      }

      # Print the stats inside the log file
      puts $FH "\n############## STATISTICS #################\n"
      # Summary table
      foreach i [split [join $output \n] \n] {
#         puts $FH [format {#  %s} $i]
        puts $FH [format {%s} $i]
      }

      if {$detailedTables} {
        puts $FH "\n############## TOP $params(topNth) RUNTIMES ############\n"
        # Select the top 50 offenders from a runtime perspective
#         set offenders [lrange [lsort -index 1 -decreasing -integer $commands] 0 49]
        set offenders [lrange [lsort -index 3 -decreasing -integer $commands] 0 [expr $params(topNth) -1] ]
        set tbl [::tclapp::xilinx::designutils::prettyTable create]
        $tbl header [list {ID} {runtime} {result} {command}]
        foreach i $offenders {
          lassign $i ID level levels delta gain peak cmdline code result src_info
          if {[string length $cmdline] > 200} {
            # Cut the command line at first space after the first 200 characters
            set idx [string first " " [string range $cmdline 200 end]]
            set cmdline [format {%s ... <%s more characters>} [string range $cmdline 0 [expr 200 + $idx]] [expr [string length $cmdline] -200 -$idx] ]
          }
          set nbrObjects {n/a}
          if {$params(expandObjects)} {
            set nbrObjects [format {%s objects} [llength $result]]
          } else {
            set nbrObjects [regsub "\}" [regsub "\{" $result ""] ""]
          }
          $tbl addrow [list $ID [formatDelay $delta] $nbrObjects $cmdline]
        }
        foreach i [split [$tbl print -format lean] \n] {
          puts $FH [format {#  %s} $i]
        }
        # Destroy the table
        catch {$tbl destroy}

        if {$params(reportMemory)} {
          puts $FH "\n############ TOP $params(topNth) MEMORY GAIN ###########\n"
          # Select the top 50 offenders from a memory perspective
#           set offenders [lrange [lsort -index 2 -decreasing -integer $commands] 0 49]
          set offenders [lrange [lsort -index 4 -decreasing -integer $commands] 0 [expr $params(topNth) -1] ]
          set tbl [::tclapp::xilinx::designutils::prettyTable create]
          $tbl header [list {ID} {gain} {peak} {result} {command}]
          foreach i $offenders {
            lassign $i ID level levels delta gain peak cmdline code result src_info
            if {[string length $cmdline] > 200} {
              # Cut the command line at first space after the first 200 characters
              set idx [string first " " [string range $cmdline 200 end]]
              set cmdline [format {%s ... <%s more characters>} [string range $cmdline 0 [expr 200 + $idx]] [expr [string length $cmdline] -200 -$idx] ]
            }
            set nbrObjects {n/a}
            if {$params(expandObjects)} {
              set nbrObjects [format {%s objects} [llength $result]]
            } else {
              set nbrObjects [regsub "\}" [regsub "\{" $result ""] ""]
            }
            $tbl addrow [list $ID [formatMemory $gain] [formatMemory $peak] $nbrObjects $cmdline]
          }
          foreach i [split [$tbl print -format lean] \n] {
            puts $FH [format {#  %s} $i]
          }
          # Destroy the table
          catch {$tbl destroy}
        }

        puts $FH "\n############## TOP 10 COLLECTIONS #########\n"
        # Report the top 10 largest collections
        set tbl [::tclapp::xilinx::designutils::prettyTable create]
        $tbl header [list {size} {count} {total} {commands}]
        catch {unset collections}
        foreach i $commands {
          lassign $i ID level levels delta gain peak cmdline code result src_info
          set count 0
          if {$params(expandObjects)} {
            # If the collection of objects is expanded, then we need $result to
            # contain the number of objects. Recreate the string like if the objects
            # would not have been expanded
            set result [format {%s object} [llength $result]]
          }
          if {![regexp {([0-9]+) object} $result - count]} {
            # If $result does not match a string such as '1234 objects' then continue
            continue
          }
          if {$count == 0} {
            # Skip empty collections
            continue
          }
          # Save the command that generated the collection => lindex <..> 0
          lappend collections($count) [lindex [split $cmdline { }] 0]
        }
        # Count total number of objects from all collections
        set count 0
        foreach size [array names collections] {
          incr count [expr $size * [llength $collections($size)]]
        }
        # Keep the 10 largest collections
        foreach size [lrange [lsort -integer -decreasing [array names collections]] 0 9] {
          $tbl addrow [list $size [llength $collections($size)] [expr $size * [llength $collections($size)]] [lsort -unique $collections($size)] ]
        }
        foreach i [split [$tbl print -format lean] \n] {
          puts $FH [format {#  %s} $i]
        }
        puts $FH [format {#  Total number of objects: %s} $count]
        # Destroy the table
        catch {$tbl destroy}


        puts $FH "\n############## DETAILED SUMMARY ###########"
        if {$format == {csv}} {
          set tbl [::tclapp::xilinx::designutils::prettyTable create]
          if {$params(reportMemory)} {
            if {$reportScoping} {
              $tbl header [list {ID} {runtime} {gain} {command} {scope} {objects}]
            } else {
              $tbl header [list {ID} {runtime} {gain} {command} {objects}]
            }
          } else {
            if {$reportScoping} {
              $tbl header [list {ID} {runtime} {command} {scope} {objects}]
            } else {
              $tbl header [list {ID} {runtime} {command} {objects}]
            }
          }
        }
        set row [list]
        foreach i $commands {
          lassign $i ID level levels delta gain peak cmdline code result src_info
          set cmd [lindex $cmdline 0]
          set scope [join $levels :]
          if {$gain < $minMemoryGain} {
            # If the memory gain for this command is below the threshold, then skip it
            continue
          }
           if {$delta < $minRuntimeDelta} {
             # If the runtime for this command is below the threshold, then skip it
             continue
           }
          set memstr {}
          if {$params(reportMemory)} {
            set memstr "gain:[formatMemory $gain] peak:[formatMemory $peak] "
          }
          if {$reportScoping} {
            # Add scoping information
            append memstr "scope:$scope "
          }
          set indent {}
          if {$showIndent} {
            # Create the indent string
            set indent [string repeat $indentString [expr $level -1]]
          }
          if {$format == {table}} {
            if {$src_info != {}} {
              puts $FH "\n${indent}# ID:$ID level:$level time:[formatDelay $delta] ${memstr}$src_info "
            } else {
              puts $FH "\n${indent}# ID:$ID level:$level time:[formatDelay $delta] ${memstr}"
            }
          } else {
            if {$params(reportMemory)} {
              set row [list $ID [format {%.3f} [expr $delta / 1000.0]] $gain ]
            } else {
              set row [list $ID [format {%.3f} [expr $delta / 1000.0]] ]
            }
          }
          if {[string length $cmdline] > 1000} {
            # Cut the command line at first space after the first 1000 characters
            set idx [string first " " [string range $cmdline 1000 end]]
            set cmdline [format {%s ... <%s more characters>} [string range $cmdline 0 [expr 1000 + $idx]] [expr [string length $cmdline] -1000 -$idx] ]
          }
          if {$format == {table}} {
            # Table format ...
            puts $FH ${indent}$cmdline
            if {$code != 0} {
              puts $FH [format { -E- returned error code: %s} $code]
            }
            if {[regexp {^(report_.+)$} $cmd]} {
              # Special treatment if the executed command is a report. In this case
              # just print the report as is
              if {$result != {}} {
                foreach el [split $result \n] {
                  puts $FH [format {%s#    %s} $indent $el]
                }
              }
            } else {
              catch {
                if {$result != {}} {
                  if {[llength $result] == 1} {
                    puts $FH [format {%s#    %s} $indent $result]
                  } else {
                    set numObjects [llength $result]
                    puts $FH [format {%s# %d objects:} $indent $numObjects]
                    set L [lsort -dictionary $result]
                    if {$maxNumObjects != {end}} {
                      set L [lrange $L 0 [expr $maxNumObjects -1] ]
                    }
                    foreach el $L {
                      puts $FH [format {%s#    %s} $indent $el]
                    }
                    if {$maxNumObjects != {end}} {
                      set numUnreportedObjects [expr $numObjects - $maxNumObjects]
                      if {$numUnreportedObjects > 0} {
                        puts $FH [format {%s#    <%d more objects>} $indent $numUnreportedObjects]
                      }
                    }
                    catch { unset L }
                  }
                }
              }
            }
          } else {
            # CSV format ...
            lappend row $cmdline
            if {$reportScoping} {
              lappend row $scope
            }
            if {[regexp {^(report_.+)$} $cmd]} {
              # Special treatment if the executed command is a report.
              lappend row {}
            } else {
              catch {
                if {$result != {}} {
                  if {[llength $result] == 1} {
                    lappend row $result
                  } else {
                    lappend row [llength $result]
                  }
                }
              }
            }
          }
          if {$format == {csv}} {
            $tbl addrow $row
          }
        }
        # End "DETAILED SUMMARY"
        if {$format == {csv}} {
          puts $FH [$tbl export -format csv]
          # Destroy the table
          catch {$tbl destroy}
        }

        # End of all detailed tables
      }

    } errorstring]} {
        puts " -I- failed to generate log file '[file normalize $logfile]': $errorstring"
    } else {
        puts " -I- log file '[file normalize $logfile]' has been created"
    }
    close $FH
  }

  if {$return_string} {
    return -code ok [join $output \n]
  } else {
    puts [join $output \n]
    return -code ok
  }
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::method:time
#------------------------------------------------------------------------
# Usage: profiler time [<options>]
#------------------------------------------------------------------------
# Profile the specified code
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::method:time {args} {
  # Summary :
  # Argument Usage:
  # Return Value:

  # Profile the inline Tcl code (-help)
  variable cmdlist
  variable params
  if {$params(mode) == {started}} {
    error " -E- the profiler is already running. Use 'profiler stop' to stop the profiler"
  }

  set error 0
  set sections [list]
  set startOptions [list]
  set logfile {}
  set help 0
  if {[llength $args] == 0} { incr help }
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-incr$} -
      {^-in(cr?)?$} {
        lappend startOptions {-incr}
      }
      {^-src_info$} -
      {^-sr(c(_(i(n(fo?)?)?)?)?)?$} {
        lappend startOptions {-src_info}
      }
      {^-memory$} -
      {^-me(m(o(ry?)?)?)?$} {
        lappend startOptions {-memory}
      }
      {^-limit$} -
      {^-li(m(it?)?)?$} -
      {^-collection_display_limit$} -
      {^-co(l(l(e(c(t(i(o(n(_(d(i(s(p(l(a(y(_(l(i(m(it?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?$} {
        lappend startOptions {-limit}
        lappend startOptions [lshift args]
      }
      {^-log$} -
      {^-log?$} {
        set logfile [lshift args]
      }
      {^-sc_help$} -
      {^-sc(_(h(e(lp?)?)?)?)?$} -
      {^-h(e(lp?)?)?$} -
      {^--h(e(lp?)?)?$} {
        set help 1
      }
      default {
        if {[string match "-*" $name]} {
          puts " -E- option '$name' is not a valid option."
          incr error
        } else {
          # Append to the list of Tcl sections(s) to execute
          lappend sections $name
        }
      }
    }
  }

  if {$error} {
    error " -E- some error(s) happened. Cannot continue"
  }

  if {$help} {
    puts [format {
  Usage: xilinx::designutils::profiler time <SectionOfTclCode>
              [-incr]
              [-src_info]
              [-collection_display_limit|-limit <num>]
              [-log <filename>]
              [-help|-h]

  Description: Run the profiler on an inline Tcl code

  Example:
     xilinx::designutils::profiler time { read_xdc ./constraints.xdc } -collection_display_limit 500
     xilinx::designutils::profiler time -incr -src_info { read_xdc ./constraints.xdc } -log profiler.log
} ]
    # HELP -->
    return {}
  }

  if {[llength $cmdlist] == 0} {
    error " -E- no command has been added to the profiler. Use 'profiler add' to add Vivado commands"
  }

  if {[llength $sections] == 0} {
    error " -E- no in-line code provided"
  }

  # Start the profiler
  eval [concat ::tclapp::xilinx::designutils::profiler::method:start $startOptions]

  # Execute each section of Tcl code
  foreach section $sections {
    set res {}
    # Needs to be executed 3 levels higher in the stack
    if {[catch { set res [uplevel 3 [concat eval $section]] } errorstring]} {
      ::tclapp::xilinx::designutils::profiler::method:stop
      error " -E- the profiler failed with the following error: $errorstring"
    }
  }

  # Stop the profiler
  ::tclapp::xilinx::designutils::profiler::method:stop

  # Generate the summary and log file if requested
  if {$logfile != {}} {
    ::tclapp::xilinx::designutils::profiler::method:summary -log $logfile
  }

  return -code ok
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::profiler::method:configure
#------------------------------------------------------------------------
# Usage: profiler configure [<options>]
#------------------------------------------------------------------------
# Configure some of the profiler parameters
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::profiler::method:configure {args} {
  # Summary :
  # Argument Usage:
  # Return Value:

  # Configure the profiler (-help)
  variable params
  set error 0
  set help 0
  if {[llength $args] == 0} {
    set help 1
  }
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-limit$} -
      {^-li(m(it?)?)?$} -
      {^-collection_display_limit$} -
      {^-co(l(l(e(c(t(i(o(n(_(d(i(s(p(l(a(y(_(l(i(m(it?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?)?$} {
        set params(collectionResultDisplayLimit) [lshift args]
      }
      {^-details$} -
      {^-de(t(a(i(ls?)?)?)?)?$} {
        set params(expandObjects) 1
      }
      {^-summary$} -
      {^-su(m(m(a(ry?)?)?)?)?$} {
        set params(expandObjects) 0
      }
      {^-no_cmdline$} -
      {^-no(_(c(m(d(l(i(ne?)?)?)?)?)?)?)?$} {
        set params(trackCmdline) 0
      }
      {^-cmdline$} -
      {^-cm(d(l(i(ne?)?)?)?)?$} {
        set params(trackCmdline) 1
      }
      {^-sc_help$} -
      {^-sc(_(h(e(lp?)?)?)?)?$} -
      {^-h(e(lp?)?)?$} -
      {^--h(e(lp?)?)?$} {
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
  Usage: xilinx::designutils::profiler configure
              [-collection_display_limit|-limit <num>]
              [-summary][-details]
              [-no_cmdline][-cmdline]
              [-help|-h]

  Description: Configure the profiler

    -details: expand inside the log file the list of objects returned by each command
    -summary: summarize inside the log file the number of objects returned by each command (default)
    -cmdline: track the command line options for each command (default)
    -no_cmdline: do not track the command line options for each command

    Default behavior is -summary and -cmdline

  Example:
     xilinx::designutils::profiler configure -collection_display_limit 500 -details
} ]
    # HELP -->
    return -code ok
  }
  return -code ok
}



#################################################################################

# namespace import ::tclapp::xilinx::designutils::profiler
