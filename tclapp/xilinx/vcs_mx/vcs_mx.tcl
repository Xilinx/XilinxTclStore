#######################################################################
#
# vcs_mx.tcl (allow Tcl to find tclindex and provide package version 1.0)
#
#######################################################################
namespace eval ::tclapp::xilinx::vcs_mx {
  variable home [file join [pwd] [file dirname [info script]]]
  if {[lsearch -exact $::auto_path $home] == -1} {
    lappend ::auto_path $home
  }
}
package provide ::tclapp::xilinx::vcs_mx 1.0
