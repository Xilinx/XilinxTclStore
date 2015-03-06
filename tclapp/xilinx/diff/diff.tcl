#
# diff.tcl (allow Tcl to find tclindex and provide package version 2.1)
# 

namespace eval ::tclapp::xilinx::diff {
  
  # Allow Tcl to find tclIndex
  variable home [file join [pwd] [file dirname [info script]]]
  if {[lsearch -exact $::auto_path $home] == -1} {
    lappend ::auto_path $home
  }
}
package provide ::tclapp::xilinx::diff 2.3
