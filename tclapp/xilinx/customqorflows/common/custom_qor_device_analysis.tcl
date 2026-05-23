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

namespace eval ::tclapp::xilinx::customqorflows {

	proc get_clock_regions_split_in_slr {slr} {
		# Summary:
		# Calculates clock region boundaries for an SLR and splits into left/right halves with special Y=0 handling.
		#
		# Argument Usage:
		# slr - SLR identifier (e.g., "SLR0", "SLR1") for which to calculate clock region boundaries
		#
		# Return Value:
		# Dictionary with keys: X:left:min, X:left:max, X:right:min, X:right:max, Y:min, Y:max,
		# x_hsr_list, y_hsr_list (device/part-specific); returns formatted error string on regex failure
		#
		# Categories: xilinxtclstore, customqorflows
		#
		# Procedure: get_clock_regions_split_in_slr
		# ===================================
		# Description:
		# This procedure calculates the clock region boundaries for a given SLR (Super Logic Region) and splits them into 
		# left and right sides. It also handles special cases for clock regions where the Y-coordinate is 0 (e.g., high-speed regions).
		# The results are returned as a Tcl dictionary containing the calculated boundaries.
		#
		# Category:
		# Device
		#
		# Arguments:
		# - slr: The name of the SLR for which the clock region boundaries need to be calculated.
		#
		# Returns:
		# - A Tcl dictionary with the following keys:
		#   - X:left:min: Minimum X coordinate for the left side.
		#   - X:left:max: Maximum X coordinate for the left side.
		#   - X:right:min: Minimum X coordinate for the right side.
		#   - X:right:max: Maximum X coordinate for the right side.
		#   - Y:min: Minimum Y coordinate for the SLR.
		#   - Y:max: Maximum Y coordinate for the SLR.
		#
		# Usage:
		# Call this procedure with the name of the SLR and store the returned dictionary.
		# Example:
		#   set slr_dict [get_clock_regions_split_in_slr "SLR0"]
		#   puts "SLR boundaries:"
		#   puts "  Left Side: X[min]=[dict get $slr_dict X:left:min], X[max]=[dict get $slr_dict X:left:max]"
		#   puts "  Right Side: X[min]=[dict get $slr_dict X:right:min], X[max]=[dict get $slr_dict X:right:max]"
		#   puts "  Y Range: Y[min]=[dict get $slr_dict Y:min], Y[max]=[dict get $slr_dict Y:max]"
		#   puts "  High-Speed Regions: X=[dict get $slr_dict x_hsr_list], Y=[dict get $slr_dict y_hsr_list]"
		set slr [get_slrs $slr]
		set slr_dict {}

		# Check if the current device belongs to the Versal family
		set versal 0
		set device_family [get_property FAMILY [get_parts [get_property PART [current_design]]]]
		if {[string match "versal*" $device_family]} {
			set versal 1
		}

		set x_list ""
		set y_list ""

		# Iterate through all clock regions in the SLR
		foreach cr [lsort -dictionary [get_clock_regions -of $slr]] {
			# Extract X and Y coordinates of the clock regions
			if {[regexp {(S\d_)?X(\d+)Y(\d+)} $cr match slr_prefix x y] == 0} {
				return "-E: Regexp for clock region failed to match: $slr $cr"
			}
			if {$versal == 1} {
				if {$y == 0} {continue}
			}
			lappend x_list $x; lappend y_list $y
		}

		# Sort and determine the min/max coordinates for the SLR. Exception handling for xcvp1902
		set x_list_dir increasing
		set y_list_dir increasing
		if {[get_property DEVICE [get_parts [get_property PART [current_design]]]] eq "xcvp1902"} {
			if {$slr eq "SLR2" || $slr eq "SLR3"} {
				set x_list_dir decreasing
			}
			if {$slr eq "SLR1" || $slr eq "SLR2"} {
				set y_list_dir decreasing
			}
		}
		set x_list [lsort -unique -integer -${x_list_dir} $x_list]
		set y_list [lsort -unique -integer -${y_list_dir} $y_list]
		dict set slr_dict X:left:min [lindex $x_list 0]
		dict set slr_dict X:right:max [lindex $x_list end]
		dict set slr_dict Y:min [lindex $y_list 0]
		dict set slr_dict Y:max [lindex $y_list end]

		# Calculate the midpoint of the X range
		set x_mid [expr ([dict get $slr_dict X:right:max] - [dict get $slr_dict X:left:min]) / 2 + [dict get $slr_dict X:left:min]]

		# Split the SLR into left and right sides
		if {[llength $x_list] % 2 == 1} {
			dict set slr_dict X:left:max $x_mid
			dict set slr_dict X:right:min [expr $x_mid + 1]
		} else {
			dict set slr_dict X:left:max [expr $x_mid - 1]
			dict set slr_dict X:right:min $x_mid
		}

		# Return the dictionary
		return $slr_dict
	}
	
}