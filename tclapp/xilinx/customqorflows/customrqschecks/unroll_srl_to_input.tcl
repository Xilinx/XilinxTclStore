####################################################################################
#
# unroll_srl_to_input.tcl (customqorflows SRL suggestion)
#
# Script created on 03/30/2026 by Madhur Chhabra, AMD
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::customqorflows {
	#namespace export unroll_srl_to_input
}

namespace eval ::tclapp::xilinx::customqorflows {

	proc unroll_srl_to_input {args} {
		# Summary:
		# Identify SRLs directly driven by LUT outputs and generate commands that set
		# SRL_STAGES_TO_REG_INPUT=1 on qualifying SRLs.

		# Argument Usage:
		# args: Optional list from Custom QoR Tools. The proc expects at most one positional entry.
		# [lindex $args 0] = qor_dict (dict): Parameter override dictionary consumed by
		#   ::tclapp::xilinx::customqorflows::update_params PARAMS $qor_dict.
		#   Supported override keys used by this proc:
		#   - EXCLUDE_LUT_COMB (Default: 1):
		#     0 = include LUT-combined paths; 1 = exclude LUTs with SOFT_HLUTNM != "".
		#   - EXCLUDE_LUT_COMB_FDC_ONLY (Default: 1, requires EXCLUDE_LUT_COMB != 0):
		#     When enabled, LUT-combined groups are filtered out only when they drive
		#     no FDC* sinks in the checked pair/group traversal.
		#   - DEBUG (Default: 0): Enables verbose debug prints.
		# Any additional args entries beyond index 0 are unexpected and only emit an error print.

		# Return Value:
		# Empty return (no value): When no qualifying SRLs are found or no command is generated.
		# dict with key COMMAND: [dict create COMMAND $command]
		# dict with keys DISABLE_DONT_TOUCH_REQUIRED and COMMAND:
		#   [dict create DISABLE_DONT_TOUCH_REQUIRED 1 COMMAND $command]
		# In the current implementation, dont_touch_objs is never populated, so the common
		# return form is a dict containing only COMMAND.

		# Categories: xilinxtclstore, customqorflows

		# Description
		# The unroll_srl_to_input proc extracts a register from SRL inputs that are driven by LUTs. Fanout from LUT must be 1.
		
		# Action
		# The suggestion will set the SRL_STAGES_TO_REG_INPUT property to 1 to extract the cells.
		
		# Applicable for
		# The suggestion requires place_design is run to be triggered. It in turn triggers an opt_design call inside the placer.
		# Will improve timing to SRLs but will increase flops and possibly increase control sets
		
		# Params
		# EXCLUDE_LUT_COMB          - When set to 1, SRLs driven by LUTs that also have SOFT_HLUTNM constraints are excluded.
		# EXCLUDE_LUT_COMB_FDC_ONLY - When set to 1, if the lut combined LUT is driving a registers with CLR pin, the cell is excluded 
		
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
		
		# Tuning parameters
		set PARAMS(EXCLUDE_LUT_COMB)          1
		set PARAMS(EXCLUDE_LUT_COMB_FDC_ONLY) 1 ; # requires $PARAMS(EXCLUDE_LUT_COMB) != 0
		set PARAMS(DEBUG) 0
		::tclapp::xilinx::customqorflows::update_params PARAMS $qor_dict
		
		# DEBUG
		set debug $PARAMS(DEBUG)
		
		# Variables
		set target_objs ""
		set require_dont_touch 0
		set dont_touch_objs ""
		set command ""
		set luts_driving_srls_lc_filtered ""
		
		# Start of suggestion content
		# ===========================
		set static_srls [lindex [::tclapp::xilinx::customqorflows::profile_static_variable_srls] 0]
		if {[llength $static_srls] == 0} {return}
		if {$PARAMS(EXCLUDE_LUT_COMB) == 0} {
			set luts_driving_srls [get_cells -filter {REF_NAME=~LUT*} -of [get_pins -leaf -filter {DIRECTION==OUT} -of [get_nets -filter {FLAT_PIN_COUNT==2} -of [get_pins -filter {REF_PIN_NAME==D} -of $static_srls]]]]
		} else {
			if {$PARAMS(EXCLUDE_LUT_COMB_FDC_ONLY) == 1} {
				set luts_driving_srls [get_cells -quiet -filter {REF_NAME=~LUT*} -of [get_pins -quiet -leaf -filter {DIRECTION==OUT} -of [get_nets -quiet -filter {FLAT_PIN_COUNT==2} -of [get_pins -filter {REF_PIN_NAME==D} -of $static_srls]]]]
				set luts_driving_srls_nonlc [filter $luts_driving_srls {SOFT_HLUTNM==""}]
				set luts_driving_srls_lc [filter $luts_driving_srls {SOFT_HLUTNM!=""}]
				set cur_in [current_instance -quiet ./]
				foreach parent [lsort -unique [get_property -quiet PARENT $luts_driving_srls_lc]] {
					current_instance [get_cells -quiet $parent]
					if {$parent ne ""} {
						set lc_cells [filter $luts_driving_srls_lc "PARENT==$parent"]
					} else {
						set lc_cells  [filter $luts_driving_srls_lc {PARENT==""}]
					}
					set sf_hlutnms [lsort -unique [get_property SOFT_HLUTNM $lc_cells]]
					foreach sf_hlutnm $sf_hlutnms {
						set checking_cells [get_cells -filter "SOFT_HLUTNM==$sf_hlutnm"]
						if {$debug == 1} {
							if {[llength $checking_cells] !=2} {puts "PARENT: $parent SOFT_HLUTNM: $sf_hlutnm"; continue}
						}
						set cells_driven_by_lc [get_cells -of [get_pins -leaf -filter {REF_PIN_NAME==D} -of [get_nets -filter {FLAT_PIN_COUNT==2} -of [get_pins -filter {DIRECTION==OUT} -of $checking_cells]]]]
						if {[llength [filter -quiet $cells_driven_by_lc {REF_NAME=~FDC*}]] == 0} {set luts_driving_srls_lc_filtered [concat $luts_driving_srls_lc_filtered $checking_cells]}
					}
					current_instance -quiet $cur_in
				}
				if {$debug == 1} {puts "-D: Number of luts_driving_srls_lc_filtered: [llength $luts_driving_srls_lc_filtered]"}
				set luts_driving_srls [concat $luts_driving_srls_lc_filtered $luts_driving_srls_nonlc]
			} else {
				set luts_driving_srls_nonlc [get_cells -quiet -filter {REF_NAME=~LUT*&&SOFT_HLUTNM==""} -of [get_pins -leaf -filter {DIRECTION==OUT} -of [get_nets -filter {FLAT_PIN_COUNT==2} -of [get_pins -filter {REF_PIN_NAME==D} -of $static_srls]]]]
				set luts_driving_srls $luts_driving_srls_nonlc
			}
		}
		if {[llength $luts_driving_srls] == 0} {return}
		set srls_driven_by_luts [get_cells -of [get_pins -leaf -filter {REF_PIN_NAME==D} -of [get_nets -of [get_pins -filter {DIRECTION==OUT} -of $luts_driving_srls]]]]
		if {[llength $srls_driven_by_luts] > 0} {
			if {$debug == 1} {puts "-D: Adding SRL_STAGES_TO_REG_INPUT=1 property to [llength $srls_driven_by_luts]"}
			set target_objs $srls_driven_by_luts
		} else {
			if {$debug == 1} {puts "-D: There are no SRL16s found being directly driven by a LUT"}
			return
		}
		
		# End of suggestion content
		# =========================
		
		if {$debug >= 1} {puts "-D: Target_objects: [lsort -dict $target_objs]"}
		if {[llength $target_objs] > 0} {
			if {[llength $dont_touch_objs] > 0} {
				set require_dont_touch 1
				set command [::tclapp::xilinx::customqorflows::pretty_command_property DONT_TOUCH 0 $dont_touch_objs]
			}
			set command [concat $command [::tclapp::xilinx::customqorflows::pretty_command_property SRL_STAGES_TO_REG_INPUT 1 $target_objs]]
		}
		set stop [clock seconds]
		::tclapp::xilinx::customqorflows::compile_time $start $stop 
		if {$command eq ""} {
			return
		} elseif {$require_dont_touch != 0} { 
			return [dict create DISABLE_DONT_TOUCH_REQUIRED 1 COMMAND $command]
		} else {
			return [dict create COMMAND $command]
		}
	}
	
	# The following sets up the suggestion in the Custom QoR Tools.
	# ==================================================
	set id RQS_AMD_NETLIST-1
	set description "Extract registers from SRLs that are driven by LUTs."
	set auto 1
	set category netlist
	set applicable_for place_design
	set switches "-property_opt_only"
	set needs_timing_data 0

	catch "delete_qor_check ${id} -quiet"
	create_qor_check -name ${id} -rule_body ::tclapp::xilinx::customqorflows::unroll_srl_to_input \
		-property_values [list DESCRIPTION $description \
							   AUTO $auto \
							   CATEGORY $category \
							   APPLICABLE_FOR $applicable_for\
							   NEEDS_TIMING_DATA $needs_timing_data \
							   ]
}

