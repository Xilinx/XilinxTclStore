####################################################################################
#
# bli_flop_io.tcl (customqorflows BLI flop IO suggestion)
#
# Script created on 03/30/2026 by Madhur Chhabra, AMD
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::customqorflows {
	#namespace export bli_flop_io
}

namespace eval ::tclapp::xilinx::customqorflows {

	proc bli_flop_io {args} {
		# Description:
		# This proc identifies critical flop-to-IO paths and sets BLI=TRUE on
		# qualifying source flops. A flop qualifies when:
		#   1. It is the source of a critical path whose destination is an IO.
		#   2. The pre-path slack to the flop (timing margin arriving at the flop)
		#      is greater than the configured margin threshold (default 2.0 ns).
		#   3. The flop is within an acceptable clock region distance from the IO
		#      (Manhattan distance in clock regions, scaled by pre-path slack).
		#
		# Applicable for: place_design
		# Returns: set_property BLI TRUE commands for qualifying flops.

		set start [clock seconds]

		# PARAMS
		set PARAMS(MAX_PATHS) 1000
		set PARAMS(SLACK_THRESHOLD) -0.100
		set PARAMS(MARGIN_THRESHOLD) 2.0
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

		# Update any params registered with the check
		::tclapp::xilinx::customqorflows::update_params PARAMS $qor_dict

		# Initialize variables
		set debug $PARAMS(DEBUG)
		set command ""
		set bli_flops [list]

		# STEP 1: Find critical paths with negative slack
		# ===============================================
		set critical_paths [get_timing_paths -quiet \
			-max_paths $PARAMS(MAX_PATHS) \
			-slack_lesser_than $PARAMS(SLACK_THRESHOLD)]

		if {[llength $critical_paths] == 0} {
			if {$debug == 1} {puts "-D: No critical paths found"}
			set stop [clock seconds]
			::tclapp::xilinx::customqorflows::compile_time $start $stop "" BLI_FLOP_IO
			return
		}
		if {$debug == 1} {puts "-D: Found [llength $critical_paths] critical paths"}

		# STEP 2: Evaluate each path for flop-to-IO
		# ==========================================
		foreach path $critical_paths {
			set startpoint_pin [get_property -quiet STARTPOINT_PIN $path]
			set endpoint_pin [get_property -quiet ENDPOINT_PIN $path]
			set path_slack [get_property -quiet SLACK $path]
			if {$debug == 1} {puts "-D: Processing path: $path (startpoint=$startpoint_pin, endpoint=$endpoint_pin, slack=$path_slack)"}

			# Check endpoint is an IO port
			set io_port [get_ports -quiet $endpoint_pin]
			if {$io_port eq ""} {
				if {$debug == 1} {puts "-D: Endpoint is not an IO port, skipping path"}
				continue
			}

			# Get source cell from startpoint pin
			set src_cell [get_cells -quiet -of [get_pins -quiet $startpoint_pin]]
			if {$src_cell eq ""} {
				if {$debug == 1} {puts "-D: Could not find source cell for startpoint pin $startpoint_pin, skipping"}
				continue
			}

			# Skip if already processed
			if {[lsearch -exact $bli_flops $src_cell] != -1} {
				if {$debug == 1} {puts "-D: Flop $src_cell already processed, skipping"}
				continue
			}

			# Verify source is a register (flop)
			set prim_group [get_property -quiet PRIMITIVE_GROUP $src_cell]
			if {$prim_group ne "REGISTER"} {
				if {$debug == 1} {puts "-D: Source cell $src_cell is not a REGISTER (PRIMITIVE_GROUP=$prim_group), skipping"}
				continue
			}

			# STEP 2a: Check pre-path margin to the flop
			# ===========================================
			# Report timing TO the flop to check how much slack margin exists
			# arriving at this flop from its upstream logic.
			set clk_pin [get_pins -quiet -of $src_cell -filter {REF_PIN_NAME == C || REF_PIN_NAME == CLK}]
			if {$clk_pin eq ""} {
				if {$debug == 1} {puts "-D: No clock pin (C/CLK) found on $src_cell, skipping"}
				continue
			}
			set d_pin [get_pins -quiet -of $src_cell -filter {REF_PIN_NAME == D}]
			if {$d_pin eq ""} {
				if {$debug == 1} {puts "-D: No D pin found on $src_cell, skipping"}
				continue
			}

			set pre_path [get_timing_paths -quiet -to $d_pin -max_paths 1]
			if {[llength $pre_path] == 0} {
				if {$debug == 1} {puts "-D: No pre-path timing found for $src_cell, skipping"}
				continue
			}

			set pre_slack [get_property -quiet SLACK $pre_path]
			if {$pre_slack eq ""} {
				if {$debug == 1} {puts "-D: Could not get SLACK property from pre-path for $src_cell, skipping"}
				continue
			}

			if {$pre_slack < $PARAMS(MARGIN_THRESHOLD)} {
				if {$debug == 1} {puts "-D: Pre-path slack $pre_slack < $PARAMS(MARGIN_THRESHOLD) for $src_cell, skipping"}
				continue
			}
			if {$debug == 1} {puts "-D: Pre-path margin OK: $pre_slack ns for $src_cell"}

			# STEP 2b: Check clock region distance from flop to IO
			# ====================================================
			# Compute the Manhattan distance in clock regions between the flop and the IO port.
			set io_loc [get_property -quiet LOC $io_port]
			set flop_loc [get_property -quiet LOC $src_cell]

			set flop_cr [get_clock_regions -quiet -of [get_sites -quiet $flop_loc]]
			set io_cr [get_clock_regions -quiet -of [get_sites -quiet $io_loc]]

			if {$flop_cr eq "" || $io_cr eq ""} {
				if {$debug == 1} {puts "-D: Could not determine clock regions for $src_cell, skipping"}
				continue
			}

			# Parse clock region coordinates (e.g. X0Y1)
			if {![regexp {X(\d+)Y(\d+)} $flop_cr -> flop_cr_x flop_cr_y] ||
				![regexp {X(\d+)Y(\d+)} $io_cr -> io_cr_x io_cr_y]} {
				if {$debug == 1} {puts "-D: Could not parse clock region coordinates for $src_cell, skipping"}
				continue
			}

			set cr_distance [expr {abs($flop_cr_x - $io_cr_x) + abs($flop_cr_y - $io_cr_y)}]

			# Scale allowed CR distance based on pre-path slack: higher slack = more distance allowed
			# pre_slack >= 5.0 -> max 5 CR, >= 4.0 -> 4, >= 3.0 -> 3, >= 2.5 -> 2, else -> 1
			if {$pre_slack >= 5.0} {
				set allowed_cr_distance 5
			} elseif {$pre_slack >= 4.0} {
				set allowed_cr_distance 4
			} elseif {$pre_slack >= 3.0} {
				set allowed_cr_distance 3
			} elseif {$pre_slack >= 2.5} {
				set allowed_cr_distance 2
			} else {
				set allowed_cr_distance 1
			}

			if {$cr_distance > $allowed_cr_distance} {
				if {$debug == 1} {puts "-D: CR distance $cr_distance > allowed $allowed_cr_distance (pre_slack=$pre_slack) for $src_cell (flop_cr=$flop_cr, io_cr=$io_cr), skipping"}
				continue
			}
			if {$debug == 1} {puts "-D: Distance OK: CR distance $cr_distance <= allowed $allowed_cr_distance (pre_slack=$pre_slack) for $src_cell (flop_cr=$flop_cr, io_cr=$io_cr)"}

			# All conditions met - add flop to BLI list
			lappend bli_flops $src_cell
			if {$debug == 1} {puts "-D: Qualifying flop: $src_cell (pre_slack=$pre_slack, cr_distance=$cr_distance)"}
		}

		# STEP 3: Generate BLI property commands
		# =======================================
		if {[llength $bli_flops] == 0} {
			if {$debug == 1} {puts "-D: No qualifying flops found for BLI"}
			set stop [clock seconds]
			::tclapp::xilinx::customqorflows::compile_time $start $stop "" BLI_FLOP_IO
			return
		}

		if {$debug == 1} {puts "-D: Setting BLI TRUE on [llength $bli_flops] flops"}
		if {[llength $bli_flops] == 1} {
			foreach flop_name [lsort $bli_flops] {
				set one_cmd "set_property BLI TRUE \[get_cells \{ $flop_name \}\]"
				set command "${command}\n${one_cmd}\n"
			}
		} else {
			set command [::tclapp::xilinx::customqorflows::pretty_command_property BLI TRUE $bli_flops]
		}

		# End of suggestion content
		# =========================
		set stop [clock seconds]
		::tclapp::xilinx::customqorflows::compile_time $start $stop "" BLI_FLOP_IO
		if {$command eq ""} {
			return
		} else {
			return [dict create COMMAND $command]
		}
	}


	proc register_bli_flop_io_checks {} {
	  # The following sets up the suggestion in the Custom QoR Tools.
	  # ==================================================
	   set id RQS_AMD_TIMING-2
	   set description "Set BLI TRUE on flops driving critical IO paths with sufficient pre-path margin"
	   set auto 1
	   set category netlist
	   set applicable_for place_design
	   set switches ""
	   set needs_timing_data 1
	   set params [list DEBUG 0 MAX_PATHS 1000 SLACK_THRESHOLD -0.100 MARGIN_THRESHOLD 2.0]

	   catch "delete_qor_check ${id} -quiet"
	   create_qor_check -name ${id} -rule_body ::tclapp::xilinx::customqorflows::bli_flop_io \
	  	-property_values [list DESCRIPTION $description \
	  						   AUTO $auto \
	  						   CATEGORY $category \
	  						   APPLICABLE_FOR $applicable_for\
	  						   NEEDS_TIMING_DATA $needs_timing_data \
	  						   PARAMS $params \
	  						   ]
	}

	register_bli_flop_io_checks

}
