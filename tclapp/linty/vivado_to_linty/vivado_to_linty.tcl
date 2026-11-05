# Package provider and commands for the Vivado to Linty app.
package require Tcl 8.5

namespace eval ::tclapp::linty::vivado_to_linty::internal {}

namespace eval ::tclapp::linty::vivado_to_linty {
    # Allow Tcl to find tclIndex
    variable home [file join [pwd] [file dirname [info script]]]
    if {[lsearch -exact $::auto_path $home] == -1} {
        lappend ::auto_path $home
    }
    namespace export run
}

proc ::tclapp::linty::vivado_to_linty::internal::rel_to {base path} {

    # Summary: Return path relative to a base directory

    # Argument Usage:
    # base : Directory the returned path is relative to
    # path : File or directory to make relative

    # Return Value:
    # Relative path, or the original path when the two locations do not share a prefix

    set base [file normalize $base]
    set path [file normalize $path]

    set bs [file split $base]
    set ps [file split $path]

    set i 0
    set n [llength $bs]
    set m [llength $ps]
    set lim [expr {$n < $m ? $n : $m}]
    while {$i < $lim && [lindex $bs $i] eq [lindex $ps $i]} {
        incr i
    }

    if {$i == 0} {
        return $path
    }

    set up [list]
    for {set k $i} {$k < $n} {incr k} {
        lappend up ".."
    }
    set down [lrange $ps $i end]

    if {[llength $up] == 0 && [llength $down] == 0} {
        return "."
    }
    if {[llength $up] == 0} {
        return [file join {*}$down]
    }
    if {[llength $down] == 0} {
        return [file join {*}$up]
    }
    return [file join {*}$up {*}$down]
}

proc ::tclapp::linty::vivado_to_linty::internal::ys_quote {path} {

    # Summary: Quote a Yosys token when it contains whitespace or quotes

    # Argument Usage:
    # path : Token to quote

    # Return Value:
    # Quoted token, or the original token when quoting is not required

    if {[string match "*\[ \t\"\\\]*" $path]} {
        set escaped [string map {\\ \\\\ \" \\\"} $path]
        return "\"$escaped\""
    }
    return $path
}

proc ::tclapp::linty::vivado_to_linty::internal::ys_chparam_value {value} {

    # Summary: Format a parameter value for a Yosys -chparam argument

    # Argument Usage:
    # value : Generic value from Vivado

    # Return Value:
    # Bare integer or Verilog literal, otherwise a quoted string

    if {[regexp {^-?[0-9]+$} $value] || [regexp {^[0-9]+'[bBhHdD][0-9a-fA-F_xXzZ]+$} $value]} {
        return $value
    }
    set escaped [string map {\\ \\\\ \" \\\"} $value]
    return "\"$escaped\""
}

proc ::tclapp::linty::vivado_to_linty::internal::vivado_root {} {

    # Summary: Return the Vivado installation directory

    # Argument Usage:

    # Return Value:
    # Value of XILINX_VIVADO, or an empty string when it is not set

    if {![info exists ::env(XILINX_VIVADO)] || $::env(XILINX_VIVADO) eq ""} {
        return ""
    }
    return $::env(XILINX_VIVADO)
}

proc ::tclapp::linty::vivado_to_linty::internal::existing_files {paths} {

    # Summary: Keep only the paths that name an existing file

    # Argument Usage:
    # paths : Candidate file paths

    # Return Value:
    # List of paths that exist

    set found [list]
    foreach path $paths {
        if {[file isfile $path]} {
            lappend found $path
        }
    }
    return $found
}

proc ::tclapp::linty::vivado_to_linty::internal::unisim_vhd_files {} {

    # Summary: Return the UNISIM VHDL package files from the Vivado installation

    # Argument Usage:

    # Return Value:
    # Existing unisim_VPKG.vhd and unisim_VCOMP.vhd paths

    set install [vivado_root]
    if {$install eq ""} {
        return [list]
    }
    set root [file join $install data vhdl src unisims]
    return [existing_files [list \
        [file join $root unisim_VPKG.vhd] \
        [file join $root unisim_VCOMP.vhd]]]
}

proc ::tclapp::linty::vivado_to_linty::internal::xpm_sv_files {} {

    # Summary: Return the XPM SystemVerilog sources from the Vivado installation

    # Argument Usage:

    # Return Value:
    # Existing xpm_cdc.sv, xpm_memory.sv, and xpm_fifo.sv paths

    set install [vivado_root]
    if {$install eq ""} {
        return [list]
    }
    set root [file join $install data ip xpm]
    return [existing_files [list \
        [file join $root xpm_cdc hdl xpm_cdc.sv] \
        [file join $root xpm_memory hdl xpm_memory.sv] \
        [file join $root xpm_fifo hdl xpm_fifo.sv]]]
}

proc ::tclapp::linty::vivado_to_linty::internal::xpm_vhd_files {} {

    # Summary: Return the XPM VHDL package from the Vivado installation

    # Argument Usage:

    # Return Value:
    # Existing xpm_VCOMP.vhd path

    set install [vivado_root]
    if {$install eq ""} {
        return [list]
    }
    return [existing_files [list \
        [file join $install data ip xpm xpm_VCOMP.vhd]]]
}

proc ::tclapp::linty::vivado_to_linty::internal::unimacro_vhd_files {} {

    # Summary: Return the UNIMACRO VHDL package from the Vivado installation

    # Argument Usage:

    # Return Value:
    # Existing unimacro_VCOMP.vhd path

    set install [vivado_root]
    if {$install eq ""} {
        return [list]
    }
    return [existing_files [list \
        [file join $install data vhdl src unimacro unimacro_VCOMP.vhd]]]
}

proc ::tclapp::linty::vivado_to_linty::internal::split_name_value {item} {

    # Summary: Split a name=value token

    # Argument Usage:
    # item : Token that may contain one equals sign

    # Return Value:
    # Two-element list of name and value. The value is empty when there is no equals sign

    set eq [string first "=" $item]
    if {$eq < 0} {
        return [list $item ""]
    }
    return [list \
        [string range $item 0 [expr {$eq - 1}]] \
        [string range $item [expr {$eq + 1}] end]]
}

proc ::tclapp::linty::vivado_to_linty::internal::fileset_verilog_defines {fs} {

    # Summary: Read VERILOG_DEFINE from a fileset

    # Argument Usage:
    # fs : Fileset object

    # Return Value:
    # Dictionary of define names to values

    set defines [dict create]
    if {[catch {set raw [get_property VERILOG_DEFINE $fs]}]} {
        return $defines
    }
    foreach item $raw {
        if {$item eq ""} {
            continue
        }
        lassign [split_name_value $item] name value
        if {$name eq ""} {
            continue
        }
        dict set defines $name $value
    }
    return $defines
}

proc ::tclapp::linty::vivado_to_linty::internal::parse_synth_more_options {more} {

    # Summary: Parse synthesis MORE OPTIONS for defines and generics

    # Argument Usage:
    # more : Value of STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS

    # Return Value:
    # List of a define dictionary and a list of {name value} generics

    set defines [dict create]
    set generics [list]
    if {$more eq ""} {
        return [list $defines $generics]
    }
    if {[catch {set n [llength $more]}]} {
        return [list $defines $generics]
    }
    for {set i 0} {$i < $n} {incr i} {
        set tok [lindex $more $i]
        if {$tok ne "-verilog_define" && $tok ne "-generic"} {
            continue
        }
        incr i
        if {$i >= $n} {
            break
        }
        foreach item [lindex $more $i] {
            if {$item eq ""} {
                continue
            }
            lassign [split_name_value $item] name value
            if {$name eq ""} {
                continue
            }
            if {$tok eq "-verilog_define"} {
                dict set defines $name $value
            } elseif {[string first "=" $item] >= 0} {
                lappend generics [list $name $value]
            }
        }
    }
    return [list $defines $generics]
}

proc ::tclapp::linty::vivado_to_linty::internal::emit_defines {ys defines} {

    # Summary: Write a Yosys read -define command

    # Argument Usage:
    # ys : Open channel for read.ys
    # defines : Dictionary of define names to values

    # Return Value:
    # None

    if {[dict size $defines] == 0} {
        return
    }
    set args [list]
    dict for {name value} $defines {
        if {$value eq ""} {
            lappend args [ys_quote $name]
        } else {
            lappend args [ys_quote "$name=$value"]
        }
    }
    puts $ys "read -define [join $args]"
}

proc ::tclapp::linty::vivado_to_linty::internal::emit_vhdl_lib {ys lib files} {

    # Summary: Write a verific -work command for VHDL library files

    # Argument Usage:
    # ys : Open channel for read.ys
    # lib : VHDL library name
    # files : VHDL files to analyze into that library

    # Return Value:
    # None

    if {[llength $files] == 0} {
        return
    }
    set quoted [list]
    foreach path $files {
        lappend quoted [ys_quote $path]
    }
    puts $ys "verific -work $lib -vhdl93 [join $quoted]"
}

proc ::tclapp::linty::vivado_to_linty::internal::is_default_lib {lib} {

    # Summary: Report whether a library is the Vivado default

    # Argument Usage:
    # lib : Library name

    # Return Value:
    # 1 when lib is xil_defaultlib or work, otherwise 0

    return [expr {
        [string equal -nocase $lib xil_defaultlib] ||
        [string equal -nocase $lib work]
    }]
}

proc ::tclapp::linty::vivado_to_linty::internal::is_global_include {f} {

    # Summary: Report whether a file is a global include

    # Argument Usage:
    # f : File object

    # Return Value:
    # 1 when IS_GLOBAL_INCLUDE is set, otherwise 0

    if {[catch {set value [get_property IS_GLOBAL_INCLUDE $f]}]} {
        return 0
    }
    if {$value eq "1" || [string equal -nocase $value "true"]} {
        return 1
    }
    return 0
}

proc ::tclapp::linty::vivado_to_linty::run {} {

    # Summary: Generate Linty elaboration scripts for the current Vivado project.

    # Argument Usage:

    # Return Value:
    # None. Writes read.ys and hierarchy.ys under .linty/yosys in the parent of the Vivado project directory. Files that are not emitted are printed to the console.

    # Categories: xilinxtclstore, projutils

    if {[catch {current_project} project] || $project eq ""} {
        error "run: no project is open"
    }
    set project_dir [get_property DIRECTORY $project]
    if {$project_dir eq "" || ![file isdirectory $project_dir]} {
        error "run: project directory is not available"
    }
    set base_path [file dirname [file normalize $project_dir]]
    set out_dir [file join $base_path .linty yosys]
    file mkdir $out_dir

    set fs      [current_fileset -srcset]
    set out_ys  [file join $out_dir "read.ys"]

    set files [get_files -compile_order sources -used_in synthesis]

    set ys   [open $out_ys w]

    set n_read 0
    set skipped [list]
    set has_vhdl 0
    set incdirs [list]
    set globals [list]
    set reads [list]

    foreach dir [get_property INCLUDE_DIRS $fs] {
        if {$dir eq ""} {
            continue
        }
        set dir [internal::rel_to $base_path $dir]
        if {$dir ni $incdirs} {
            lappend incdirs $dir
        }
    }

    foreach f $files {
        set path [internal::rel_to $base_path [get_property NAME $f]]
        set typ  [string tolower [get_property FILE_TYPE $f]]
        set lib  [get_property LIBRARY $f]
        if {$lib eq ""} { set lib "xil_defaultlib" }
        set global [internal::is_global_include $f]

        switch -glob -- $typ {
            "verilog header" {
                set dir [file dirname $path]
                if {$dir ni $incdirs} {
                    lappend incdirs $dir
                }
                if {$global && $path ni $globals} {
                    lappend globals $path
                }
            }
            "verilog" - "systemverilog" {
                if {$global} {
                    if {$path ni $globals} {
                        lappend globals $path
                    }
                } else {
                    lappend reads [list sv $lib $path]
                    incr n_read
                }
            }
            "vhdl 2019" {
                lappend reads [list vhdl -vhdl2019 $lib $path]
                set has_vhdl 1
                incr n_read
            }
            "vhdl 2008" {
                lappend reads [list vhdl -vhdl2008 $lib $path]
                set has_vhdl 1
                incr n_read
            }
            "vhdl" {
                lappend reads [list vhdl -vhdl93 $lib $path]
                set has_vhdl 1
                incr n_read
            }
            default {
                lappend skipped [list $lib $typ $path]
            }
        }
    }

    puts $ys "read_verilog -lib +/xilinx/cells_sim.v"
    puts $ys "read_verilog -lib +/xilinx/cells_xtra.v"
    puts $ys "write_verilog -blackboxes xilinx_prims.v"
    puts $ys "design -reset"
    puts $ys "read -sv xilinx_prims.v"

    foreach dir $incdirs {
        puts $ys "read -incdir [internal::ys_quote $dir]"
    }

    set defines [internal::fileset_verilog_defines $fs]
    set generics [list]
    if {![catch {set run [current_run -synthesis]}] && $run ne ""} {
        set more ""
        set props [list_property $run]
        if {{STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} in $props} {
            set more [get_property {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} $run]
        } elseif {STEPS.SYNTH_DESIGN.ARGS.MORE_OPTIONS in $props} {
            set more [get_property STEPS.SYNTH_DESIGN.ARGS.MORE_OPTIONS $run]
        }
        lassign [internal::parse_synth_more_options $more] more_defs more_gens
        dict for {name value} $more_defs {
            dict set defines $name $value
        }
        set generics $more_gens
    }
    internal::emit_defines $ys $defines

    set xpm_sv [internal::xpm_sv_files]
    if {[llength $xpm_sv] == 0} {
        puts "XPM: skipped (sources not found under XILINX_VIVADO)"
    } else {
        set quoted [list]
        foreach path $xpm_sv {
            lappend quoted [internal::ys_quote $path]
        }
        puts $ys "read -sv [join $quoted]"
    }

    if {$has_vhdl} {
        set unisim [internal::unisim_vhd_files]
        if {[llength $unisim] == 0} {
            puts "Xilinx VHDL primitives: skipped (UNISIM packages not found under XILINX_VIVADO)"
        } else {
            internal::emit_vhdl_lib $ys unisim $unisim
        }
        set xpm_vhd [internal::xpm_vhd_files]
        if {[llength $xpm_vhd] == 0} {
            puts "XPM VHDL package: skipped (xpm_VCOMP.vhd not found under XILINX_VIVADO)"
        } else {
            internal::emit_vhdl_lib $ys xpm $xpm_vhd
        }
        set unimacro [internal::unimacro_vhd_files]
        if {[llength $unimacro] == 0} {
            puts "UNIMACRO: skipped (unimacro_VCOMP.vhd not found under XILINX_VIVADO)"
        } else {
            internal::emit_vhdl_lib $ys unimacro $unimacro
        }
    }
    set vlog_libs [list]
    set vhdl_libs [list]
    foreach item $reads {
        set kind [lindex $item 0]
        if {$kind eq "sv"} {
            set lib [lindex $item 1]
            if {![internal::is_default_lib $lib] && $lib ni $vlog_libs} {
                lappend vlog_libs $lib
            }
        } elseif {$kind eq "vhdl"} {
            set lib [lindex $item 2]
            if {![internal::is_default_lib $lib] && $lib ni $vhdl_libs} {
                lappend vhdl_libs $lib
            }
        }
    }
    foreach item $reads {
        set kind [lindex $item 0]
        if {$kind eq "sv"} {
            set lib [lindex $item 1]
            set path [lindex $item 2]
            set parts [list]
            foreach g $globals {
                lappend parts [internal::ys_quote $g]
            }
            lappend parts [internal::ys_quote $path]
            set files [join $parts]
            if {[internal::is_default_lib $lib] && [llength $vlog_libs] == 0} {
                puts $ys "read -sv $files"
            } else {
                set cmd verific
                foreach l $vlog_libs {
                    if {![string equal -nocase $l $lib]} {
                        append cmd " -L [internal::ys_quote $l]"
                    }
                }
                if {![internal::is_default_lib $lib]} {
                    append cmd " -work [internal::ys_quote $lib]"
                }
                puts $ys "$cmd -sv $files"
            }
        } else {
            set flag [lindex $item 1]
            set lib [lindex $item 2]
            set path [lindex $item 3]
            set quoted [internal::ys_quote $path]
            set lflags [list]
            foreach l $vhdl_libs {
                if {![string equal -nocase $l $lib]} {
                    lappend lflags "-L [internal::ys_quote $l]"
                }
            }
            if {[internal::is_default_lib $lib] && [llength $lflags] == 0} {
                puts $ys "read $flag $quoted"
            } else {
                set cmd verific
                if {[llength $lflags] > 0} {
                    append cmd " [join $lflags]"
                }
                if {![internal::is_default_lib $lib]} {
                    append cmd " -work [internal::ys_quote $lib]"
                }
                puts $ys "$cmd $flag $quoted"
            }
        }
    }

    close $ys

    set top [get_property TOP $fs]
    if {$top eq ""} {
        error "run: source fileset has no top"
    }
    set out_hier [file join $out_dir "hierarchy.ys"]
    set hier [open $out_hier w]
    set link_libs $vlog_libs
    foreach l $vhdl_libs {
        if {$l ni $link_libs} {
            lappend link_libs $l
        }
    }
    if {[llength $link_libs] > 0} {
        set import_cmd verific
        foreach l $link_libs {
            append import_cmd " -L [internal::ys_quote $l]"
        }
        append import_cmd " -import"
        foreach generic $generics {
            lassign $generic name value
            append import_cmd " -chparam [internal::ys_quote $name] [internal::ys_chparam_value $value]"
        }
        puts $hier "$import_cmd [internal::ys_quote $top]"
        puts $hier "hierarchy -top [internal::ys_quote $top]"
    } else {
        set hier_cmd "hierarchy -top [internal::ys_quote $top]"
        foreach generic $generics {
            lassign $generic name value
            append hier_cmd " -chparam [internal::ys_quote $name] [internal::ys_chparam_value $value]"
        }
        puts $hier $hier_cmd
    }
    close $hier

    puts "read.ys script: $out_ys ($n_read files, [llength $incdirs] include dirs, [llength $globals] global includes, [dict size $defines] defines)"
    puts "hierarchy script: $out_hier (top $top, [llength $generics] generics)"
    foreach item $skipped {
        lassign $item lib typ path
        puts "skipped: $path ($typ, library $lib)"
    }
}
package provide ::tclapp::linty::vivado_to_linty 1.0
