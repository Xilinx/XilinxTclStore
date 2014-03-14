package require Vivado 1.2014.1

namespace eval ::tclapp::mycompany::template {
    # Export procs that should be allowed to import into other namespaces
    namespace export my_command1
}

proc ::tclapp::mycompany::template::my_command1 { args } {
  # Summary: Multi-lines summary of
  # what the proc is doing

  # Argument Usage:
  # [-verbose]: Verbose mode
  # [-file <arg>]: Report file name
  # [-append]: Append to file
  # [-return_string]: Return report as string
  # [-usage]: Usage information

  # Return Value:
  # return report if -return_string is used, otherwise 0. If any error occur TCL_ERROR is returned

  # Categories: xilinxtclstore, template

  uplevel [concat ::tclapp::mycompany::template::my_command1::my_command1 $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::mycompany::template::my_command1 {
} ]

proc ::tclapp::mycompany::template::my_command1::lshift {inputlist} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:

  upvar $inputlist argv
  set arg  [lindex $argv 0]
  set argv [lrange $argv 1 end]
  return $arg
}

proc ::tclapp::mycompany::template::my_command1::my_command1 {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:

    #-------------------------------------------------------
    # Process command line arguments
    #-------------------------------------------------------
    set error 0
    set help 0
    set filename {}
    set cell {}
    set returnString 0
    while {[llength $args]} {
      set name [lshift args]
      switch -regexp -- $name {
        -cell -
        {^-c(e(ll?)?)?$} {
             set cell [lshift args]
        }
        -file -
        {^-f(i(le?)?)?$} {
             set filename [lshift args]
             if {$filename == {}} {
               puts " -E- no filename specified."
               incr error
             }
        }
        -append -
        {^-a(p(p(e(nd?)?)?)?)?$} {
             set mode {a}
        }
        -return_string -
        {^-r(e(t(u(r(n(_(s(t(r(i(ng?)?)?)?)?)?)?)?)?)?)?)?$} {
             set returnString 1
        }
        -usage -
        {^-u(s(a(ge?)?)?)?$} {
             set help 1
        }
        default {
              if {[string match "-*" $name]} {
                puts " -E- option '$name' is not a valid option. Use the -usage option for more details"
                incr error
              } else {
                puts " -E- option '$name' is not a valid option. Use the -usage option for more details"
                incr error
              }
        }
      }
    }

    if {$help} {
      puts [format {
  Usage: my_command1
              [-cell <arg>]        - Cell to generate template on. If not specified,
                                     runs on current_instance
              [-file <arg>]        - Output file name
                                     Default: <module>.v or <module>.vhd
              [-append]            - Append to file
              [-return_string]     - Return template as string
              [-usage|-u]          - This help message

  Description: Get information on a cell and generate a report

  Example:
     tclapp::mycompany::template::my_command1
     tclapp::mycompany::template::my_command1 -cell ila_v2_1_0 -return_string
} ]
      # HELP -->
      return {}
    }

    if {$error} {
      error " -E- some error(s) happened. Cannot continue"
    }

    return -code ok "my_command1 result"
}
