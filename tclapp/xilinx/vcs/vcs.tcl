#######################################################################
#
# vcs.tcl (allow Tcl to find tclindex and provide package version 1.0)
#
#######################################################################
namespace eval ::tclapp::xilinx::vcs {
  variable home [file join [pwd] [file dirname [info script]]]
  if {[lsearch -exact $::auto_path $home] == -1} {
    lappend ::auto_path $home
  }
}
package provide ::tclapp::xilinx::vcs 1.1
