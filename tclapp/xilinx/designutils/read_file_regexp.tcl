package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export read_file_regexp gets_regexp
}

##
## Example code:
##    foreach line [::tclapp::xilinx::designutils::read_file_regexp myreport.rpt {Cell:}] {
##      # Process one-by-one, all the lines that matched the pattern: Cell:
##    }
##
proc ::tclapp::xilinx::designutils::read_file_regexp {filename rexp} {
  # Summary : Returns all lines that match occurrence of a regular expression in the file

  # Argument Usage:
  # filename : File name to process
  # rexp : Regular expresion

  # Return Value:
  # all the lines that match the regular expression
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  set lines [list]
  set FH {}
  if {[catch {set FH [open $filename r]} errorstring]} {
      error " error - $errorstring"
  }
  while {![eof $FH]} {
    gets $FH line
    if {[regexp $rexp $line]} { lappend lines $line }
  }
  close $FH
  return $lines
}

##
## Example code:
##    set FH [open myreport.rpt r]
##    while {![eof $FH]} {
##      set status [gets_regexp $FH {Cell:} line]
##      if {$status == 0} { 
##        # Process one-by-one, all the lines that matched the pattern: Cell:
##      }
##    }
##    close $FH
##
proc ::tclapp::xilinx::designutils::gets_regexp {FH rexp var} {
  # Summary : Returns the next line that matches occurrence of a regular expression in the file

  # Argument Usage:
  # FH : File handler of the file to process
  # rexp : Regular expresion
  # var : Variable name to get the next line matching the regular expression

  # Return Value:
  # 0 if succeeded
  # 1 if EOF reached
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  upvar 1 $var _var
  if {$FH == {}} {
    error " error - empty file handler"
  }
  if {[eof $FH]} {
    error " error - End-Of-File has been reached"
  }
  while {![eof $FH]} {
    gets $FH line
    if {[regexp $rexp $line]} { set _var $line; return 0 }
  }
  set _var {}
  return 1
}
