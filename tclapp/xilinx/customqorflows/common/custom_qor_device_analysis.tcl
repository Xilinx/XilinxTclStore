####################################################################################
#
# custom_qor_device_analysis.tcl (customqorflows device analysis utilities)
#
# Script created on 03/30/2026 by Madhur Chhabra, AMD
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::customqorflows {
	
}


namespace eval ::tclapp::xilinx::customqorflows  {

	proc check_pblock_capacity {range cells {max_util_pct 100} {label ""} {debug 0}} {
		# Summary:
		# Performs a what-if report_utilization -evaluate_pblock dry-run against a scratch pblock
		# covering $range, hypothetically populated with $cells, and reports whether every
		# resource type (Site Type row) stays at or under $max_util_pct. The scratch pblock is
		# always deleted before returning - no permanent side effects on the live design.
		#
		# Argument Usage:
		# range - Pblock range string, e.g. "CLOCKREGION_X0Y4:CLOCKREGION_X0Y4" (the exact format
		#   returned by get_floorplan)
		# cells - List of cell names or cell objects to hypothetically assign
		# max_util_pct - Maximum allowed Util% per resource row before it is flagged (default 100)
		# label - Optional human-readable tag folded into the scratch pblock name for debug
		#   traceability (default "")
		# debug - 1 for debug prints (default 0)
		#
		# Return Value:
		# dict with keys:
		#   OK - 1 if every resource row's Util% <= max_util_pct and no internal error occurred,
		#     0 otherwise (over-capacity OR internal error - always treated as "does not fit")
		#   OVERFLOW - dict keyed by Site Type, each value a dict {USED u AVAILABLE a UTIL_PCT p},
		#     populated only for rows exceeding max_util_pct (empty if OK==1 or on error)
		#   ERROR - "" normally; non-empty Tcl error text if create_pblock/resize_pblock/
		#     report_utilization/parsing threw an exception (caller must treat as OK==0)
		#
		set OK 1
		set OVERFLOW [dict create]
		set ERR ""

		# Deterministic, collision-free scratch pblock name. Never matches the real suggestion
		# names (pb_single_cr_*/pb_row_cr_*/pb_slr_side_*) so it can never trip a later
		# "suggestion already exists as pblocks" early-exit check.
		if {![info exists ::tclapp::xilinx::customqorflows::scratch_pblock_ctr]} {
			set ::tclapp::xilinx::customqorflows::scratch_pblock_ctr 0
		}
		incr ::tclapp::xilinx::customqorflows::scratch_pblock_ctr
		set safe_label [string map {" " "_" "/" "_" ":" "_"} $label]
		set scratch_name "RQS_SCRATCH_PBLOCK_${safe_label}_${::tclapp::xilinx::customqorflows::scratch_pblock_ctr}"

		if {[catch {
			set cell_objs [get_cells -quiet $cells]
			if {[llength $cell_objs] == 0} {
				error "No resolvable cells passed to check_pblock_capacity (input: $cells)"
			}
			create_pblock $scratch_name
			resize_pblock -add $range $scratch_name
			set rpt [report_utilization -evaluate_pblock -pblocks $scratch_name -cells $cell_objs \
				-return_string -no_primitives -quiet]
		} create_err]} {
			set OK 0
			set ERR "check_pblock_capacity: evaluate_pblock failed for $scratch_name ($range): $create_err"
			if {$debug == 1} {puts "-D: $ERR"}
		} else {
			# Every resource-bearing table in report_utilization -evaluate_pblock output. Table
			# names are intentionally unqualified (no leading "N. ") since numbering shifts by
			# device family/Vivado version; build_data_from_report_table's unanchored scan
			# self-corrects past the Table of Contents listing to the real, dash-underlined header.
			set candidate_tables {"Netlist Logic" "BLOCKRAM" "ARITHMETIC" "CLOCK" "ADVANCED"}
			foreach table_name $candidate_tables {
				set tdata [::tclapp::xilinx::customqorflows::build_data_from_report_table $rpt $table_name ""]
				if {[dict size $tdata] == 0} {continue}
				foreach site_type [dict keys $tdata] {
					set row [dict get $tdata $site_type]
					if {![dict exists $row {Util%}]} {continue}
					set util_str [dict get $row {Util%}]
					if {![string is double -strict $util_str]} {continue}
					if {$util_str > $max_util_pct} {
						set used ""
						set available ""
						if {[dict exists $row Used]} {set used [dict get $row Used]}
						if {[dict exists $row Available]} {set available [dict get $row Available]}
						dict set OVERFLOW $site_type [dict create USED $used AVAILABLE $available UTIL_PCT $util_str]
					}
				}
			}
			if {[dict size $OVERFLOW] > 0} {set OK 0}
		}

		# Cleanup always runs, independent of the outcome above, so a failed check never leaves
		# a stray scratch pblock behind in the live design.
		if {[catch {delete_pblocks -quiet $scratch_name} del_err]} {
			puts "-E: check_pblock_capacity failed to remove scratch pblock $scratch_name: $del_err"
		}

		if {$debug == 1} {
			puts "-D: check_pblock_capacity $scratch_name range=$range max_util_pct=$max_util_pct OK=$OK OVERFLOW=$OVERFLOW ERROR={$ERR}"
		}
		return [dict create OK $OK OVERFLOW $OVERFLOW ERROR $ERR]
	}

}
