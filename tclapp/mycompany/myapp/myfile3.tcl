package require Vivado 1.2014.1

namespace eval ::tclapp::mycompany::myapp {
    # Export procs that should be allowed to import into other namespaces
    namespace export myproc3
}
    
proc ::tclapp::mycompany::myapp::myproc3 {args} {

    # Summary : 3_10_2014
    
    # Argument Usage:
    # [-cell <arg> = current_instance]: Cell to generate template on. If not specified, runs on current_instance
    # [-file <arg> = <module>.v or <module>.vhd]: Output file name
    # [-append]: Append to file
    # [-return_string]: Return result as string
    # [-usage]: Usage information

    # Return Value: 
    # TCL_OK is returned with result set to a string

    proc lshift {inputlist} {
      # Summary :
      # Argument Usage:
      # Return Value:
    
      upvar $inputlist argv
      set arg  [lindex $argv 0]
      set argv [lrange $argv 1 end]
      return $arg
    }

    puts "I am pushing it to github 2014-03-05"
    puts "Calling ::tclapp::mycompany::myapp::myproc3 '$args'"
    
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
                puts " -E- option '$name' is not a valid option. Use the -help option for more details"
                incr error
              } else {
                puts " -E- option '$name' is not a valid option. Use the -help option for more details"
                incr error
              }
        }
      }
    }

    if {$help} {
      puts [format {
  Usage: myproc3
              [-cell <arg>]        - Cell to generate template on. If not specified,
                                     runs on current_instance
              [-file <arg>]        - Output file name
                                     Default: <module>.v or <module>.vhd
              [-append]            - Append to file
              [-return_string]     - Return template as string
              [-usage|-u]          - This help message

  Description: Get iformation on a cell and generate a report

  Example:
     myproc3
     myproc3 -cell ila_v2_1_0 -return_string
} ]
      # HELP -->
      return {}
    }

    if {$error} {
      error " -E- some error(s) happened. Cannot continue"
    }

    return -code ok "myproc3 result"
}

