###########################################################################
#
# riviera.tcl
#
# based on XilinxTclStore\tclapp\xilinx\modelsim\modelsim.tcl
#
###########################################################################

namespace eval ::tclapp::aldec::riviera {
  variable home [file join [pwd] [file dirname [info script]]]
  if {[lsearch -exact $::auto_path $home] == -1} {
    lappend ::auto_path $home
  }
}
package provide ::tclapp::aldec::riviera 1.3
