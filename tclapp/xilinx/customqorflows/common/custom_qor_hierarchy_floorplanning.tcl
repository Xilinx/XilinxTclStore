####################################################################################
#
# custom_qor_hierarchy_floorplanning.tcl (customqorflows hierarchy floorplanning utilities)
#
# Script created on 03/30/2026 by Madhur Chhabra, AMD
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::customqorflows {
	
}

namespace eval ::tclapp::xilinx::customqorflows {

	proc flag_hierarchies_above {cell_name cell_data {flag_current_hier 1} {value 1} {index_pre ""} {index_post ""}} {
		# Summary:
		# Recursively flags all hierarchical cells above a specified cell in the hierarchy tree.
		#
		# Argument Usage:
		# cell_name - Cell name or object to start search from
		# cell_data - Array variable name (by reference via upvar) to store flagged hierarchy cell names
		# flag_current_hier - 1 to include input cell (default: 1)
		# value - String value to set on array elements (default: 1)
		# index_pre - Optional prefix to add before cell name in array index
		# index_post - Optional suffix to add after cell name in array index
		#
		# Return Value:
		# No explicit return; populates caller's CELL_DATA array via upvar with flagged hierarchy cells
		#
		# Categories: xilinxtclstore, customqorflows
		#
		# -------------------------------------------------------------------------
		# flag_hierarchies_above
		#
		# Recursively flags all non-primitive hierarchical cells above a given cell.
		# This can be used when you are processing many hierarchies in a design, but have found
		# a cell you do not want to analyze data beneath it in order to speed up the script.
		# In this case, you can quickly check the array to see if it is set to 1 and continue 
		# in the loop
		#
		# Arguments:
		#   cell_name         - The name of the top-level cell to start the search from.
		#   cell_data         - The name of the array variable (by reference) to store flagged hierarchies.
		#   flag_current_hier - (Optional) If set to 1 (default), marks the input cell itself.
		#   value             - (Optional) The string value set on the array
		#   index_pre         - (Optional) Add something to the array name index before the cell name
		#   index_post        - (Optional) Add something to the array name index after the cell name
		#
		# Description:
		#   This procedure traverses the hierarchy tree starting from the specified cell.
		#   For each non-primitive cell (IS_PRIMITIVE==0) found above the current cell,
		#   it sets CELL_DATA($hier) to 1 and recursively continues the search upwards from that cell.
		#   The result is that CELL_DATA will contain all hierarchy cell names above the input cell.
		#
		# Example usage: 
		#   set CELL_DATA(delete) 1;                             # Initialize an array
		#   flag_hierarchies_above [get_cells ..] CELL_DATA;     # Call the function
		# -------------------------------------------------------------------------
		upvar $cell_data CELL_DATA
		set cell_name [get_cells $cell_name]
		set idx $cell_name
		if {$index_pre ne ""} {set idx ${index_pre},$idx}
		if {$index_post ne ""} {set idx ${idx},$index_post}
		if {$flag_current_hier == 1} {set CELL_DATA($idx) 1}
        set cell_name [get_cells -quiet [get_property PARENT $cell_name]]
		#
		while {$cell_name ne ""} {
			set idx $cell_name
			if {$index_pre ne ""} {set idx ${index_pre},$idx}
			if {$index_post ne ""} {set idx ${idx},$index_post}
			set CELL_DATA($idx) $value
            set cell_name [get_cells -quiet [get_property PARENT $cell_name]]
        }	
	}

	proc flag_hierarchies_below {cell_name cell_data {flag_current_hier 1} {value 1} {index_pre ""} {index_post ""}} {
		# Summary:
		# Recursively flags all hierarchical cells below a specified cell in the hierarchy tree.
		#
		# Argument Usage:
		# cell_name - Cell name or object to start search from
		# cell_data - Array variable name (by reference via upvar) to store flagged hierarchy cell names
		# flag_current_hier - 1 to include input cell (default: 1)
		# value - String value to set on array elements (default: 1)
		# index_pre - Optional prefix to add before cell name in array index
		# index_post - Optional suffix to add after cell name in array index
		#
		# Return Value:
		# No explicit return; populates caller's CELL_DATA array via upvar with flagged hierarchy cells
		#
		# Categories: xilinxtclstore, customqorflows
		#
		# -------------------------------------------------------------------------
		# flag_hierarchies_below
		#
		# Recursively flags all non-primitive hierarchical cells below a given cell.
		# This can be used when you are processing many hierarchies in a design, but have found
		# a cell you do not want to analyze data beneath it in order to speed up the script.
		# In this case, you can quickly check the array to see if it is set to 1 and continue 
		# in the loop
		#
		# Arguments:
		#   cell_name         - The name of the top-level cell to start the search from.
		#   cell_data         - The name of the array variable (by reference) to store flagged hierarchies.
		#   flag_current_hier - (Optional) If set to 1 (default), marks the input cell itself.
		#   value             - (Optional) The string value set on the array
		#   index_pre         - (Optional) Add something to the array name index before the cell name
		#   index_post        - (Optional) Add something to the array name index after the cell name
		#
		# Description:
		#   This procedure traverses the hierarchy tree starting from the specified cell.
		#   For each non-primitive cell (IS_PRIMITIVE==0) found below the current cell,
		#   it sets CELL_DATA($hier) to 1 and recursively continues the search within that cell.
		#   The result is that CELL_DATA will contain all hierarchy cell names below the input cell.
		#
		# Example usage:
		#   set CELL_DATA(FOR_DELETE) 1;                   # Initialize an array
		#   flag_hiers_below [get_cells ..] CELL_DATA;     # Call the function
		# -------------------------------------------------------------------------
		upvar $cell_data CELL_DATA
		set idx $cell_name
		if {$index_pre ne ""} {set idx ${index_pre},$idx}
		if {$index_post ne ""} {set idx ${idx},$index_post}
		if {$flag_current_hier == 1} {set CELL_DATA($idx) $value}
		# COMMENTED OUT AS BELOW METHOD IS 12x QUICKER. HOWEVER POSSIBLY NOT AS ROBUST
		#
		# # Find all non-primitive cells in the current hierarchy
		# foreach hier [get_cells ${cell_name}/* -quiet -filter {IS_PRIMITIVE==0}] {
		# 	set CELL_DATA($hier) 1
		# 	# Recurse into each hierarchy
		# 	flag_hierarchies_below $hier CELL_DATA 0
		# }
		set ci_tmp [current_inst . -quiet]; current_inst -quiet ; current_inst -quiet  $cell_name; 
		foreach cell [get_cells  -quiet -filter "NAME=~ ${cell_name}/* && (IS_PRIMITIVE==0)" -hier] {
			set idx $cell
			if {$index_pre ne ""} {set idx ${index_pre},$idx}
			if {$index_post ne ""} {set idx ${idx},$index_post}
			set CELL_DATA($idx) $value
		}
		current_inst -quiet; current_inst -quiet $ci_tmp;	
	}

    proc get_bottom_hierarchical_cells {{hierarchical_cells ""}} {
        # Summary:
        # Identifies the bottom-most (leaf) hierarchical cells in a design hierarchy.
        #
        # Argument Usage:
        # hierarchical_cells - Optional list of cells to filter (default: "" searches entire design)
        #
        # Return Value:
        # List of hierarchical cell objects that have no sub-hierarchies (bottom-level cells)
        #
        # Categories: xilinxtclstore, customqorflows
        #
        # Description:
        # Finds the bottom hierarchical cells in a design or if a list of
		# hierarchical cells is provided, the bottom cells in the list. 
        #
		# Arguments:
		# None
		#
		# Returns:
		# A list of cell objects.
		#
		# Usage:
		# When collecting data on hierarchies, starting at the bottom and working up allows more opportunities for 
		# compile time optimizations by reducing hierarchical calls to the database. Instead resources in the current
		# hierarchy can be added to ones from the lower hierarchies.
		
		# Step 1: Get all hierarchical cells (IS_PRIMITIVE == 0)
        if {$hierarchical_cells eq ""} {
			set hierarchical_cells [get_cells -quiet -hierarchical -filter {IS_PRIMITIVE == 0}]
		} else {
			set hierarchical_cells [get_cells $hierarchical_cells]
		}

        # Step 2: Generate a list of all parent cells
        foreach parent [get_property -quiet PARENT $hierarchical_cells] {
            set parent_array($parent) 1
        }

        # Step 3: Identify cells that are not parent cells
        set bottom_hierarchy_cells [list]
        foreach cell $hierarchical_cells {
            if {![info exists parent_array($cell)]} {
                lappend bottom_hier_cells $cell
            }
        }
		set bottom_hier_cells [filter [lsort -unique $bottom_hier_cells] {PRIMITIVE_LEVEL!=MACRO}]

        # Return the list of non-parent hierarchical cells
        return $bottom_hier_cells
    }

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

	proc get_floorplan {gt_dict gclk_dict params {check 1} } {
		# Summary:
		# Evaluates floorplanning constraints and returns clock region pblock ranges matching fanout thresholds.
		#
		# Argument Usage:
		# gt_dict - Dictionary with GT topology info (GATING: gt_single_cr key)
		# gclk_dict - Dictionary with gated clock info (LOADS_ADVANCED_LOCS_CR, FLAT_PIN_COUNT keys)
		# params - Parameter array (by reference via upvar): SINGLE_CR_PRIM_CNT_THRESHOLD, MULTI_CR_PRIM_CNT_THRESHOLD, HALF_SLR_PRIM_CNT_THRESHOLD, SLR Y/MIN/MAX
		# check - Check type (1=same CR, 2=same CR row, 3=same SLR half) (default: 1)
		#
		# Return Value:
		# Clock region pblock string "CLOCKREGION_X<min>Y<min>:CLOCKREGION_X<max>Y<max>" or empty string if threshold/range check fails
		#
		# Categories: xilinxtclstore, customqorflows
		#
		upvar $params PARAMS
		set src_cr  [::tclapp::xilinx::customqorflows::dict_exists_check $gt_dict gt_single_cr]
		set load_crs  [::tclapp::xilinx::customqorflows::dict_exists_check $gclk_dict LOADS_ADVANCED_LOCS_CR]
		set fanout  [::tclapp::xilinx::customqorflows::dict_exists_check $gclk_dict FLAT_PIN_COUNT]
		if {[regexp {X(\d+)Y(\d+)} $src_cr match x y] == 0} {return}

		if {$check == 1} {
			# single CR check - same as driver
			set threshold $PARAMS(SINGLE_CR_PRIM_CNT_THRESHOLD)
			set x_min $x; set x_max $x; set y_min $y; set y_max $y;
		} elseif {$check == 2} {
			# single CR row check - loads in same row as driver and within 3 clock regions
			set threshold $PARAMS(MULTI_CR_PRIM_CNT_THRESHOLD)        
			if {$x == 0} {set x_min 0; set x_max 2; set y_min $y; set y_max $y}
			if {$x != 0} {set x_min [expr $x - 2]; set x_max $x; set y_min $y; set y_max $y}
		} elseif {$check == 3} {
			# Same half of SLR
			set threshold $PARAMS(HALF_SLR_PRIM_CNT_THRESHOLD)
			set slr [get_slrs -of [get_clock_regions $src_cr]]
			if {$x == 0} {set x_min 0; set x_max 2; set y_min $PARAMS($slr,Y,MIN); set y_max $PARAMS($slr,Y,MAX)}
			if {$x != 0} {set x_min [expr $x - 2]; set x_max $x; set y_min $PARAMS($slr,Y,MIN); set y_max $PARAMS($slr,Y,MAX)}
		}
		if {$fanout > $threshold} {return}
		foreach cr $load_crs {
			if {[regexp {X(\d+)Y(\d+)} $cr match x y]==0} {{return}}
			# puts "-D: x - $x x_min $x_min x_max - $x_max y - $y y_min - $y_min y_max - $y_max"
			if {$x < $x_min || $x > $x_max || $y < $y_min || $y > $y_max} {return}
		}
		return CLOCKREGION_X${x_min}Y${y_min}:CLOCKREGION_X${x_max}Y${y_max}      
	}

    proc get_floorplan_hierarchy_by_celltype {cell {top_cell ""} {ref_name_filter ""}} {
        # Summary:
        # Identifies hierarchy levels containing single and multiple instances of cells matching a reference name.
        #
        # Argument Usage:
        # cell - Cell object to analyze (used to determine ref_name_filter if not provided)
        # top_cell - Optional upper hierarchy limit for search (default: "" searches all)
        # ref_name_filter - Optional cell reference name to match (default: "" auto-detects from cell's first pin)
        #
        # Return Value:
        # Nested list {cr_single_inst parent_single_inst cr_multi_list parent_multi_inst num_in_multi_hier}
        # where single instance holds highest level matching filter, multi holds lowest level with multiple instances
        #
        # Categories: xilinxtclstore, customqorflows
        #
        set debug 0
        # This proc takes an input cell that should have the same ref_name and
        # a) finds the hierarchy that is the highest level of hierarchy containing a 
        #    single cell instance with the ref_name filter specified and 
        # b) the lowest level of hierarchy containing more than one instance.
        #
        # Arguments
        # pins - pin objects. These should be from the ref name specified
        # top_cell - cell object that limits the search
        # ref_name_filter - This is the filtering variable applied to the REF_NAME
        #
        # Return
        # A list of n elements representing how many different cells matching the 
        # ref_name were provided in the pin list
        # Each list contains a sublist of 5 elements 
        # 0 - Clock region LOC of single instance MAC
        # 1 - MAC single instance parent cell object
        # 2 - Clock regions LOCs of MACs in multi hierarchy
        # 3 - MAC hierarchy with more than one MAC. 
        # 4 - Number of instances in that hierarchy
        # If nothing is found returns [list [list "" "" "" ""]]
        #
        if {$debug == 1} {puts "-D: get_floorplan_by_celltype: Cell name is $cell"}
		set cell [get_cells $cell]
        if {$ref_name_filter eq ""} {set ref_name_filter [get_property REF_NAME [lindex [get_pins -of $cell] 0]]}
        if {$debug == 1} {puts "-D: get_floorplan_by_celltype: Looking for REF_NAME: $ref_name_filter"}
        set parents [get_cells [get_property PARENT $cell]]
        foreach parent $parents {
            if {$top_cell ne ""} {
                if {[string first $top_cell $parent] == -1} {
                    puts "-CW: Top search cell $top_cell is not an upper hierarchical cell in $parent"
                    continue
                }
            }
            set highest_single_hier ""
            set highest_single_hier_cr ""
            set lowest_multi_hier ""
            set lowest_multi_hier_cr ""
            set lowest_multi_hier_num_cells ""
            while {$parent ne $top_cell} {
                current_inst $parent
                set Cs [get_cells -hier -filter "REF_NAME=~${ref_name_filter}"]
                if {[llength $Cs] == 1} {
                    set highest_single_hier $parent
                    if {$highest_single_hier_cr eq ""} {set highest_single_hier_cr [get_clock_regions -of $Cs]}
                }
                if {$lowest_multi_hier eq ""} {
                    if {[llength $Cs] > 1} {
                        set lowest_multi_hier $parent
                        set lowest_multi_hier_cr [get_clock_regions -of $Cs]
                        set lowest_multi_hier_num_cells [llength $Cs]
                        current_inst -quiet
                        break
                    }
                }
                current_inst -quiet
				set parent [get_cells -quiet [get_property PARENT $parent]]
                if {$parent eq ""} {
					if {$debug == 1} {puts "-D: get_floorplan_by_celltype: Reached top of the design. Multi cell is not returned"}
					set return_val [list $highest_single_hier_cr $highest_single_hier "" "" ""]
					return $return_val
				}
            }
            set return_val [list $highest_single_hier_cr $highest_single_hier $lowest_multi_hier_cr $lowest_multi_hier $lowest_multi_hier_num_cells]
        }
        return $return_val
    }

	proc get_sibling_hier_cells {cell_name} {
		# Summary:
		# Returns all hierarchical siblings of a given cell (excluding macros and the cell itself).
		#
		# Argument Usage:
		# cell_name - Cell name or object to find siblings for
		#
		# Return Value:
		# List of hierarchical sibling cell objects at the same parent level
		#
		# Categories: xilinxtclstore, customqorflows
		#
		# -------------------------------------------------------------------------
		# get_sibling_hier_cells
		#
		# Returns all non-primitive (hierarchical) sibling cells at the same level
		# as the given cell.It ignores macro cells.
		# This can be used to investigate other cells at the same level as a cell of
		# interest. For example, floorplanning, whether we should recommend a change
		# in hierarchy so synthesis optimizations can take place and still meet 
		# floorplanning requirements.
		#
		# Arguments:
		#   cell_name - The name or object of the cell whose siblings are to be found.
		#
		# Returns:
		#   A list of hierarchical sibling cell objects (excluding the input cell).
		#
		# Example usage:
		#   set siblings [get_sibling_hier_cells $cell]
		# -------------------------------------------------------------------------
		# Get the parent cell of the given cell
		set parent [get_property PARENT $cell_name]
		if {$parent eq ""} {
			set siblings [get_cells -quiet -filter {IS_PRIMITIVE==0 && PRIMITIVE_LEVEL!=MACRO}]
		} else {
			set siblings [get_cells -quiet ${parent}/* -filter {IS_PRIMITIVE==0 && PRIMITIVE_LEVEL!=MACRO}]
		}
		
		# Remove the input cell from the list
		set siblings [lsearch -inline -all -not $siblings $cell_name]
		return $siblings
	}
	
    proc has_same_parent {cell1 cell2} {
        # Summary:
        # Tests if two cells share the same parent (are siblings in hierarchy).
        #
        # Argument Usage:
        # cell1 - First cell name or object
        # cell2 - Second cell name or object
        #
        # Return Value:
        # 1 if cells have same parent (siblings), 0 if different parents
        #
        # Categories: xilinxtclstore, customqorflows
        #
        # Description:
        # This procedure checks if the cells are instantiated at the same level and consequently
        # have the same parent cell
        # Returns 1 if it does, 0 otherwise.
        set parents [lsort -unique [get_property PARENT [get_cells [list $cell1 $cell2]]]]
 
        # Check if the unique number of parents is 1. If yes they have the same parent.
        if {[llength $parents] == 1} {
            return 1
        } else {
            return 0
        }
    }

    proc is_loc_in_range {loc range {debug 0}} {
        # Summary:
        # Tests if a clock region location falls within a specified range (single SLR supported).
        #
        # Argument Usage:
        # loc - Clock region location in format XmYn or S<d>_XmYn (m, n are integers)
        # range - Clock region range in format Xm1Yn1:Xm2Yn2 or S<d>_Xm1Yn1:S<d>_Xm2Yn2
        # debug - 1 for debug output (default: 0)
        #
        # Return Value:
        # 1 if location is within range, 0 if outside range, empty/error string if invalid format
        #
        # Categories: xilinxtclstore, customqorflows
        #
        # is_loc_in_range
        # 
        # Description
        # This proc checks to see if a given clock region loc specified in $loc would fall 
        # into a a clock region range specified in $range
        # Support in P80 is limited to same SLR
        #
        # Arguments
        # loc     - expected format is XmYn where m and n are integers
        # range   - expected format is Xm1Yn1:Xm2Yn2 where m1, m2, n1 and n2 are integer
        #
        # Returns
        # 1 if in range
        # 0 if not in range
        # "" if invalid arguments
        #
        if {$debug == 1} {puts "-D: LOC - $loc. Range $range"}
        set all_S ""; set all_x ""; set all_y "";
        foreach r [split $range :] {
            # Match LOC strings like S1_X4Y90, S2_X10Y20, etc.
            if {![regexp {^(?:S(\d)_)?X(\d+)Y(\d+)} $r -> sopt x y]} {return -code 2 "-E: Format of provided range is not meeting requirements: $range"}
            # sopt will be "S1_" or empty, x and y are the coordinates as strings
            # You can use $sopt, $x, $y as needed
            lappend all_S $sopt
            lappend all_x $x 
            lappend all_y $y 
        }
        if {[llength [set all_S [lsort -unique $all_S]]] > 1} {return "-E: Proc does not currently support vp1902 fully. is_loc_in_range only checks with the same SLR"}
        set all_x [lsort -integer -increasing $all_x]
        set min_x [lindex $all_x 0]
        set max_x [lindex $all_x end]
        set all_y [lsort -integer -increasing $all_y]
        set min_y [lindex $all_y 0]
        set max_y [lindex $all_y end]

        # Extract S option, X, and Y from the loc string
        set sopt [list ""]; set x ""; set y "";
        if {![regexp {^(?:S(\d)_)?X(\d+)Y(\d+)} $loc -> sopt x y]} { return "-E: LOC $loc is not in expected format"}
        if {$sopt ne "" && [lindex $all_S 0] ne ""} {
            if {$sopt ne [lsort -unique $all_S]} {return 0}
        } elseif {$sopt eq "" && [lindex $all_S 0] ne ""} {
            return "-E: $loc is not in the same format as the range. LOC - $loc RANGE - $range"
        }
        if {$x >= $min_x && $x <= $max_x && $y >= $min_y && $y <= $max_y} {
            return 1
        } else {
            return 0
        }
    }

	proc is_sub_module {base_cell test_cell} {
		# Summary:
		# Tests if test_cell is a descendant (sub-module) of base_cell in the hierarchy tree.
		#
		# Argument Usage:
		# base_cell - Parent cell name (hierarchy path component)
		# test_cell - Child cell name to check (hierarchy path)
		#
		# Return Value:
		# 1 if test_cell's hierarchical path contains base_cell name (submodule), 0 otherwise
		#
		# Categories: xilinxtclstore, customqorflows
		#
		# Description:
		# This procedure checks if the hierarchical name of the `test_cell` contains the name of the `base_cell`.
		# Returns 1 if it does, implying that this is a submodule, 0 otherwise implying it is not.

		# Check if the test cell name contains the base cell name
		if {[string first $base_cell $test_cell] != -1} {
			return 1
		} else {
			return 0
		}
	}
	
}