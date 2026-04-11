####################################################################################
#
# custom_qor_design_analysis.tcl (customqorflows design analysis utilities)
#
# Script created on 03/30/2026 by Madhur Chhabra, AMD
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::customqorflows {
	
}

namespace eval ::tclapp::xilinx::customqorflows  {

	proc check_control_set_compatability {cells ref_pin_names} {
		# Summary:
		# Check whether a set of cells are control-set compatible for the provided reference pins.
		#
		# Argument Usage:
		# cells ref_pin_names
		#
		# Return Value:
		# Integer status: 1 when compatible, 0 when incompatible.
		#
		# Categories: xilinxtclstore, customqorflows
		#
		# This is a device edit proc used for experimentation. Caution should be used when using this proc as it has not undergone
		# vigourous verification. It is good for experimentation and what if analysis.
		# check ref_names
		set cells [get_cells $cells]
		set ref_names [get_property REF_NAME $cells]
		
		foreach rpn $ref_pin_names {
			set pin_chk_rst 0
			set pin_chk_en 0
			set pin_chk_clk 0
			set rpn [string toupper $rpn]
			if {$rpn eq "CE"} {set pin_filter IS_ENABLE; set pin_chk_en 1}
			if {$rpn eq "C"||$rpn eq "CLK"} {set pin_filter IS_CLOCK; set pin_chk_clk 1}
			if {$rpn eq "RST"||$rpn eq "R"||$rpn eq "CLR"||$rpn eq "SET"||$rpn eq "S"||$rpn eq "PRESET"||$rpn eq "P"} {
				set pin_chk_rst 1
				set pin_filter IS_RESET||IS_SET||IS_PRESET||IS_CLEAR
			}
			set nets [get_nets -parent -of [get_pins -filter "$pin_filter" -of $cells]]
			set signal_nets [filter $nets {TYPE==SIGNAL}]
			set num_signal_nets [llength $signal_nets]
			set num_signal_gnd_nets $num_signal_nets
			set gnd_nets [filter $nets {TYPE==GROUND}]
			set pwr_nets [filter $nets {TYPE==POWER}]
			set num_unique_nets [llength $signal_nets]
			if {[llength $gnd_nets] >= 1} {incr num_unique_nets; incr num_signal_gnd_nets}
			if {[llength $pwr_nets] >= 1} {incr num_unique_nets}
			
			# checks
			if {[llength $signal_nets] > 1} {return 0}
			if {$pin_chk_rst == 1} {
				if {$num_signal_gnd_nets > 1} {return 0}
			}
			if {$pin_chk_en == 1 || $pin_chk_clk == 1} {
				if {$num_unique_nets > 1} {return 0}
			}
		}
		return 1
	}
	
	proc extract_register_from_srl_single {net_create net_connect cell_create pin_disconnect srl parent {input_regs 0} {output_regs 0} {cell_inst_idx 0} {flop_type FDRE}} {
		# Summary:
		# Extract registers around a single SRL and reconnect netlist objects for one SRL transformation.
		#
		# Argument Usage:
		# net_create net_connect cell_create pin_disconnect srl parent {input_regs 0} {output_regs 0} {cell_inst_idx 0} {flop_type FDRE}
		#
		# Return Value:
		# List of extracted object names on success; returns -1 or empty return on non-applicable/error paths.
		#
		# Categories: xilinxtclstore, customqorflows
		#
		# This is a device edit proc used for experimentation. Caution should be used when using this proc as it has not undergone
		# vigourous verification. It is good for experimentation and what if analysis.
		set debug 0
		upvar $net_connect NET_CONNECT
		upvar $net_create NET_CREATE
		upvar $cell_create CELL_CREATE
		upvar $pin_disconnect PIN_DISCONNECT
		# This command extracts a register from the SRL provided
		# Checking
		if {$flop_type ne "FDRE" && $flop_type ne "FDCE" && $flop_type ne "FDSE" && $flop_type ne "FDPE"} {return}
		set len [::tclapp::xilinx::customqorflows::get_srl_length $srl]
		if {$debug == 1} {puts "-D: srl is length is $len"}
		if {$len == -1} {return}
		set total_extraction [expr $input_regs + $output_regs]
		if {$len <= $total_extraction} {		if {$debug == 1} {puts "SRL $srl is too short to extract. Skipping."}; return -1}
		set new_length [expr $len - $total_extraction]
		if {$debug == 1} {puts "-D: new_length is $new_length"}
		if {$parent ne ""} {set parent_mod_2 ${parent}/ } else {set parent_mod_2 ""}
		foreach type [list POWER GROUND] {
			if {$parent eq ""} {set NET_PWR_GND($type) [lindex [get_nets -quiet -filter "TYPE==$type"] 0]} else {set NET_PWR_GND($type) [lindex [get_nets ${parent}/* -quiet -filter "TYPE==$type"] 0]}
			if {$NET_PWR_GND($type) eq ""} {
				if {$type eq "POWER"}  {set ref VCC}
				if {$type eq "GROUND"} {set ref GND}
				set cell [create_cell -reference ${ref} ${parent_mod_2}${ref}_srl_opt]; 
				set NET_PWR_GND($type) [set net [create_net ${parent_mod_2}${ref}_srl_opt]]
				# set NET($net) [get_pins -of $cell] 
				connect_net -net $net -objects [get_pins -of $cell] 
			}
		}
		set gnd $NET_PWR_GND(GROUND); set pwr $NET_PWR_GND(POWER)
		set srl_add_length [expr $new_length -1]
		set address [format %05b $srl_add_length ]
		set ce_net [get_nets -of [set ce_pin [get_pins -filter {IS_ENABLE} -of $srl]]]
		set clk_net [get_nets -of [set clk_pin [get_pins -filter {IS_CLOCK} -of $srl]]]
		set d_net [get_nets -of [set d_pin [get_pins -filter {REF_PIN_NAME==D} -of $srl]]]
		set q_net [get_nets -of [set q_pin [get_pins -filter {REF_PIN_NAME==Q} -of $srl]]]
		set a_pins [lsort -dict [get_pins -filter {REF_PIN_NAME=~A*} -of $srl]]
		if {$flop_type eq "FDRE"} {set rst R} elseif {$flop_type eq "FDCE"} {set rst CLR} elseif {$flop_type eq "FDSE"} {set rst S} elseif {$flop_type eq "FDPE"} {set rst PRE}
		set pins_to_disconnect $a_pins
		if {$debug == 1} {puts "-D: address is $address; srl_add_length $srl_add_length"}
		if {$input_regs > 0} {set pins_to_disconnect [concat $pins_to_disconnect $d_pin]}
		if {$output_regs > 0} {set pins_to_disconnect [concat $pins_to_disconnect $q_pin]; lappend NET_CONNECT($q_net) ${srl}_opreg1/Q}
		set i 0
		foreach a_pin $a_pins {
			set val [string index $address end-${i}]
			if {$val == 0} {lappend NET_CONNECT($gnd) $a_pin} else {lappend NET_CONNECT($pwr) $a_pin}
			incr i
		}
		set rt ""

		set i $input_regs
		while {$i != 0} {
			set j [expr $i+1]
			set new_cell_name ${parent_mod_2}${flop_type}_srl_opt_ipreg_${cell_inst_idx}_${i}
			lappend CELL_CREATE($flop_type) $new_cell_name
			lappend rt $new_cell_name
			set NET_CREATE(${d_net}_srl_ip_net${i}) 1
			set NET_CONNECT(${d_net}_srl_ip_net${i}) ${new_cell_name}/Q
			if {$i == $input_regs} {lappend NET_CONNECT(${d_net}_srl_ip_net${i}) $srl/D} else {lappend NET_CONNECT(${d_net}_srl_ip_net${i}) ${new_cell_name}/D}
			lappend NET_CONNECT($clk_net) ${new_cell_name}/C
			lappend NET_CONNECT($ce_net) ${new_cell_name}/CE
			lappend NET_CONNECT($gnd) ${new_cell_name}/${rst}
			if {$i == 1} {lappend NET_CONNECT($d_net) ${new_cell_name}/D}
			incr i -1
		}
		

		lappend rt ${srl}
		set i $output_regs
		while {$i != 0} {
			set j [expr $i+1]
			set new_cell_name ${parent_mod_2}${flop_type}_srl_opt_opreg_${cell_inst_idx}_${i}
			lappend CELL_CREATE($flop_type) ${new_cell_name}
			lappend rt ${new_cell_name}
			set NET_CREATE(${q_net}_srl_op_net${i}) 1
			set NET_CONNECT(${q_net}_srl_op_net${i}) ${new_cell_name}/D
			if {$i == $output_regs} {lappend NET_CONNECT(${q_net}_srl_op_net${i}) $srl/Q} else {lappend NET_CONNECT(${q_net}_srl_op_net${i}) ${new_cell_name}/Q}
			lappend NET_CONNECT($clk_net) ${new_cell_name}/C
			lappend NET_CONNECT($ce_net) ${new_cell_name}/CE
			lappend NET_CONNECT($gnd) ${new_cell_name}/${rst}
			if {$i == 1} {lappend NET_CONNECT($q_net) ${new_cell_name}/Q}
			incr i -1
		}
		# disconnect_net -objects $pins_to_disconnect
		foreach pin $pins_to_disconnect {
			set PIN_DISCONNECT($pin) 1
		}
		# set new_cells [create_cell -reference $flop_type [concat $input_regs_to_create $output_regs_to_create]]
		# create_net [concat $input_nets_to_create $output_nets_to_create]
		return  $rt
	}
	
	proc extract_register_from_srl_multi {srl_list ip_reg_list op_reg_list {flop_type_list ""}} {
		# Summary:
		# Apply SRL register extraction over multiple SRLs and aggregate per-SRL extraction results.
		#
		# Argument Usage:
		# srl_list ip_reg_list op_reg_list {flop_type_list ""}
		#
		# Return Value:
		# Aggregated list of extraction results; may raise Tcl error (return -code 2) for invalid list lengths.
		#
		# Categories: xilinxtclstore, customqorflows
		#
		# This is a device edit proc used for experimentation. Caution should be used when using this proc as it has not undergone
		# vigourous verification. It is good for experimentation and what if analysis.
		array set NET_CREATE {}
		array set NET_CONNECT {}
		array set CELL_CREATE {}
		array set PIN_DISCONNECT {}
		if {[llength $srl_list] != [llength $ip_reg_list]} {return -code 2 "-E: srl list length is different to ip_reg_list length. Must be the same- srl [llength $srl_list]  - ip [llength $ip_reg_list]"}
		if {[llength $srl_list] != [llength $op_reg_list]} {return -code 2 "-E: srl list length is different to op_reg_list length. Must be the same- srl [llength $srl_list]  - op [llength $op_reg_list]"}
		if {$flop_type_list eq ""} {set flop_type_list [string repeat "FDRE " [llength $srl_list]]}
		if {[llength $srl_list] != [llength $flop_type_list]} {return -code 2 "-E: srl list length is different to flop_type_list length. Must be the same or flop_type_list must be set to an empty list"}
		set parents [get_property PARENT $srl_list]
		set i 0
		set rt ""
		foreach srl $srl_list {
			set ip_reg [lindex $ip_reg_list $i]
			set op_reg [lindex $op_reg_list $i]
			set flop_type [lindex $flop_type_list $i]
			set parent [lindex $parents $i]
			lappend rt [::tclapp::xilinx::customqorflows::extract_register_from_srl_single NET_CREATE NET_CONNECT CELL_CREATE PIN_DISCONNECT $srl $parent $ip_reg $op_reg $i $flop_type]
			incr i
		}
		foreach flop_type [lsort -unique $flop_type_list] {
			if {[info exists CELL_CREATE($flop_type)]} {
				# puts "-D: Creating Cells $flop_type [llength $CELL_CREATE($flop_type)]"
				create_cell -reference $flop_type $CELL_CREATE($flop_type)
			}
		}
		#parray NET_CREATE
		#parray NET_CONNECT
		disconnect_net -objects [array names PIN_DISCONNECT]
		create_net [array names NET_CREATE]
		connect_net -net_object_list [array get NET_CONNECT]
		return $rt
	}

	proc generate_gclk_hier_details {gclk_array} {
		# Summary:
		# Build hierarchy-to-global-clock mapping data used by GT floorplan analysis.
		#
		# Argument Usage:
		# gclk_array
		#
		# Return Value:
		# No explicit return. Updates caller array by upvar (side effect).
		#
		# Categories: xilinxtclstore, customqorflows
		#
		upvar $gclk_array GCLK_ARR
		create_property NUM_GCLKS cell -type int -description "Number of global clocks in the hierarchy"

		set nets [get_nets -parent -hier -filter {TYPE==GLOBAL_CLOCK}]
		foreach net $nets {
			set segments [get_nets -segments $net]
			set parents [get_property PARENT_CELL $segments]        
			foreach parent $parents {
				if {$parent ne ""} {
					incr NUM_CLKS($parent)
					lappend GCLK_ARR($parent) $net
				}
			}
		}
		foreach name [array names NUM_CLKS] {
			set tmp $NUM_CLKS($name)
			lappend PROP_NUM_CLKS($tmp) $name
		}
		foreach name [array names PROP_NUM_CLKS] {
			# puts "$name - [llength $PROP_NUM_CLKS($name)]"
			set_property NUM_GCLKS $name [get_cells -quiet $PROP_NUM_CLKS($name)]
		}
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
		foreach cr [lsort -dictionary [get_clock_regions -quiet -of $slr]] {
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

	proc get_multi_clock_net_data {{clock_nets ""} {mode "mode0"}} {
		# Summary:
		# Collects clock network properties, categorized by mode (mode0=minimal, mode1=extended with GT/non-GT ranking).
		#
		# Argument Usage:
		# clock_nets - Optional list of clock nets to analyze (default: "" analyzes all global clock nets)
		# mode - Analysis mode: "mode0" (default) or "mode1" (adds PARENT_INFO, DRIVING_CELL_INFO, CATEGORY_INFO)
		#
		# Return Value:
		# Dictionary mapping each clock_net to its properties dict (keys vary by mode)
		#
		# Categories: xilinxtclstore, customqorflows
		#
		set debug 0
		
		# Either work on an input list of clocks or all global clocks
		if {$clock_nets eq ""} {
			set clock_nets [get_nets -parent -hier -filter {TYPE==GLOBAL_CLOCK}]
		}
		
		set clock_net_dict [dict create]

		# This is a property mapping to enable generation of only the properties required. It is intended to make
		# this proc more reusable for different information gathering
		set gen_parent_net_info 0
		set gen_driving_pin_info 0
		set gen_category_info 0
		set mode [string tolower $mode]
		if {$mode eq "mode1"} {
			# Add clock_info
			set gen_parent_net_info 1
			set gen_driving_pin_info 1
			set gen_category_info 1

		}

		if {$gen_parent_net_info} {
			foreach item [list USER_CLOCK_ROOT USER_CLOCK_EXPANSION_WINDOW USER_CLOCK_VTREE_TYPE FLAT_PIN_COUNT GCLK_DESKEW] {
					set props [get_property -quiet $item $clock_nets]
					set i 0
					foreach clock_net $clock_nets {
					dict set clock_net_dict $clock_net PARENT_INFO 1
					set prop [lindex $props $i]
					if {$prop ne ""} {
							dict set clock_net_dict $clock_net $item $prop
					}
					incr i
					}       
			}                
		}

		if {$gen_driving_pin_info} {
			set driving_pins [get_pins -quiet -leaf -filter {DIRECTION==OUT} -of $clock_nets]
			set driving_pin_ref_name [get_property REF_NAME $driving_pins]
			if {[llength $driving_pins] == [llength $clock_nets]} {
				set i 0
				foreach clock_net $clock_nets {
					dict set clock_net_dict $clock_net DRIVING_CELL_INFO 1
					dict set clock_net_dict $clock_net DRIVING_CELL_REF_NAME [lindex $driving_pin_ref_name $i]
					incr i 
				}
			}
		}

		if {$gen_category_info} {
			#dict set clock_net_dict $clock_net CATEGORY_INFO 1
			set clock_nets_sorted [::tclapp::xilinx::customqorflows::sort_by_property $clock_nets FLAT_PIN_COUNT decreasing]
			set drv_pins [get_pins -filter {DIRECTION==OUT} -leaf -of $clock_nets_sorted]
			set drv_ref [get_property REF_NAME $drv_pins]
			set i 0
			set j 1
			set k 1
			foreach clock_net $clock_nets_sorted {
				dict set clock_net_dict $clock_net HIGHEST_CLOCK_LOADS [expr $i + 1]
				if {[string range [lindex $drv_ref $i] end-6 end] eq "BUFG_GT"} {
						dict set clock_net_dict $clock_net HIGHEST_GT_CLOCK_LOADS  $j
						incr j
				} else {
					dict set clock_net_dict $clock_net HIGHEST_NONGT_CLOCK_LOADS  $k
					incr k
				}
				incr i
			}  
		}

		# Return the collected data
		return $clock_net_dict
	}

	proc get_multi_hier_cell_data {levelup_dict {cells ""} {mode "mode0"}} {
		# Summary:
		# Collects hierarchical cell properties into a caller's dictionary, with property scope determined by mode.
		#
		# Argument Usage:
		# levelup_dict - Dictionary variable name (by reference via upvar) to receive cell data
		# cells - Optional list of cells to analyze (default: "" analyzes all hierarchical cells)
		# mode - Analysis mode: "mode0" (minimal) or "mode1" (adds PROPERTY_INFO for ORIG_REF_NAME, PARENT, X_CORE_INFO, etc.)
		#
		# Return Value:
		# No explicit return; populates caller's hier_cell_dict dictionary via upvar with collected cell properties
		#
		# Categories: xilinxtclstore, customqorflows
		#
		upvar 1 $levelup_dict hier_cell_dict
		set debug 0
		
		# Either work on an input list of clocks or all global clocks
		if {$cells eq ""} {
			set cells [get_cells -hier -filter {IS_PRIMITIVE==0}]
		}
		
		# This is a property mapping to enable generation of only the properties required. It is intended to make
		# this proc more reusable for different information gathering
		set gen_property_info 0
		set gen_category_info 0
		set gen_num_global_clocks 0
		set mode [string tolower $mode]
		if {$mode eq "mode1"} {
			set gen_property_info 1
			# set gen_num_global_clocks 1
		}

		if {$gen_property_info} {
			foreach item [list ORIG_REF_NAME PARENT X_CORE_INFO XPM NUM_GCLKS] {
					set props [get_property -quiet $item $cells]
					set i 0
					foreach cell $cells {
					dict set hier_cell_dict $cell PROPERTY_INFO 1
					set prop [lindex $props $i]
					if {$prop ne ""} {
							dict set hier_cell_dict $cell $item $prop
					}
					incr i
					}       
			}                
		}

		# Do not use this is slow
		if {$gen_num_global_clocks} {
			dict set hier_cell_dict GCLK_INFO 1
			set nets [get_nets -parent -hier -filter {TYPE==GLOBAL_CLOCK}]
			foreach net $nets {
				set segments [get_nets -segments $net]
				set parents [get_property PARENT_CELL $segments]
				foreach parent $parents {
					if {$parent ne ""} {
						if {[dict exists $hier_cell_dict $parent GCLKS]} {set tmp [dict get $hier_cell_dict $parent GCLKS]} else {set tmp ""}
						lappend tmp $net
						dict set hier_cell_dict $parent GCLKS $tmp
					}
				}
			}
		}
	}

	proc get_single_clock_net_data {{clock_net ""} {mode "mode0"}} {
		# Summary:
		# Collects detailed clock network data including source, load, and parent information based on mode.
		#
		# Argument Usage:
		# clock_net - Optional clock net (default: "" uses selected object)
		# mode - Analysis mode: "mode0" (minimal) or "mode1" (adds SOURCE_INFO and LOAD_INFO with BUFG/advanced cell filtering)
		#
		# Return Value:
		# Dictionary with keys: PARENT_INFO, SOURCE_INFO, LOAD_INFO sections containing nested property dicts
		#
		# Categories: xilinxtclstore, customqorflows
		#
		# Description:
		# This procedure generates data for a clock net. It is expected that of all the 
		# segments for a given clock net, the data is logged against the parent_net in order
		# to not generate the same data more than once.
		# Different data is generated depending on mode. The data that is generated based on 
		# mode is described below.
		# The proc can return a new dictionary or it can add/overwrite additional data to an 
		# existing dictionary supplied as clock_net_dict
		#
		# Supported Modes
		# ===============
		# mode1  - Generates the following data: 
		#          # parent_info
		#          # source_info
		#          # load_info
		#
		# Generated Info
		# ==============
		# parent_info
		#          # USER_CLOCK_ROOT
		#          # USER_CLOCK_EXPANSION_WINDOW
		#          # USER_CLOCK_VTREE_TYPE
		#          # FLAT_PIN_COUNT
		#          # GCLK_DESKEW
		#
		# source_info Generates the following information:
		#          # Driving BUFG cell name
		#          # Driving REF_NAME
		#          # Pre driver cell name
		#          # Pre driver REF_NAME
		#          # Pre driver LOC
		#
		# load_info Generates the following information:
		#          # limited to a list of ref_names
		#          # The cell names for a given ref_name
		#          # Any LOC constraints related to the cell

		# DEBUG - Enable debugging for additional output during execution
		set debug 0
		set gen_parent_net_info 0
		set gen_source_info 0
		set gen_load_info 0

		# Initialize the return dictionary
		set clock_net_dict [dict create]
		if {$clock_net eq ""} {set clock_net [get_nets -parent [get_selected_objects]]}

		# This is a property mapping to enable generation of only the properties required. It is intended to make
		# this proc more reusable for different information gathering
		set mode [string tolower $mode]
		if {$mode eq "mode1"} {
			# Add clock_info
			set gen_source_info 1
			set gen_load_info 1
		}

		if {$gen_parent_net_info} {
			dict set clock_net_dict PARENT_INFO 1
			foreach item [list USER_CLOCK_ROOT USER_CLOCK_EXPANSION_WINDOW USER_CLOCK_VTREE_TYPE FLAT_PIN_COUNT GCLK_DESKEW] {
				if {[set prop [get_property -quiet $item $clock_net]] ne ""} {
					dict set clock_net_dict $item $prop
				}					
			}
		}

		if {$gen_source_info} {
			dict set clock_net_dict SOURCE_INFO 1
			set driving_pin [get_pins -quiet -leaf -filter {DIRECTION==OUT} -of $clock_net]
			if {$driving_pin ne ""} {
				set driving_cell [get_cells -of $driving_pin]
				dict set clock_net_dict DRIVING_CELL $driving_cell
				dict set clock_net_dict DRIVING_CELL_REF_NAME [get_property -quiet REF_NAME $driving_cell]
				dict set clock_net_dict DRIVING_CELL_LOC [get_property -quiet LOC $driving_cell]
				dict set clock_net_dict DRIVING_CELL_CR [get_clock_regions -quiet -of [get_sites -quiet [get_property -quiet LOC $driving_cell]]]
				set pre_driving_cell [get_cells -of [get_pins -quiet -leaf -filter {DIRECTION==OUT} -of [get_nets -quiet -of [get_pins -quiet -filter {REF_PIN_NAME==I} -of $driving_cell]]]]
				dict set clock_net_dict PRE_DRIVING_CELL $pre_driving_cell
				dict set clock_net_dict PRE_DRIVING_CELL_REF_NAME [get_property REF_NAME $pre_driving_cell]
				dict set clock_net_dict PRE_DRIVING_CELL_LOC [get_property -quiet LOC $pre_driving_cell]
				dict set clock_net_dict PRE_DRIVING_CELL_LOC_CR [get_clock_regions -quiet -of [get_sites -quiet [get_property -quiet LOC $pre_driving_cell]]]
			}
		}

		if {$gen_load_info} {
			dict set clock_net_dict LOAD_INFO 1
			set load_info_ref_names [lsort -dict [list DCMAC MRMAC ILKNF GTME5_QUAD GTY_QUAD]]
			set load_pins [get_pins -quiet -leaf -filter {DIRECTION==IN} -of $clock_net]
			set load_cells [get_cells -quiet -of $load_pins]
			foreach ref_name [lsort -unique [get_property -quiet REF_NAME $load_cells]] {
				if {[lsearch -sorted $load_info_ref_names $ref_name] == -1} {continue}
				dict set clock_net_dict LOADS_${ref_name} [set ref_cells [filter -quiet $load_cells "REF_NAME==${ref_name}"]]
				dict set clock_net_dict LOADS_${ref_name}_LOCS [get_property -quiet LOC $ref_cells]
				dict set clock_net_dict LOADS_${ref_name}_LOCS_CR [get_clock_regions -quiet -of $ref_cells]
				dict set clock_net_dict LOADS_${ref_name}_LOCS_SLR [get_slrs -quiet -of $ref_cells]
			}
			set ref_cells [filter -quiet $load_cells {PRIMITIVE_GROUP==ADVANCED}]
			if {[llength $ref_cells] > 0} {
				dict set clock_net_dict LOADS_ADVANCED $ref_cells
				dict set clock_net_dict LOADS_ADVANCED_LOCS [get_property -quiet LOC $ref_cells]
				dict set clock_net_dict LOADS_ADVANCED_LOCS_CR [get_clock_regions -quiet -of $ref_cells]
				dict set clock_net_dict LOADS_ADVANCED_LOCS_SLR [get_slrs -quiet -of $ref_cells]
			}
		}

		# Return the collected data
		return $clock_net_dict
	}

	proc get_single_hier_cell_data {{cell ""} {mode "mode0"}} {
		# Summary:
		# Collects hierarchical cell data including global clocks, pins, and pblock properties (mode-dependent).
		#
		# Argument Usage:
		# cell - Optional cell name/object (default: "" uses selected hierarchical objects)
		# mode - Analysis mode: "mode0" (minimal) or "mode1" (extended property collection)
		#
		# Return Value:
		# Dictionary with keys: PIN_INFO (pin counts), GCLK_INFO (global clock data), PBLOCK_INFO (pblock associations)
		#
		# Categories: xilinxtclstore, customqorflows
		#
		# Description:
		# This procedure generates data for a hierarchical cell.

		# DEBUG - Enable debugging for additional output during execution
		set debug 0
		set gen_gclk_info 0
		set gen_pin_info 0
		set gen_pblock_info 0

		# Initialize the return dictionary
		set hier_cell_dict [dict create]
		if {$cell eq ""} {set cell [filter [get_selected_objects] {IS_PRIMITIVE==0}]} else {set cell [get_cells $cell]}

		# This is a property mapping to enable generation of only the properties required. It is intended to make
		# this proc more reusable for different information gathering
		set mode [string tolower $mode]
		if {$mode eq "mode1"} {
			# Add clock_info
			# set gen_gclk_info 1
			#set gen_pblock_info 1
		}

		if {$gen_gclk_info} {
			dict set hier_cell_dict GCLK_INFO 1
			set ci [current_inst -quiet $cell]
			set gclks [get_nets -parent -filter {TYPE==GLOBAL_CLOCK}]
			set ci [current_inst -quiet]
			dict set hier_cell_dict GCLKS $gclks
			dict set hier_cell_dict NUM_GCLKS [llength $gclks]
		}

		if {$gen_pin_info} {
			dict set hier_cell_dict PIN_INFO 1
			set all_pins [get_pins -of $cell -filter {IS_CONNECTED}]
			dict set hier_cell_dict NUMBER_OF_PINS [llength $all_pins]
			dict set hier_cell_dict NUMBER_OF_INPUT_PINS [llength [filter $all_pins {DIRECTION==IN}]]
			dict set hier_cell_dict NUMBER_OF_OUTPUT_PINS [llength [filter $all_pins {DIRECTION==OUT}]]
		}

		if {$gen_pblock_info} {
			dict set hier_cell_dict PBLOCK_INFO 1
			dict set hier_cell_dict PBLOCKS [get_pblocks -of $cell]
		}

		# Return the collected data
		return $hier_cell_dict
	}

	proc get_srl_length {srl} {
		# Summary:
		# Determines the depth/length of an SRL by analyzing its address pin net configurations.
		#
		# Argument Usage:
		# srl - SRL cell name or object
		#
		# Return Value:
		# Integer depth value (1, 2, 4, 8, 16, 32, etc.) or -1 if unable to determine from non-static address pins
		#
		# Categories: xilinxtclstore, customqorflows
		#
		# This returns an integer that indicates how long an SRL is
		set length 1
		set address_pins [lsort -dict [get_pins -filter {REF_PIN_NAME=~A*} -of $srl]]
		for {set i 0; set j 1} {$i < [llength $address_pins]} {incr i; set j [expr ${j}*2]} {
			set net [get_nets -of [lindex $address_pins $i]]
			set type [get_property TYPE $net]
			if {$type eq "GROUND"} {
				continue
			} elseif {$type eq "POWER"} {
				incr length $j
			} else {
				return -1
			}
		}
		return $length
	}

    proc is_loc_in_range {loc range {debug 0}} {
        # Summary:
        # Tests if a clock region location falls within a specified range (single SLR supported).
        #
        # Argument Usage:
        # loc - Clock region location in format XmYn or S<d>_XmYn (m, n are integers)
        # range - Clock region range in format Xm1Yn1:Xm2Yn2 or S<d>_Xm1Yn1:S<d>_Xm2Yn2
        # debug - 1 for debug output, 0 for no output (default: 0)
        #
        # Return Value:
        # 1 if location is within range, 0 if outside range, -code 2 error or error string if invalid format
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

	proc profile_static_variable_srls {{cells ""}} {
		# Summary:
		# Separates SRLs into static (non-shifting) and variable (dynamic address) groups for optimization analysis.
		#
		# Argument Usage:
		# cells - Optional cell filter (default: "" analyzes all SRL cells in design)
		#
		# Return Value:
		# Nested list: {static_srls_list variable_srls_list} where each sublist contains cell objects
		#
		# Categories: xilinxtclstore, customqorflows
		#
		set debug 0
		package require struct::set
		# first get static SRLs
		if {$cells eq ""} {
			set all_srls [get_cells -quiet -hier -filter {REF_NAME=~SRL*}]
		} else {
			set all_srls [get_cells -quiet $cells]
		}
		set all_signals [get_nets -quiet -filter {TYPE==SIGNAL} -of [get_pins -quiet -filter {REF_PIN_NAME=~A*} -of $all_srls]]
		set variable_srls [get_cells -quiet -filter {REF_NAME=~SRL*} -of [get_pins -quiet -leaf -of $all_signals]]
		set static_srls [::struct::set difference $all_srls $variable_srls]
		if {$debug == 1} {puts "-D: There are [llength $static_srls] static SRLs to consider for optimization"}
		if {$debug == 1} {puts "-D: [llength [filter $static_srls {REF_NAME==SRLC32E}]] static SRL32s"}
		if {$debug == 1} {puts "-D: [llength [filter $static_srls {REF_NAME=~SRL16*}]] static SRL16s"}
		if {$debug == 1} {puts "-D: There are [llength $variable_srls] variable SRLs. These will not be looked at for optimization"}
		return [list [get_cells -quiet $static_srls] [get_cells -quiet $variable_srls]]
	}

	proc sort_by_property {list_to_sort property_name {sort_type "ascending"}} {
		# Summary:
		# Sorts a list of Vivado objects by an integer property value using custom compare procedures.
		#
		# Argument Usage:
		# list_to_sort - List of Vivado objects (cells, nets, pins, etc.)
		# property_name - Name of the integer property to sort by
		# sort_type - Sort order: "ascending" or "descending" (default: "ascending")
		#
		# Return Value:
		# Sorted list of objects in specified order based on property value
		#
		# Categories: xilinxtclstore, customqorflows
		#
		# Sorts a list based on a property value. Property value must be an integer.
		# Ths has the benefit of sorting a list of objects using lsort instead of foreach.
		# This results in a speed up of script compile time.
		set debug 0
		set start [clock seconds]
		set values [get_property $property_name $list_to_sort]
		for {set i 0} {$i < [llength $list_to_sort]} {incr i} {
			lappend list_with_sorting_factors [list [lindex $values $i] [lindex $list_to_sort $i]]
		}
		if {$sort_type eq "ascending"} {
				set sorted_list [lsort -command ::tclapp::xilinx::customqorflows::compare_ascending $list_with_sorting_factors]
		} else {
				set sorted_list [lsort -command ::tclapp::xilinx::customqorflows::compare_descending $list_with_sorting_factors]	
		}
		foreach obj $sorted_list {
			lappend ret_list [lindex $obj 1]
		}

		set stop [clock seconds]
		if {$debug == 1} {puts "-D: Sorting took [expr $stop - $start] seconds"}
		return $ret_list
	}
	
}