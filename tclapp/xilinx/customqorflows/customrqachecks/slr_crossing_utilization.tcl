####################################################################################
#
# slr_crossing_utilization.tcl (customqorflows RQA check for SLR crossing utilization)
#
# Script created on 03/30/2026 by Madhur Chhabra, AMD
#
####################################################################################

package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::customqorflows {
	#namespace export slr_crossing_utilization
}

namespace eval ::tclapp::xilinx::customqorflows {

	proc slr_crossing_utilization {args} {
		# Summary:
		# Analyze inter-SLR SLL usage from utilization data and flag REVIEW when
		# the number of crossings above a configurable usage threshold exceeds the threshold limit.

		# Argument Usage:
		# args: Optional list from Custom QoR Tools. The proc expects at most one positional entry.
		# [lindex $args 0] = qor_dict (dict): Parameter override dictionary consumed by
		#   ::tclapp::xilinx::customqorflows::update_params PARAMS $qor_dict.
		#   Supported override keys used by this proc:
		#   - THRESHOLD (Default: 0): Maximum allowed count of crossings at/above USAGE_THRESHOLD.
		#   - USAGE_THRESHOLD (Default: 85.0): Percent-used cutoff per SLR crossing.
		#   - DEBUG (Default: 0): Enables debug prints.
		# Any additional args entries beyond index 0 are unexpected and only emit an error print.

		# Return Value:
		# dict containing assessment output fields:
		#   Threshold, Actual, Used, Available, Score, Status, Summary, Detailed_Table.
		# Status is REVIEW when Actual > THRESHOLD, otherwise OK.

		# Categories: xilinxtclstore, customqorflows

		# Description:
		# ============
		#
		# This TCL script is a Report QoR Assessment (RQA) check designed to assess the usage of inter-SLR connections in multi-SLR FPGA devices.
		# For each crossing between two SLRs, it checks the usage of the SLL lines that connect between the SLRs. It will flag REVIEW to a user when the number of SLR crossings exceeding the USAGE_THRESHOLD is higher than the THRESHOLD value.
		# 
		# Thresholds are configurable at check registration time by registering new values for the following PARAMS
		# 1. USAGE_THRESHOLD - Percentage value representing the number of lines in use between two SLRs
		# 2. THRESHOLD - The number of SLRs that exceed the usage threshold
		# 
		# For different families with different threshold values, a new check should be created for each family.
		#
		# A detailed table is returned that contains individual SLL usage statistics for each SLR crossing.
		#
		# RQA Check Registration Requirements:
		# ====================================
		# `NEEDS_UTILIZATION_DATA` - 1
		# `DESIGN_STAGE` - [list "fully placed" "routed" "physopt postroute"]
		# `DEVICE_SUPPORT`- Conceptually supports `[get_parts -filter {SLRS>1}]` (any parts with number of SLRs > 1), but registration example shows `[list versal]` for specific device targeting
		# `CATEGORY` - Utilization
		#
		set start [clock seconds]

		# Start of content
		# ================

		# Tuning parameters
		set PARAMS(THRESHOLD) 0
		set PARAMS(USAGE_THRESHOLD) 85.0
		set PARAMS(DEBUG) 0

		# Extract dictionary from input
		set qor_dict ""
		if {$args ne ""} {
			for {set i 0} {$i < [llength $args]} {incr i} {
				set arg [lindex $args $i]
				if {$i == 0} {set qor_dict $arg}
				if {$i != 0} {puts "-E: Not expecting this arg from QoR tools"}
			}
		}
		
		::tclapp::xilinx::customqorflows::update_params PARAMS $qor_dict
		# DEBUG
		set debug $PARAMS(DEBUG)
		if {$debug} {puts "-D: Running in debug mode"}
	
		# Variables
		set status "OK"
		set actual 0
		set detailed_table ""
		set usage_threshold $PARAMS(USAGE_THRESHOLD)

		# Extract from RQA provided qor_dict dictionary. 
		set util_dict [dict get $qor_dict UTILIZATION]
		#set util_dict [dict get $util_dict_top TOP]

		if {$debug} {
			puts "-D: Printing qor_dict contents:"
			::tclapp::xilinx::customqorflows::print_dict $qor_dict
		}


		lappend detailed_table [list {SLR Crossing} {Used} {Available} {% Used}]
		if {[llength [dict keys $util_dict SLL_*]] > 0} {
			set slrs [get_slrs]
			for {set i 0} {$i < [llength $slrs]-1} {incr i} {
				set slr_1 [lindex $slrs $i]
				for {set j [expr ${i}+1]} {$j < [llength $slrs]} {incr j} {
					set slr_2 [lindex $slrs $j]
					# Check Algorithm
					set key_1 SLL_${slr_1}-${slr_2} 
					set key_2 SLL_${slr_2}-${slr_1} 
					set used 0
					if {[dict exists $util_dict $key_1] || [dict exists $util_dict $key_2]} {
						foreach key [list $key_1 $key_2] {
							if {[dict exists $util_dict $key]} {
								set res_dict [dict get $util_dict $key]
								set values [split $res_dict :]
								incr used [lindex $values 0]
								set total [lindex $values 1]
							}
						}
						set pc_used [string range [expr (${used}/${total})*100.0] 0 4]
						lappend detailed_table [list ${slr_1}-${slr_2} $used $total $pc_used]
						if {$pc_used >= $usage_threshold} {
							if {$debug == 1} {puts "-D: slr ${slr_1}-${slr_2} - pc used : $pc_used"}
							incr actual
						}
					}
				}   
			}
		} else {
			set actual -
			set pc_used -
			set used -
			set avail -
		}

		if {$actual > $PARAMS(THRESHOLD)} {set status "REVIEW"}
		
		# End of suggestion content
		# =========================
		set stop [clock seconds]
		::tclapp::xilinx::customqorflows::compile_time $start $stop 
		return [dict create Threshold $PARAMS(THRESHOLD) \
							Actual $actual \
							Used - \
							Available - \
							Score "" \
							Status $status \
							Summary "SLR Crossings > ${usage_threshold}% Usage" \
							Detailed_Table $detailed_table]

	}
	
	set id RQA_AMD_NETLIST-14
	catch "delete_qor_checks -type assessment $id -quiet"
	set rule_body ::tclapp::xilinx::customqorflows::slr_crossing_utilization
	set prop_vals [list CATEGORY Utilization \
						SUMMARY "SLR Crossings with high SLLs usage" \
						DESCRIPTION "SLR Crossings with high SLLs usage" \
						APPLICABLE_FOR place_design \
						PARAMS [dict create DEBUG 0 THRESHOLD 0 USAGE_THRESHOLD 85.0 NEEDS_UTILIZATION_DATA 1 NO_PBLOCK_CHECK 1 NO_SLR_CHECK 1] \
						]
	create_qor_check -name $id -rule_body $rule_body -type assessment -property_values $prop_vals 
	
}






