####################################################################################################
# Company:        Xilinx, Inc.
# Created by:     Nik Cimino
# 
# Created Date:   06/01/12
# Script name:    diff.tcl
# Classes:        html, report, design, diff
# Procedures:     new_report, new_diff, diff_lists, diff_reports, diff_props, diff_close_designs
# Tool Versions:  Vivado 2012.2
# Description:    This script is used to compare 2 designs that have been loaded into memory.
# Dependencies:   struct package
#                 stooop package
# Notes:          
#     For more information on STOOOP visit: http://wiki.tcl.tk/2165 
#     For more information on STRUCT visit: http://tcllib.sourceforge.net/doc/struct_set.html
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
#
####################################################################################################


# title: Vivado Design Differencing


package require Tcl 8.5
package require struct::set 2.2.3
package require struct::list 1.7
package require stooop 4

namespace eval ::tclapp::xilinx::diff {

    # Allow Tcl to find tclIndex
    variable home [file join [pwd] [file dirname [info script]]]
    if {[lsearch -exact $::auto_path $home] == -1} {
	lappend ::auto_path $home
    }

}

package provide ::tclapp::xilinx::diff 1.2
