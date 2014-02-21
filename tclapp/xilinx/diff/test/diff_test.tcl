set file_dir [file dirname [info script]]
puts "== Unit Test directory: $file_dir"
set ::env(XILINX_TCLAPP_REPO) [file normalize [file join $file_dir .. .. ..]]
puts "== Application directory: $::env(XILINX_TCLAPP_REPO)"
lappend auto_path $::env(XILINX_TCLAPP_REPO)

package require ::tclapp::xilinx::diff
namespace import ::tclapp::xilinx::diff::*


# setup
set report [new_report "diff.html" "My Difference Report"]
set of [new_diff "read_checkpoint ${file_dir}/design1.dcp" "read_checkpoint ${file_dir}/design2.dcp" $report]

# lists
diff_lists $of {get_cells -hierarchical} 
diff_lists $of {get_nets -hierarchical}
diff_lists $of {get_clocks}
diff_lists $of {get_ports}

# lists vs reports
diff_lists $of {get_property LOC [lsort [get_cells -hierarchical]]}
diff_reports $of {join [get_property LOC [lsort [get_cells -hierarchical]]] \n}

# reports
diff_reports $of {report_timing -return_string -max_paths 1000} {timing}
diff_reports $of {report_route_status -return_string -list_all_nets}
diff_reports $of {report_route_status -return_string -of_objects [get_nets]}

# properties
diff_props $of {lrange [get_cells -hierarchical] 0 9999}
diff_props $of {lrange [get_cells -hierarchical] 10000 19999}
diff_props $of {get_timing_paths -max_paths 1000}

# multi-line capable
diff_lists $of {
	set paths [get_timing_paths -max_paths 1000]
	return [get_property SLACK [lsort $paths]]
}

diff_lists $of {
	set cells [get_cells -hierarchical]
	return [get_property LOC [lsort $cells]]
} 

diff_reports $of {
	set nets [get_nets]
	set subset_nets [lrange $nets 0 10]
	return [list [report_route_status -return_string -of_objects [get_nets $subset_nets]]]
} 

diff_props $of {
	set paths [get_timing_paths -max_paths 1000]
	return $paths
}

# clean-up
#diff_close_designs $of
delete $of
