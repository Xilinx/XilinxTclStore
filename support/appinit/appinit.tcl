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
    # Need to forget the package first in case version conflict
    package forget $app
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

    # save app to app_orig
    set app_orig $app

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
    package forget $app_orig
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



# 'app': must have the format ::tclapp::<company>::<app>
# For example:
#  vivado% ::tclapp::support::appinit::get_app_procs /wrk/hdstaff/dpefour/support/TclApps/XilinxTclStore ::tclapp::xilinx::designutils

proc ::tclapp::support::appinit::get_app_procs {repo app} {

  # Summary: Load the argument app in Vivado

  # Argument Usage:
  # repo: Full path to repo
  # app: Full name of app to load, e.g. ::tclapp::xilinx::designutils

  # Return Value:
  # List of app procs that were registered with Vivado

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

    foreach file [glob -nocomplain -directory $dir -tails -types {r f} *.tcl] {
      if {$file eq "pkgIndex.tcl"} {
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

  return [lsort $procs]
}


# For example:
#   vivado% ::tclapp::support::appinit::get_proc_metacomment ::tclapp::xilinx::ultrafast report_reset_signals
#   vivado% ::tclapp::support::appinit::get_proc_metacomment ::tclapp::xilinx::ultrafast report_reset_signals {argument usage}
#   vivado% ::tclapp::support::appinit::get_proc_metacomment ::tclapp::xilinx::ultrafast report_reset_signals {description}

proc ::tclapp::support::appinit::get_proc_metacomment {app procName {metacomment {}}} {

  # Summary: Return the metacomment for a specific app/proc

  # Argument Usage:
  # app: Full name of app to load, e.g. ::tclapp::xilinx::designutils
  # procName: Proc name, e.g. write_template
  # metacomment: Metacomment, e.g. Summary, Argument Usage, Return Value or Categories

  # Return Value:
  # Extracted metacomment(s) from proc


  set doc {}
  set procName [format {%s::%s} $app $procName]
  if {[info proc $procName] ne $procName} { return {} }
  # reports a proc's args and leading comments.
  # Multiple documentation lines are allowed.
  set res {}
  set section {}
  catch {unset results}
  # This comment should not appear in the metacomment
  foreach line [split [uplevel 1 [list info body $procName]] \n] {
      if {[string trim $line] eq ""} continue
      # Skip comments that have been added to support rdi::register_proc command
      if {[regexp -nocase -- {^\s*#\s*(Summary|Argument Usage|Return Value|Categories)\s*\:\s*(.*)\s*$} $line -- match msg]} {
        if {$section != {}} {
          set results([string tolower $section]) $res
          set res {}
        }
        set section $match
        if {[regexp {^\s*$} $msg]} { set res {} } else { set res [list $msg] }
        continue
      }
     if {![regexp {^\s*#(.+)} $line -> line]} break
      lappend res [string trim $line]
  }
  if {$section != {}} {
    set results([string tolower $section]) $res
  }
  if {$metacomment != {}} {
    set metacomment [string tolower $metacomment]
    if {[info exists results($metacomment)]} {
      set doc [join $results($metacomment) " \n"]
    } else {
      set doc {}
    }
  } else {
    set doc [array get results]
  }
  return $doc
}

package provide ::tclapp::support::appinit 1.1
