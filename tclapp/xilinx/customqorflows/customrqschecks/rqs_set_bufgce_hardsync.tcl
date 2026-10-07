####################################################################################
#
# rqs_set_bufgce_hardsync.tcl (customqorflows BUFGCE/MBUFGCE HARDSYNC suggestion)
#
# Script created on 03/30/2026 by Madhur Chhabra, AMD
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::customqorflows {
	#namespace export rqs_set_bufgce_hardsync
}

namespace eval ::tclapp::xilinx::customqorflows {

	proc rqs_set_bufgce_hardsync {args} {
		# Description:
		# Converts clock enables on BUFGCE/MBUFGCE from SYNC to HARDSYNC.
		#
		# Applicable for: place_design
		# Returns: set_property CE_TYPE HARDSYNC [get_cells ...] command.

		set start [clock seconds]

		# Extract dictionary from input
		set qor_dict ""
		if {$args ne ""} {
			for {set i 0} {$i < [llength $args]} {incr i} {
				set arg [lindex $args $i]
				if {$i == 0} {set qor_dict $arg}
				if {$i != 0} {puts "-E: Not expecting this arg from QoR tools"}
			}
		}

		# Keep pattern consistent with other custom suggestions.
		set PARAMS(DEBUG) 0
		::tclapp::xilinx::customqorflows::update_params PARAMS $qor_dict
		set debug $PARAMS(DEBUG)
		set command ""

		set target_objs [get_cells -quiet -hier -filter {(REF_NAME =~ BUFGCE || REF_NAME =~ MBUFGCE) && CE_TYPE == SYNC}]
		if {[llength $target_objs] == 0} {
			if {$debug == 1} {puts "-D: No BUFGCE/MBUFGCE cells found with CE_TYPE=SYNC"}
			return
		}

		if {[llength $target_objs] == 1} {
			foreach cell_name [lsort $target_objs] {
				set one_cmd "set_property CE_TYPE HARDSYNC \[get_cells \{ $cell_name \}\]"
				set command "${command}\n${one_cmd}\n"
			}
		} else {
			set command [::tclapp::xilinx::customqorflows::pretty_command_property CE_TYPE HARDSYNC $target_objs]
		}

		set stop [clock seconds]
		::tclapp::xilinx::customqorflows::compile_time $start $stop "" RQS_SET_BUFGCE_HARDSYNC

		return [dict create COMMAND $command]
	}

	proc register_rqs_set_bufgce_hardsync_checks {} {
		# The following sets up the suggestion in the Custom QoR Tools.
		# ==================================================
		set id RQS_AMD_NETLIST-2
		set description "Set CE_TYPE to HARDSYNC on BUFGCE/MBUFGCE cells currently using SYNC."
		set auto 1
		set category netlist
		set applicable_for place_design
		set needs_timing_data 0
		set params [list DEBUG 0]

		catch "delete_qor_check ${id} -quiet"
		create_qor_check -name ${id} -rule_body ::tclapp::xilinx::customqorflows::rqs_set_bufgce_hardsync \
			-property_values [list DESCRIPTION $description \
							   AUTO $auto \
							   CATEGORY $category \
							   APPLICABLE_FOR $applicable_for\
							   NEEDS_TIMING_DATA $needs_timing_data \
							   PARAMS $params \
							   ]
	}

	register_rqs_set_bufgce_hardsync_checks
}
