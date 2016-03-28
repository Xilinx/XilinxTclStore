###########################################################################
#
# questa.tcl (allow Tcl to find tclindex and provide package this version)
#
###########################################################################
namespace eval ::tclapp::xilinx::questa {
  variable home [file join [pwd] [file dirname [info script]]]
  if {[lsearch -exact $::auto_path $home] == -1} {
    lappend ::auto_path $home
  }
}
package provide ::tclapp::xilinx::questa 1.92
