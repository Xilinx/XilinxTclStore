package require Vivado 1.2024.1

namespace eval ::tclapp::aldec::alint {
    namespace export convert_project
}

proc ::tclapp::aldec::alint::convert_project {alint_path} {

    # Summary: Convert Vivado project to Alint

    # Argument Usage:
    # alint_path: Path where Alint is located

    # Return Value:

    # Categories: xilinxtclstore, aldec, alint, convert

    set alintcon $alint_path/bin/alintcon

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
        -do $alint_script_path $xpr_path \
        >@stdout
}
