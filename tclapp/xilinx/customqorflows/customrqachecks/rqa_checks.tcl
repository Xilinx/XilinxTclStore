###########################################################################
##
## RQA checks creation and management for customqorflows
##
###########################################################################

package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::customqorflows {
	set this_file [file normalize [info script]]
	set this_dir  [file dirname $this_file]

	foreach tcl_file [lsort [glob -nocomplain -directory $this_dir *.tcl]] {
		if {[file normalize $tcl_file] eq $this_file} {
			continue
		}
		source $tcl_file
	}
}
