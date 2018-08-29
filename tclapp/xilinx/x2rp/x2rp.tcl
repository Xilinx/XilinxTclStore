package require Tcl 8.5

namespace eval ::tclapp::xilinx::x2rp {

  # Allow tcl to find the tclIndex
  variable home [file join [pwd] [file dirname [info script]]]
  if {[lsearch -exact $::auto_path $home] == -1} {
    lappend ::auto_path $home
  }
}

package provide ::tclapp::xilinx::x2rp 1.5