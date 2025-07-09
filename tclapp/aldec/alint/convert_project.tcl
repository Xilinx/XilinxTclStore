package require Vivado 1.2024.1

namespace eval ::tclapp::aldec::alint {
    namespace export convert_project
}

proc ::tclapp::aldec::alint::convert_project {args} {

    # Summary: Convert Vivado project to Alint

    # Argument Usage:
    #  alint_path: Path where Alint is located
    #  [-usage]: This help message

    # Return Value:

    # Categories: xilinxtclstore, aldec, alint, convert

    set usage [format {
  Usage: convert_project
              alint_path - Path where Alint is located
              [-usage]   - This help message

  Description: Convert Vivado project to Alint
  Example:
     convert_project ~/ALINT-PRO
}]

    set help false

    foreach arg $args {
        switch -- $arg {
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
        error "Alint path not passed\n$usage"
    }

    set alint $alint_path/bin/alint
    set alintcon $alint_path/bin/alintcon
    if {$::tcl_platform(platform) == "windows"} {
        set alint $alint.exe
        set alintcon $alintcon.exe
    }

    if {![file exists $alintcon]} {
        error "Required file $alintcon not found"
    }

    # Generate a script file for Alint
    set alint_script_path [file tempfile]
    set alint_script_file [open $alint_script_path w]
    set alint_script {
        convert.xpr.project {*}$argv
    }
    puts $alint_script_file $alint_script
    close $alint_script_file

    set project_dir [get_property DIRECTORY [current_project]]
    set project_name [get_property NAME [current_project]]
    set xpr_path [file join $project_dir $project_name.xpr]
    if {![file exists $xpr_path]} {
        error "Project file not found"
    }

    exec -- $alintcon \
        -batch \
        -do $alint_script_path $xpr_path
}
