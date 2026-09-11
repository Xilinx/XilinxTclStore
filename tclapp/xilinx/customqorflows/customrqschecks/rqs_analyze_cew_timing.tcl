####################################################################################
#
# rqs_analyze_cew_timing.tcl (customqorflows CEW timing analysis suggestion)
#
# Script created on 03/30/2026 by Madhur Chhabra, AMD
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::customqorflows {
	#namespace export rqs_analyze_cew_timing
}

namespace eval ::tclapp::xilinx::customqorflows {

	proc rqs_analyze_cew_timing {args} {
		# Description:
		# Analyzes timing-critical paths for CEW (Clock Expansion Window) overlap issues.
		# Supports Versal (X0Y10) and Versal P80 (S1X2Y6) clock region formats.
		#
		# Applicable for: place_design
		# Returns: set_property USER_CLOCK_EXPANSION_WINDOW commands for CEW-constrained nets.

		set start [clock seconds]

		# PARAMS
		set PARAMS(MAX_PATHS) 10
		set PARAMS(SLACK_THRESHOLD) 0.0
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
		set max_paths $PARAMS(MAX_PATHS)
		set slack_threshold $PARAMS(SLACK_THRESHOLD)

		# ---- Collect failing path groups -------------------------------------------
		set all_groups [get_path_groups -quiet]
		if {[llength $all_groups] == 0} {
			return
		}

		# CEW fix collection: net_name -> expanded {s_lo x_min y_min s_hi x_max y_max}
		array set cew_fix_nets {}

		set num_groups [llength $all_groups]
		for {set gi 0} {$gi < $num_groups} {incr gi} {
			set grp [lindex $all_groups $gi]
			# Use the group object directly (handles **default** etc.)
			set grp_name $grp

			# Get worst N paths in this group with negative slack
			set timing_paths [get_timing_paths \
				-group [get_path_groups -quiet $grp_name] \
				-max_paths $max_paths \
				-slack_lesser_than $slack_threshold \
				-quiet]

			if {[llength $timing_paths] == 0} {
				continue
			}

			foreach tp $timing_paths {

				# ---- Extract basic timing info -----------------------------------------
				set startpoint  [get_property STARTPOINT_PIN  $tp]
				set endpoint    [get_property ENDPOINT_PIN    $tp]

				# ---- Determine path type: cell-to-cell, port-to-cell, cell-to-port ----
				set src_is_port 0
				set dst_is_port 0
				set src_cell [get_cells -quiet -of_objects [get_pins -quiet $startpoint]]
				set dst_cell [get_cells -quiet -of_objects [get_pins -quiet $endpoint]]

				# Check if startpoint is a port (no cell resolved)
				if {[llength $src_cell] == 0} {
					set src_port [get_ports -quiet $startpoint]
					if {[llength $src_port] > 0} {
						set src_is_port 1
					} else {
						continue
					}
				}
				# Check if endpoint is a port (no cell resolved)
				if {[llength $dst_cell] == 0} {
					set dst_port [get_ports -quiet $endpoint]
					if {[llength $dst_port] > 0} {
						set dst_is_port 1
					} else {
						continue
					}
				}

				# If both are ports (port-to-port), skip CEW analysis
				if {$src_is_port && $dst_is_port} {
					continue
				}

				# ---- Determine path type string ----------------------------------------
				if {$src_is_port && !$dst_is_port} {
					set path_type "PORT_TO_CELL"
				} elseif {!$src_is_port && $dst_is_port} {
					set path_type "CELL_TO_PORT"
				} else {
					set path_type "CELL_TO_CELL"
				}

				# ---- Get locations -----------------------------------------------------
				if {$src_is_port} {
					set src_loc [get_property -quiet LOC $src_port]
				} else {
					set src_loc [get_property LOC $src_cell]
				}
				if {$dst_is_port} {
					set dst_loc [get_property -quiet LOC $dst_port]
				} else {
					set dst_loc [get_property LOC $dst_cell]
				}

				# ---- Get clock regions -------------------------------------------------
				set src_cr [get_clock_region_of_site $src_loc]
				set dst_cr [get_clock_region_of_site $dst_loc]

				# ---- Find clock pins of source and destination cells -------------------
				# Ports don't have clock pins — only query on real cells
				if {$src_is_port} {
					set src_clk_pin {}
				} else {
					set src_clk_pin [get_pins -quiet -of_objects $src_cell -filter {IS_CLOCK == 1}]
				}
				if {$dst_is_port} {
					set dst_clk_pin {}
				} else {
					set dst_clk_pin [get_pins -quiet -of_objects $dst_cell -filter {IS_CLOCK == 1}]
				}

				# ---- Get CEW and determine CEW-limited status --------------------------
				set src_cew [get_cew_from_clk_pin $src_clk_pin]
				set dst_cew [get_cew_from_clk_pin $dst_clk_pin]

				# Get clock buffer output net names for XDC fix generation
				set src_clk_net [get_clock_buffer_net $src_clk_pin]
				set dst_clk_net [get_clock_buffer_net $dst_clk_pin]

				set cew_limited 0
				set cew_constrained 0
				set cew_overlap "N/A"
				set src_to_dst_min -1
				set dst_to_src_min -1

				if {$path_type eq "CELL_TO_CELL"} {
					# Both endpoints are cells — check overlap of their CEWs
					set cew_overlap [lindex [compute_cew_overlap $src_cew $dst_cew] 0]
					if {$cew_overlap == 0} {
						set cew_limited 1
					}

					# ---- Check reachability: can each cell's CEW reach the other's CR? ----
					set src_to_dst_min [compute_min_distance_from_cew_to_cr $src_cew $dst_cr]
					set dst_to_src_min [compute_min_distance_from_cew_to_cr $dst_cew $src_cr]
					if {!$cew_limited && ($src_to_dst_min > 0 || $dst_to_src_min > 0)} {
						set cew_constrained 1
					}

				} elseif {$path_type eq "CELL_TO_PORT"} {
					# Flop/SRL -> output port: CEW of the source cell must cover
					# at least 1 CR beyond the port's clock region
					set cell_cew $src_cew
					set port_cr  $dst_cr
					set cell_cr  $src_cr
					set cew_limited [lindex [check_cew_covers_port_cr $cell_cew $cell_cr $port_cr] 0]

				} elseif {$path_type eq "PORT_TO_CELL"} {
					# Input port -> flop/SRL: CEW of the destination cell must cover
					# at least 1 CR beyond the port's clock region
					set cell_cew $dst_cew
					set port_cr  $src_cr
					set cell_cr  $dst_cr
					set cew_limited [lindex [check_cew_covers_port_cr $cell_cew $cell_cr $port_cr] 0]
				}

				# ---- Collect CEW fix XDC commands ------------------------------------
				if {$path_type eq "CELL_TO_CELL" && ($cew_constrained || $cew_limited)} {
					# Expand source clock CEW to include destination CR if src can't reach dst
					if {$src_to_dst_min > 0 && $src_clk_net ne "" && $src_cew ne "N/A"} {
						set src_cew_parsed [parse_cew_range $src_cew]
						set dst_cr_parsed  [parse_clock_region $dst_cr]
						if {[lindex $src_cew_parsed 0] ne "ERR" && [lindex $dst_cr_parsed 0] ne "ERR"} {
							set expanded [expand_cew_to_include_cr $src_cew_parsed $dst_cr_parsed]
							if {[info exists cew_fix_nets($src_clk_net)]} {
								set cew_fix_nets($src_clk_net) [merge_cew_ranges $cew_fix_nets($src_clk_net) $expanded]
							} else {
								set cew_fix_nets($src_clk_net) $expanded
							}
						}
					}
					# Expand destination clock CEW to include source CR if dst can't reach src
					if {$dst_to_src_min > 0 && $dst_clk_net ne "" && $dst_cew ne "N/A"} {
						set dst_cew_parsed [parse_cew_range $dst_cew]
						set src_cr_parsed  [parse_clock_region $src_cr]
						if {[lindex $dst_cew_parsed 0] ne "ERR" && [lindex $src_cr_parsed 0] ne "ERR"} {
							set expanded [expand_cew_to_include_cr $dst_cew_parsed $src_cr_parsed]
							if {[info exists cew_fix_nets($dst_clk_net)]} {
								set cew_fix_nets($dst_clk_net) [merge_cew_ranges $cew_fix_nets($dst_clk_net) $expanded]
							} else {
								set cew_fix_nets($dst_clk_net) $expanded
							}
						}
					}
				}
				if {($path_type eq "CELL_TO_PORT" || $path_type eq "PORT_TO_CELL") && $cew_limited} {
					# Expand the sequential cell's clock CEW to include the port's CR
					if {$path_type eq "CELL_TO_PORT"} {
						set fix_clk_net $src_clk_net
						set fix_cew     $src_cew
						set fix_target  $dst_cr
					} else {
						set fix_clk_net $dst_clk_net
						set fix_cew     $dst_cew
						set fix_target  $src_cr
					}
					if {$fix_clk_net ne "" && $fix_cew ne "N/A"} {
						set fix_cew_parsed [parse_cew_range $fix_cew]
						set fix_cr_parsed  [parse_clock_region $fix_target]
						if {[lindex $fix_cew_parsed 0] ne "ERR" && [lindex $fix_cr_parsed 0] ne "ERR"} {
							set expanded [expand_cew_to_include_cr $fix_cew_parsed $fix_cr_parsed]
							if {[info exists cew_fix_nets($fix_clk_net)]} {
								set cew_fix_nets($fix_clk_net) [merge_cew_ranges $cew_fix_nets($fix_clk_net) $expanded]
							} else {
								set cew_fix_nets($fix_clk_net) $expanded
							}
						}
					}
				}
			}
		}

		set cmd ""
		# ---- Build XDC fix commands for CEW-constrained/limited clocks -----------
		set fix_net_names [array names cew_fix_nets]
		if {[llength $fix_net_names] > 0} {
			foreach net_name [lsort $fix_net_names] {
				set expanded_range [format_cew_range $cew_fix_nets($net_name)]
				set xdc_cmd "set_property USER_CLOCK_EXPANSION_WINDOW $expanded_range \[get_nets $net_name\]"
				set cmd "${cmd}\n${xdc_cmd}\n"
			}
		}

		# End of suggestion content
		# =========================
		set stop [clock seconds]
		::tclapp::xilinx::customqorflows::compile_time $start $stop "" RQS_ANALYZE_CEW_TIMING
		if {$cmd eq ""} {
			return
		} else {
			return [dict create COMMAND $cmd]
		}
	}

	################################################################################
	# Helper: Extract clock region from a site name.
	################################################################################
	proc get_clock_region_of_site {site_name} {
		if {$site_name eq ""} { return "UNKNOWN" }
		set site_obj [get_sites -quiet $site_name]
		if {[llength $site_obj] == 0} { return "UNKNOWN" }
		set cr [get_property CLOCK_REGION $site_obj]
		if {$cr eq ""} { return "UNKNOWN" }
		return $cr
	}

	################################################################################
	# Helper: Parse a clock region name into {slr x y}.
	#   Handles:
	#     "X0Y10"       -> {-1 0 10}    (Versal, no SLR prefix)
	#     "S1X2Y6"      -> {1 2 6}      (Versal P80 with SLR)
	################################################################################
	proc parse_clock_region {cr} {
		# Versal P80: S<n>X<n>Y<n>
		if {[regexp {S(\d+)X(\d+)Y(\d+)} $cr -> s x y]} {
			return [list $s $x $y]
		}
		# Standard Versal: X<n>Y<n>
		if {[regexp {X(\d+)Y(\d+)} $cr -> x y]} {
			return [list -1 $x $y]
		}
		return [list "ERR"]
	}

	################################################################################
	# Helper: Get CEW for a cell given its clock pin.
	################################################################################
	proc get_cew_from_clk_pin {clk_pin} {
		if {[llength $clk_pin] == 0} { return "N/A" }

		set pin [lindex $clk_pin 0]

		set clk_net [get_nets -quiet -of_objects [get_pins -quiet $pin]]
		if {[llength $clk_net] == 0} { return "N/A" }

		set driver_pin [get_pins -quiet -of_objects $clk_net -leaf -filter {DIRECTION == OUT}]
		if {[llength $driver_pin] == 0} { return "N/A" }

		set driver_net [get_nets -quiet -of_objects $driver_pin]
		if {[llength $driver_net] == 0} { return "N/A" }

		set cew [get_property -quiet CLOCK_EXPANSION_WINDOW $driver_net]
		if {$cew eq ""} { return "N/A" }

		return $cew
	}

	################################################################################
	# Helper: Compute overlap between two CEWs.
	################################################################################
	proc compute_cew_overlap {cew1 cew2} {
		if {$cew1 eq "N/A" || $cew2 eq "N/A"} {
			return [list -1 ""]
		}

		set parsed1 [parse_cew_range $cew1]
		set parsed2 [parse_cew_range $cew2]

		if {[lindex $parsed1 0] eq "ERR" || [lindex $parsed2 0] eq "ERR"} {
			return [list -1 "Could not parse CEW format: $cew1 / $cew2"]
		}

		lassign $parsed1 s1_lo x1_min y1_min s1_hi x1_max y1_max
		lassign $parsed2 s2_lo x2_min y2_min s2_hi x2_max y2_max

		if {$s1_lo ne "-1" && $s2_lo ne "-1"} {
			set slr_ov_lo [expr {max($s1_lo, $s2_lo)}]
			set slr_ov_hi [expr {min($s1_hi, $s2_hi)}]
			if {$slr_ov_lo > $slr_ov_hi} {
				return [list 0 "No overlap (no common SLR: S${s1_lo}-S${s1_hi} vs S${s2_lo}-S${s2_hi})"]
			}
			if {$slr_ov_lo == $slr_ov_hi} {
				set slr_pfx "S${slr_ov_lo}"
			} else {
				set slr_pfx "S${slr_ov_lo}-S${slr_ov_hi}"
			}
		} else {
			set slr_pfx ""
		}

		set ov_x_min [expr {max($x1_min, $x2_min)}]
		set ov_y_min [expr {max($y1_min, $y2_min)}]
		set ov_x_max [expr {min($x1_max, $x2_max)}]
		set ov_y_max [expr {min($y1_max, $y2_max)}]

		if {$ov_x_min > $ov_x_max || $ov_y_min > $ov_y_max} {
			return [list 0 "No overlap in X/Y. Src=${slr_pfx}X${x1_min}Y${y1_min}:X${x1_max}Y${y1_max}, Dst=${slr_pfx}X${x2_min}Y${y2_min}:X${x2_max}Y${y2_max}"]
		}

		set ov_width  [expr {$ov_x_max - $ov_x_min + 1}]
		set ov_height [expr {$ov_y_max - $ov_y_min + 1}]
		set ov_area   [expr {$ov_width * $ov_height}]

		set detail "Overlap=${slr_pfx}X${ov_x_min}Y${ov_y_min}:${slr_pfx}X${ov_x_max}Y${ov_y_max} (${ov_width}x${ov_height}=${ov_area} CRs)"
		return [list $ov_area $detail]
	}

	################################################################################
	# Helper: Parse a CEW range string into {s_lo x_min y_min s_hi x_max y_max}.
	################################################################################
	proc parse_cew_range {cew_str} {
		# Versal P80: CLOCKREGION_S<n>X<n>Y<n>:CLOCKREGION_S<n>X<n>Y<n>
		if {[regexp {CLOCKREGION_S(\d+)X(\d+)Y(\d+)\s*:\s*CLOCKREGION_S(\d+)X(\d+)Y(\d+)} $cew_str -> s1 x1 y1 s2 x2 y2]} {
			set s_lo [expr {min($s1, $s2)}]
			set s_hi [expr {max($s1, $s2)}]
			set x_min [expr {min($x1, $x2)}]
			set y_min [expr {min($y1, $y2)}]
			set x_max [expr {max($x1, $x2)}]
			set y_max [expr {max($y1, $y2)}]
			return [list $s_lo $x_min $y_min $s_hi $x_max $y_max]
		}
		# Versal: CLOCKREGION_X<n>Y<n>:CLOCKREGION_X<n>Y<n>
		if {[regexp {CLOCKREGION_X(\d+)Y(\d+)\s*:\s*CLOCKREGION_X(\d+)Y(\d+)} $cew_str -> x1 y1 x2 y2]} {
			set x_min [expr {min($x1, $x2)}]
			set y_min [expr {min($y1, $y2)}]
			set x_max [expr {max($x1, $x2)}]
			set y_max [expr {max($y1, $y2)}]
			return [list -1 $x_min $y_min -1 $x_max $y_max]
		}
		# Plain with SLR: S<n>X<n>Y<n>:S<n>X<n>Y<n>
		if {[regexp {S(\d+)X(\d+)Y(\d+)\s*:\s*S(\d+)X(\d+)Y(\d+)} $cew_str -> s1 x1 y1 s2 x2 y2]} {
			set s_lo [expr {min($s1, $s2)}]
			set s_hi [expr {max($s1, $s2)}]
			set x_min [expr {min($x1, $x2)}]
			set y_min [expr {min($y1, $y2)}]
			set x_max [expr {max($x1, $x2)}]
			set y_max [expr {max($y1, $y2)}]
			return [list $s_lo $x_min $y_min $s_hi $x_max $y_max]
		}
		# Plain: X<n>Y<n>:X<n>Y<n>
		if {[regexp {X(\d+)Y(\d+)\s*:\s*X(\d+)Y(\d+)} $cew_str -> x1 y1 x2 y2]} {
			set x_min [expr {min($x1, $x2)}]
			set y_min [expr {min($y1, $y2)}]
			set x_max [expr {max($x1, $x2)}]
			set y_max [expr {max($y1, $y2)}]
			return [list -1 $x_min $y_min -1 $x_max $y_max]
		}
		return [list "ERR"]
	}

	################################################################################
	# Helper: Compute the minimum Manhattan CR distance from a CEW box to a target
	#   clock region. Returns 0 if the target CR is inside the CEW box.
	################################################################################
	proc compute_min_distance_from_cew_to_cr {cew_str target_cr} {
		if {$cew_str eq "N/A" || $target_cr eq "UNKNOWN"} { return -1 }

		set cew_parsed [parse_cew_range $cew_str]
		if {[lindex $cew_parsed 0] eq "ERR"} { return -1 }
		lassign $cew_parsed cew_s_lo cew_x_min cew_y_min cew_s_hi cew_x_max cew_y_max

		set p_target [parse_clock_region $target_cr]
		if {[lindex $p_target 0] eq "ERR"} { return -1 }
		lassign $p_target t_s t_x t_y

		if {$cew_s_lo ne "-1" && $t_s ne "-1"} {
			if {$t_s < $cew_s_lo || $t_s > $cew_s_hi} {
				return 999
			}
		}

		if {$t_x < $cew_x_min} {
			set dx [expr {$cew_x_min - $t_x}]
		} elseif {$t_x > $cew_x_max} {
			set dx [expr {$t_x - $cew_x_max}]
		} else {
			set dx 0
		}

		if {$t_y < $cew_y_min} {
			set dy [expr {$cew_y_min - $t_y}]
		} elseif {$t_y > $cew_y_max} {
			set dy [expr {$t_y - $cew_y_max}]
		} else {
			set dy 0
		}

		return [expr {$dx + $dy}]
	}

	################################################################################
	# Helper: For port paths, check whether the sequential cell's CEW extends
	#   at least 1 CR beyond the port's clock region.
	################################################################################
	proc check_cew_covers_port_cr {cell_cew cell_cr port_cr} {
		if {$cell_cew eq "N/A" || $port_cr eq "UNKNOWN" || $cell_cr eq "UNKNOWN"} {
			return [list 0 "Could not determine (CEW=$cell_cew, cell_cr=$cell_cr, port_cr=$port_cr)"]
		}

		set p_cell [parse_clock_region $cell_cr]
		set p_port [parse_clock_region $port_cr]
		if {[lindex $p_cell 0] eq "ERR"} {
			return [list 0 "Could not parse cell CR: $cell_cr"]
		}
		if {[lindex $p_port 0] eq "ERR"} {
			return [list 0 "Could not parse port CR: $port_cr"]
		}
		lassign $p_cell cell_s cell_x cell_y
		lassign $p_port port_s port_x port_y

		set cew_parsed [parse_cew_range $cell_cew]
		if {[lindex $cew_parsed 0] eq "ERR"} {
			return [list 0 "CEW format not recognized: $cell_cew"]
		}
		lassign $cew_parsed cew_s_lo cew_x_min cew_y_min cew_s_hi cew_x_max cew_y_max

		if {$cew_s_lo ne "-1" && $port_s ne "-1"} {
			if {$port_s < $cew_s_lo || $port_s > $cew_s_hi} {
				return [list 1 "Cell CEW spans SLR S${cew_s_lo}-S${cew_s_hi} but port is in SLR S${port_s} - outside CEW SLR range"]
			}
		}

		set port_in_cew [expr {
			$port_x >= ($cew_x_min - 1) && $port_x <= ($cew_x_max + 1) &&
			$port_y >= ($cew_y_min - 1) && $port_y <= ($cew_y_max + 1)
		}]

		if {$cew_s_lo ne "-1"} {
			set cew_disp "S${cew_s_lo}X${cew_x_min}Y${cew_y_min}:S${cew_s_hi}X${cew_x_max}Y${cew_y_max}"
		} else {
			set cew_disp "X${cew_x_min}Y${cew_y_min}:X${cew_x_max}Y${cew_y_max}"
		}

		if {!$port_in_cew} {
			return [list 1 "Cell CEW \[$cew_disp\] does NOT reach port CR $port_cr (need at least 1 CR beyond)"]
		} else {
			return [list 0 "Cell CEW \[$cew_disp\] covers port CR $port_cr"]
		}
	}

	################################################################################
	# Helper: Get the clock buffer output net name from a cell clock pin.
	################################################################################
	proc get_clock_buffer_net {clk_pin} {
		if {[llength $clk_pin] == 0} { return "" }
		set pin [lindex $clk_pin 0]
		set clk_net [get_nets -quiet -of_objects [get_pins -quiet $pin]]
		if {[llength $clk_net] == 0} { return "" }
		set driver_pin [get_pins -quiet -of_objects $clk_net -leaf -filter {DIRECTION == OUT}]
		if {[llength $driver_pin] == 0} { return "" }
		set driver_net [get_nets -quiet -of_objects $driver_pin]
		if {[llength $driver_net] == 0} { return "" }
		return [get_property -quiet NAME $driver_net]
	}

	################################################################################
	# Helper: Expand a parsed CEW range to include a target clock region.
	################################################################################
	proc expand_cew_to_include_cr {cew_parsed target_cr_parsed} {
		lassign $cew_parsed  s_lo x_min y_min s_hi x_max y_max
		lassign $target_cr_parsed t_s t_x t_y
		set new_x_min [expr {min($x_min, $t_x)}]
		set new_y_min [expr {min($y_min, $t_y)}]
		set new_x_max [expr {max($x_max, $t_x)}]
		set new_y_max [expr {max($y_max, $t_y)}]
		if {$s_lo ne "-1" && $t_s ne "-1"} {
			set new_s_lo [expr {min($s_lo, $t_s)}]
			set new_s_hi [expr {max($s_hi, $t_s)}]
		} else {
			set new_s_lo $s_lo
			set new_s_hi $s_hi
		}
		return [list $new_s_lo $new_x_min $new_y_min $new_s_hi $new_x_max $new_y_max]
	}

	################################################################################
	# Helper: Merge two parsed CEW ranges into a bounding box.
	################################################################################
	proc merge_cew_ranges {range1 range2} {
		lassign $range1 s1_lo x1_min y1_min s1_hi x1_max y1_max
		lassign $range2 s2_lo x2_min y2_min s2_hi x2_max y2_max
		set new_x_min [expr {min($x1_min, $x2_min)}]
		set new_y_min [expr {min($y1_min, $y2_min)}]
		set new_x_max [expr {max($x1_max, $x2_max)}]
		set new_y_max [expr {max($y1_max, $y2_max)}]
		if {$s1_lo ne "-1" && $s2_lo ne "-1"} {
			set new_s_lo [expr {min($s1_lo, $s2_lo)}]
			set new_s_hi [expr {max($s1_hi, $s2_hi)}]
		} else {
			set new_s_lo $s1_lo
			set new_s_hi $s1_hi
		}
		return [list $new_s_lo $new_x_min $new_y_min $new_s_hi $new_x_max $new_y_max]
	}

	################################################################################
	# Helper: Format a parsed CEW range back to a CLOCKREGION string.
	################################################################################
	proc format_cew_range {cew_range} {
		lassign $cew_range s_lo x_min y_min s_hi x_max y_max
		if {$s_lo ne "-1"} {
			return "CLOCKREGION_S${s_lo}X${x_min}Y${y_min}:CLOCKREGION_S${s_hi}X${x_max}Y${y_max}"
		} else {
			return "CLOCKREGION_X${x_min}Y${y_min}:CLOCKREGION_X${x_max}Y${y_max}"
		}
	}


	proc register_rqs_analyze_cew_timing_checks {} {
	  # The following sets up the suggestion in the Custom QoR Tools.
	  # ==================================================
	   set id RQS_AMD_TIMING-1
	   set description "Analyzes timing-critical paths for CEW (Clock Expansion Window) overlap issues"
	   set auto 1
	   set category timing
	   set applicable_for place_design
	   set needs_timing_data 0
	   set params [list DEBUG 0 MAX_PATHS 10 SLACK_THRESHOLD 0.0]

	   catch "delete_qor_check ${id} -quiet"
	   create_qor_check -name ${id} -rule_body ::tclapp::xilinx::customqorflows::rqs_analyze_cew_timing \
	  	-property_values [list DESCRIPTION $description \
	  						   AUTO $auto \
	  						   CATEGORY $category \
	  						   APPLICABLE_FOR $applicable_for\
	  						   NEEDS_TIMING_DATA $needs_timing_data \
	  						   PARAMS $params \
	  						   ]
	}

	register_rqs_analyze_cew_timing_checks

}
