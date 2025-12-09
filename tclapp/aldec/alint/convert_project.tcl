package require Vivado 1.2024.1

namespace eval ::tclapp::aldec::alint {
    namespace export convert_project
}

proc ::tclapp::aldec::alint::convert_project {args} {

    # Summary: Convert Vivado project to ALINT-PRO

    # Argument Usage:
    #  alint_path: Path where ALINT-PRO is located
    #  [-gui]: Start ALINT-PRO in GUI mode and don't exit after converting
    #  [-usage]: This help message

    # Return Value:

    # Categories: xilinxtclstore, aldec, alint, convert

    set usage [format {
  Usage: aldec::alint::convert_project
              alint_path - Path where ALINT-PRO is located
              [-gui]     - Start ALINT-PRO in GUI mode and don't exit after converting
              [-usage]   - This help message

  Description: Convert Vivado project to ALINT-PRO
  Example:
     aldec::alint::convert_project ~/ALINT-PRO
     aldec::alint::convert_project -gui ~/ALINT-PRO
}]

    set gui false
    set help false

    foreach arg $args {
        switch -- $arg {
            -gui {
                set gui true
            }
            -usage {
               set help true
            }
            -* {
                error "Unrecognized option $arg"
            }
            default {
                if {[info exists alint_path]} {
                    error "Too many arguments\n$usage"
                }
                set alint_path $arg
            }
        }
    }

    if {$help} {
        puts $usage
        return
    }

    if {![info exists alint_path]} {
        error "ALINT-PRO path not passed\n$usage"
    }

    if {$gui} {
        set alint_bin $alint_path/bin/alint
    } else {
        set alint_bin $alint_path/bin/alintcon
    }
    if {$::tcl_platform(platform) == "windows"} {
        set alint_bin $alint_bin.exe
    }

    if {![file exists $alint_bin]} {
        error "Required file $alint_bin not found"
    }

    set this_script_path [dict get [info frame 0] file]
    set alint_script_path [file dirname $this_script_path]/alint_script.do

    set project_dir [get_property DIRECTORY [current_project]]
    set project_name [get_property NAME [current_project]]
    set xpr_path [file join $project_dir $project_name.xpr]
    if {![file exists $xpr_path]} {
        error "Project file not found"
    }

    if {$gui} {
        exec -- $alint_bin \
            -do $alint_script_path $xpr_path &
    } else {
        exec -- $alint_bin \
            -batch \
            -do $alint_script_path $xpr_path
    }
}
