# Tcl App Initialization
# 
# - source all Tcl files in this directory
# - all namespace exported procs are registered with Vivado

namespace eval ::tclapp::support::appinit {}

proc ::tclapp::support::appinit::load_app {repo app {ns ""}} {

    # Summary: Load the argument app in Vivado

    # Argument Usage:
    # repo: Full path to repo
    # app: Full name of app to load, e.g. ::tclapp::xilinx::diff
    # [ns=]: Namespace into which the app should be registered

    # Return Value:
    # List of app procs that were registered with Vivado

    if {[lsearch -exact $::auto_path $repo] == -1} {
      lappend ::auto_path $repo
    }

    set slave [interp create]

    $slave eval {

        # temporary variables 
        namespace eval ::tcl {
            variable repo
            variable app
            variable procs
        }

    }

    $slave eval [list set ::tcl::repo $repo ]
    $slave eval [list set ::tcl::app $app ]

    $slave eval {

        set tcl::procs {}

        # Stub out package to avoid processing embedded package require
        rename package __package_orig
        proc package {what args} {
            switch -- $what {
                require { return }
                default { __package_orig $what {*}$args }
            }
        }

        # Stub out namespace to capture all 'namespace export'
        rename namespace __namespace_orig
        proc namespace {what args} {
            switch -- $what {
                export {
                    foreach cmd $args {
                        lappend ::tcl::procs $cmd
                    }
                }
                default { __namespace_orig $what {*}$args }
            }
        }

        # Sbut out unknown 
        proc tclPkgUnknown args {}
        package unknown tclPkgUnknown
        proc unknown {args} {}

        # Require the app
        package require $::tcl::app

        # What dir 
        set dir [file join $::tcl::repo {*}[regsub -all "::" $::tcl::app " "]]

        foreach file [glob -directory $dir -tails -types {r f} *.tcl] {
            if {$file eq "pkgIndex.tcl"} {
                continue
            }
            if {$file eq "tclIndex.tcl"} {
                continue
            }
            
            # evaluate source in calling context otherwise procs would be
            # registered inside appinit namespace unless prefixed with "::"
            source [file join $dir $file]
        }
    }

    # The list of explicitly exported procs from $app
    set procs [$slave eval set ::tcl::procs]
    interp delete $slave

    # Now register the exported app procs with Vivado
    package require $app

    foreach p $procs {

        set origname $app
        append origname :: $p

        set newname $ns
        append newname :: $p

        uplevel 1 rdi::register_proc -quiet $origname $newname

    }

    return $procs
}

proc ::tclapp::support::appinit::unload_app {app ns} {

    # Summary: Unload the argument app from Vivado
    
    # Argument Usage:
    # app: Full name of app to unload, e.g. ::tclapp::xilinx::diff
    # ns: Namespace in which the app is registered

    # Return Value:
    # Nothing

    # Find the app procs known to Tcl
    set pattern $app
    append pattern :: *
    set appprocs [info commands $pattern]

    append app ::
    foreach cmd $appprocs {
        # name of app proc without the namespace
        set procnm [regsub $app $cmd ""]

        # name of app proc if registered in vivado
        set vvnm $ns
        append vvnm :: $procnm

        # now unregister allow for errors
        if {[catch {rdi::unregister_proc $vvnm} result]} {
            # ignore errors
        }
    }
}

proc ::tclapp::support::appinit::app_procs {app ns} {

    # Summary: List currently registered procs for app
    
    # Argument Usage:
    # app: Full name of app to list registered procs
    # ns: Namespace in which the app is registered

    # Return Value:
    # List of Vivado commands associated with the app

    # Find the app procs known to Tcl
    set pattern $app
    append pattern :: *
    set appprocs [info commands $pattern]

    # Accumulate a list of app corresponding vv commands
    set vvcmds {}
    append app ::
    foreach cmd $appprocs {
        # name of app proc without the namespace
        set procnm [regsub $app $cmd ""]

        # name of app proc if registered in vivado
        set vvnm $ns
        append vvnm :: $procnm
        set infocmd [uplevel 1 info commands $vvnm]
        if {$infocmd != ""} {
            lappend vvcmds $infocmd
        }
    }

    return $vvcmds
}

package provide ::tclapp::support::appinit 1.1
