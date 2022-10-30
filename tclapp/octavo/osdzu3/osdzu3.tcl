#
# octavo.tcl (allow Tcl to find tclindex and provide package)
# 

namespace eval ::tclapp::octavo::osdzu3 {
  
  # Allow Tcl to find tclIndex
  variable home [file join [pwd] [file dirname [info script]]]
  if {[lsearch -exact $::auto_path $home] == -1} {
    lappend ::auto_path $home
  }
}
package provide ::tclapp::octavo::osdzu3 1.0
