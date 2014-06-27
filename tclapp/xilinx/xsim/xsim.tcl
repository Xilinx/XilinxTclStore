#######################################################################
#
# xsim.tcl (allow Tcl to find tclindex and provide package version 1.1)
#
#######################################################################
namespace eval ::tclapp::xilinx::xsim {
  variable home [file join [pwd] [file dirname [info script]]]
  if {[lsearch -exact $::auto_path $home] == -1} {
    lappend ::auto_path $home
  }
}
package provide ::tclapp::xilinx::xsim 1.1
