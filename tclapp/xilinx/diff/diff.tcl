#######################################################################
#
# diff.tcl (allow Tcl to find tclindex and provide package version 1.0)
#
#######################################################################

# 
# Getting Started:
#     % package require ::tclapp::xilinx::diff
#     % namespace import ::tclapp::xilinx::diff::* 
#     % set report [new_report "diff.html" "Difference Report"]
#     % set of [new_diff {read_checkpoint design1.dcp} {read_checkpoint design2.dcp} $report]
#     % diff_lists $of {get_cells -hierarchical} 
#     % diff_reports $of {report_timing -return_string}
#     % diff_props $of {get_timing_paths}
#     % diff_close_designs $of
#     % delete $of

package require Tcl 8.5
package require struct::set 2.2.3
package require struct::list 1.7
package require stooop 4
namespace eval ::tclapp::xilinx::diff {
  variable home [file join [pwd] [file dirname [info script]]]
  if {[lsearch -exact $::auto_path $home] == -1} {
    lappend ::auto_path $home
  }
}
package provide ::tclapp::xilinx::diff 1.2
