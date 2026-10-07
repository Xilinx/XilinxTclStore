####################################################################################
#
# imr_reg.tcl (customqorflows move fabric registers to IRI_QUAD/IMR suggestion)
#
# Script created on 09/30/2026 by John Blaine, AMD
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::customqorflows {
	#namespace export move_ff_to_imr_reg
}

# CUSTOM QOR TOOLS will pass a dictionary to the proc through the args variable.
# DO NOT ADD ARGUMENTS TO THE PROC

# PREREQUISITE: REGISTER_PIPELINE and PERIOD are populated by the C++ data providers behind
# NEEDS_PIPELINE_DATA / NEEDS_CLK_PERIOD_DATA (registered below), so no manual annotation is
# required for them. NEEDS_CONTROL_SET_DATA (CS.GROUP) is not available yet, so the control-set
# path (ENABLE_CONTROL_SET_CHECK) stays off until its provider lands in C++.
#
# PREREQUISITE: NEEDS_UTILIZATION_DATA (registered below) is expected to place a dict in
# $qor_dict under key UTILIZATION, keyed by resource name (REG, LUT, BRAM, ...), each value a
# "used:available" string. register_usage below is the REG entry's used/available ratio as a
# percentage.

namespace eval ::tclapp::xilinx::customqorflows {

	proc move_ff_to_imr_reg {args} {
		# Summary:
		# Identify fabric registers that drive supported hard-block data inputs and generate
		# commands that set IMR=TRUE on them so they are moved into IRI_QUAD/IMR registers.

		# Argument Usage:
		# args: Optional list from Custom QoR Tools. The proc expects at most one positional entry.
		# [lindex $args 0] = qor_dict (dict): Configuration dictionary. Its PARAMS key is consumed by
		#   ::tclapp::xilinx::customqorflows::update_params PARAMS $qor_dict, and its UTILIZATION
		#   key (from NEEDS_UTILIZATION_DATA) supplies the REG "used:available" utilization.
		#   Supported override keys used by this proc:
		#   - SUPPORTED_PRIMITIVES / SUPPORTED_PINS,<primitive>: Hard-block REF_NAMEs and the
		#     input pin patterns checked on each of them.
		#   - UTIL1_THRESHOLD (Default: 30), UTIL2_THRESHOLD (Default: 60):
		#     REG utilization % boundaries selecting GROUP1 (<= UTIL1), GROUP2 (<= UTIL2) or GROUP3.
		#   - GROUP1/2/3_MIN_REGISTER_PIPELINE (Default: 3/2/1):
		#     Minimum REGISTER_PIPELINE a register needs for the selected group.
		#   - GROUP1/2/3_MAX_PERIOD (Default: 2.000/3.500/10.000):
		#     Maximum clock PERIOD (ns) for the selected group, used when ENABLE_PERIOD_CHECK=1.
		#   - ENABLE_CONTROL_SET_CHECK (Default: 0):
		#     1 = per pin group, keep only the registers in the largest CS.GROUP.
		#   - ENABLE_PERIOD_CHECK (Default: 0):
		#     1 = keep only registers whose clock PERIOD <= the selected group's MAX_PERIOD.
		#   - DEBUG (Default: 0): Enables verbose debug prints (1 = summary, 2 = detailed).
		# Any additional args entries beyond index 0 are unexpected and only emit an error print.

		# Return Value:
		# Empty return (no value): When no qualifying registers are found.
		# dict with keys COMMAND and EST_RESOURCE_CHANGE.FF:
		#   COMMAND is the set_property IMR TRUE command; EST_RESOURCE_CHANGE.FF is the negative
		#   count of moved registers.
		# dict with keys DISABLE_DONT_TOUCH_REQUIRED, COMMAND and EST_RESOURCE_CHANGE.FF:
		#   When some target registers have DONT_TOUCH=TRUE, COMMAND also clears DONT_TOUCH on them.

		# Categories: xilinxtclstore, customqorflows

		# Description
		# The move_ff_to_imr_reg proc finds FDR*/FDC* registers (INIT != 1) that drive the data inputs of
		# RAMB18/36, URAM288, DSP58, GT, NoC, CPM5, HSC and RF/DFE hard blocks and meet the
		# utilization-dependent REGISTER_PIPELINE threshold.

		# Action
		# The suggestion sets the IMR property to TRUE on the qualifying registers so they are placed in
		# the IRI_QUAD/IMR registers in front of the hard block inputs.

		# Applicable for
		# The suggestion requires place_design to be run to be triggered.
		# Reduces fabric register utilization and improves timing into the hard block.

		# Params
		# UTIL1_THRESHOLD/UTIL2_THRESHOLD      - REG utilization % tiers selecting GROUP1/2/3 settings.
		# GROUP<n>_MIN_REGISTER_PIPELINE       - Minimum REGISTER_PIPELINE for a register to qualify.
		# GROUP<n>_MAX_PERIOD                  - Maximum clock period (ns) when ENABLE_PERIOD_CHECK is 1.
		# ENABLE_CONTROL_SET_CHECK             - When set to 1, keeps only the largest control-set group per pin group.
		# ENABLE_PERIOD_CHECK                  - When set to 1, excludes registers on clocks slower than GROUP<n>_MAX_PERIOD.

		set start [clock seconds]

		# Tuning parameters
		set PARAMS(SUPPORTED_PRIMITIVES) [list RAMB18E5_INT RAMB36E5_INT URAM288E5 URAM288E5_BASE DSP58 GTYP_QUAD GTME5_QUAD NOC_NMU512 NOC_NSU512 HSC CPM5 DFE_CHANNELIZER BFR_FT RFDACE5 SDFEC_LD MRMAC DCMAC ILKNF PCIE50E5]
		set PARAMS(SUPPORTED_PINS,RAMB18E5_INT) [list DINADIN\[*\] DINBDIN\[*\] DINPADINP\[*\] DINPBDINP\[*\]]
		set PARAMS(SUPPORTED_PINS,RAMB36E5_INT) [list DINADIN\[*\] DINBDIN\[*\] DINPADINP\[*\] DINPBDINP\[*\]]
		set PARAMS(SUPPORTED_PINS,URAM288E5) [list DIN_A\[*\] DIN_B\[*\]]
		set PARAMS(SUPPORTED_PINS,URAM288E5_BASE) [list DIN_A\[*\] DIN_B\[*\]]
		set PARAMS(SUPPORTED_PINS,DSP58) [list A\[*\] B\[*\] C\[*\] D\[*\]]
		set PARAMS(SUPPORTED_PINS,GTYP_QUAD) [list CH*_TXDATA\[*\]]
		set PARAMS(SUPPORTED_PINS,GTME5_QUAD) [list CH*_TXDATA\[*\]]
		set PARAMS(SUPPORTED_PINS,NOC_NMU512) [list IF_NOC_AXI_WDATA\[*\]]
		set PARAMS(SUPPORTED_PINS,NOC_NSU512) [list IF_NOC_AXI_RDATA\[*\]]
		set PARAMS(SUPPORTED_PINS,HSC) [list DEC_IGR_AXIS_TDATA*\[*\] ENC_IGR_AXIS_TDATA*\[*\]]
		set PARAMS(SUPPORTED_PINS,CPM5) [list IFCPM5PLMPIO*AXISRQTDATA\[*\] IFCPM5PLMPIO*AXISCCTDATA\[*\] IFPLCPM5P*CHIWDATFLIT\[*\] IFCPM5PLAXI*RDATA\[*\] IFCPM5PLMPIO*AXISRQTUSER\[*\] IFCPM5PLMPIO*AXISCCTUSER\[*\] IFCPM5PLMPIO*CFGREQTXTDATA\[*\] IFPLCPM5P*CHIREQFLIT\[*\] IFCPM5PLAXI*RUSER\[*\] IFCPM5PLMPIO*CFGINTERRUPTMSIXADDRESS\[*\]]
		set PARAMS(SUPPORTED_PINS,DFE_CHANNELIZER) [list S_AXIS_DIN*_TDATA\[*\]]
		set PARAMS(SUPPORTED_PINS,BFR_FT) [list IF_S_AXIS_DIN_TDATA\[*\]]
		set PARAMS(SUPPORTED_PINS,RFDACE5) [list DATA_DAC*\[*\]]
		set PARAMS(SUPPORTED_PINS,SDFEC_LD) [list S_AXIS_LD_DIN_TDATA\[*\]]
		set PARAMS(SUPPORTED_PINS,MRMAC) [list TX_AXIS_TDATA*\[*\]]
		set PARAMS(SUPPORTED_PINS,DCMAC) [list TX_AXIS_TDATA*\[*\]]
		set PARAMS(SUPPORTED_PINS,ILKNF) [list TX_AXIS_TDATA*\[*\]]
		set PARAMS(SUPPORTED_PINS,PCIE50E5) [list SAXIS??TDATA\[*\]]
		set PARAMS(UTIL1_THRESHOLD) 30
		set PARAMS(UTIL2_THRESHOLD) 60
		set PARAMS(GROUP1_MIN_REGISTER_PIPELINE) 3
		set PARAMS(GROUP2_MIN_REGISTER_PIPELINE) 2
		set PARAMS(GROUP3_MIN_REGISTER_PIPELINE) 1
		set PARAMS(GROUP1_MAX_PERIOD) 2.000
		set PARAMS(GROUP2_MAX_PERIOD) 3.500
		set PARAMS(GROUP3_MAX_PERIOD) 10.000
		set PARAMS(ENABLE_CONTROL_SET_CHECK) 0
		set PARAMS(ENABLE_PERIOD_CHECK) 0
		set PARAMS(DEBUG) 0

		# QoR dict setup (DO NOT MODIFY)
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

		# Variables
		set target_objs ""
		set dont_touch_objs ""
		set command ""

		# Start of suggestion content
		# ===========================

		# NEEDS_UTILIZATION_DATA: extract REG usage %, per references/NEEDS_UTILIZATION_DATA.md.
		set register_usage 0
		if {[dict exists $qor_dict UTILIZATION]} {
			set util_dict [dict get $qor_dict UTILIZATION]
			if {[dict exists $util_dict REG]} {
				set reg_info [split [dict get $util_dict REG] :]
				if {[llength $reg_info] >= 2 && [lindex $reg_info 1] > 0} {
					set register_usage [expr [lindex $reg_info 0].0 / [lindex $reg_info 1] * 100]
					set register_usage [format "%.2f" $register_usage]
				}
			}
		}

		if {$register_usage <= $PARAMS(UTIL1_THRESHOLD)} {
			set min_pipe $PARAMS(GROUP1_MIN_REGISTER_PIPELINE)
			set max_period $PARAMS(GROUP1_MAX_PERIOD)
		} elseif {$register_usage > $PARAMS(UTIL1_THRESHOLD) && $register_usage <= $PARAMS(UTIL2_THRESHOLD)} {
			set min_pipe $PARAMS(GROUP2_MIN_REGISTER_PIPELINE)
			set max_period $PARAMS(GROUP2_MAX_PERIOD)
		} else {
			set min_pipe $PARAMS(GROUP3_MIN_REGISTER_PIPELINE)
			set max_period $PARAMS(GROUP3_MAX_PERIOD)
		}
		if {$debug >= 2} {puts "-D: register_usage=$register_usage -> min_pipe=$min_pipe max_period=$max_period"}

		set registers ""

		if {$PARAMS(ENABLE_CONTROL_SET_CHECK) == 0} {
			# Faster path: no control-set compatibility check.
			set pin_list ""
			foreach primitive $PARAMS(SUPPORTED_PRIMITIVES) {
				set cells [get_cells -quiet -hier -filter "REF_NAME==${primitive}"]
				if {[llength $cells] == 0} {continue}
				set pin_terms {}
				foreach pin_pattern $PARAMS(SUPPORTED_PINS,$primitive) {
					lappend pin_terms "REF_PIN_NAME =~ \"${pin_pattern}\""
				}
				set pin_filter "[join $pin_terms { || }]"
				set pin [get_pins -quiet -filter ${pin_filter} -of_objects $cells]
				set pin_list [concat $pin_list $pin]
			}
			if {[llength $pin_list] > 0} {
				set registers [get_cells -quiet -filter "INIT != 1 && (REF_NAME=~FDR* || REF_NAME=~FDC*) && REGISTER_PIPELINE >= $min_pipe" -of [get_pins -quiet -leaf -filter {REF_NAME=~FD*} -of [get_nets -quiet -of $pin_list]]]
			}
		} elseif {$PARAMS(ENABLE_CONTROL_SET_CHECK) == 1} {
			# Slower path: per-cell/per-pin-group control-set compatibility check, keeping only
			# the largest CS.GROUP within each group (control-set mismatch does not error, it is
			# just less likely to place cleanly into IMR - see IRI_QUAD details).
			foreach primitive $PARAMS(SUPPORTED_PRIMITIVES) {
				set prim_cells [get_cells -quiet -hier -filter "REF_NAME==${primitive}"]
				if {[llength $prim_cells] == 0} {continue}
				foreach cell $prim_cells {
					foreach pin_term $PARAMS(SUPPORTED_PINS,$primitive) {
						set pin_list [get_pins -quiet -filter "REF_PIN_NAME =~ ${pin_term}" -of_objects $cell]
						if {[llength $pin_list] == 0} {continue}
						set register_group [get_cells -quiet -filter "INIT != 1 && (REF_NAME=~FDR* || REF_NAME=~FDC*) && REGISTER_PIPELINE >= $min_pipe" -of [get_pins -quiet -leaf -filter {REF_NAME=~FD*} -of [get_nets -quiet -of $pin_list]]]
						if {[llength $register_group] == 0} {continue}

						set cs_groups [lsort -integer -unique [get_property CS.GROUP $register_group]]
						if {[llength $cs_groups] != 1} {
							# sort_by_property (common/custom_qor_utilities.tcl) does the
							# pair-and-sort work so we don't hand-roll it here.
							set sorted_registers [::tclapp::xilinx::customqorflows::sort_by_property $register_group CS.GROUP]
							set sorted_groups [get_property CS.GROUP $sorted_registers]
							set max_count 0
							set largest_grp_cells {}
							foreach grp $cs_groups {
								set idxs [lsearch -sorted -integer -all $sorted_groups $grp]
								set grp_cells {}
								foreach idx $idxs {
									lappend grp_cells [lindex $sorted_registers $idx]
								}
								set grp_count [llength $grp_cells]
								if {$grp_count > $max_count} {
									set max_count $grp_count
									set largest_grp_cells $grp_cells
								}
							}
							set register_group $largest_grp_cells
						}
						set registers [concat $registers $register_group]
					}
				}
			}
		}

		if {$PARAMS(ENABLE_PERIOD_CHECK) == 1 && [llength $registers] > 0} {
			if {$debug > 0} {
			   puts "-D: Limiting cells to meet period check. Reg count before [llength $registers], period $max_period"
			}
			set registers [get_cells -quiet -of [get_pins -quiet -of $registers -filter "IS_CLOCK && PERIOD <= $max_period"]]
			if {$debug > 0} {
			   puts "-D: Reg count after [llength $registers]"
			}
		}
		set target_objs [lsort -unique $registers]

		# End of suggestion content
		# =========================

		if {$debug >= 1} {puts "-D: Target objects: [llength $target_objs]"}

		set ret_dict [dict create]
		if {[llength $target_objs] > 0} {
			if {$debug >= 2} {puts "-D: Target objects: [lsort -dict $target_objs]"}

			set command [::tclapp::xilinx::customqorflows::pretty_command_property IMR TRUE $target_objs]

			# DONT_TOUCH handling
			set dont_touch_objs [filter $target_objs {DONT_TOUCH == TRUE}]
			if {[llength $dont_touch_objs] > 0} {
				set command "[::tclapp::xilinx::customqorflows::pretty_command_property DONT_TOUCH 0 $dont_touch_objs]\n${command}"
				dict set ret_dict DISABLE_DONT_TOUCH_REQUIRED 1
			}

			dict set ret_dict COMMAND $command
			# Moving registers to IMR reduces fabric FF usage, hence the negative count.
			dict set ret_dict EST_RESOURCE_CHANGE.FF -[llength $target_objs]
			if {$debug >= 1} {puts "-D: EST_RESOURCE_CHANGE.FF: -[llength $target_objs]"}
		} else {
			if {$debug == 1} {puts "-D: No commands generated"}
		}

		set stop [clock seconds]
		::tclapp::xilinx::customqorflows::compile_time $start $stop "" MOVE_FF_TO_IMR_REG
		if {[llength [dict keys $ret_dict]] == 0} {return}
		return $ret_dict
	}

	proc register_move_ff_to_imr_reg {} {
		# The following sets up the suggestion in the Custom QoR Tools.
		# ==================================================
		set id RQS_AMD_UTIL-1
		set description "Move eligible fabric registers into IRI_QUAD/IMR registers in front of RAMB18/36, URAM288, DSP58, GT, NoC, CPM5, HSC and RF/DFE hard-block inputs. Reduces register utilization and improves timing into the hard block."
		set auto 1
		set category Utilization
		set applicable_for place_design
		set needs_pipeline_data 1
		set needs_utilization_data 1
		set needs_clk_period_data 1 ;
		set needs_control_set_data 0 ; # NOT IMPLEMENTED YET
		set params [dict create \
			UTIL1_THRESHOLD 30 \
			UTIL2_THRESHOLD 60 \
			GROUP1_MIN_REGISTER_PIPELINE 3 \
			GROUP2_MIN_REGISTER_PIPELINE 2 \
			GROUP3_MIN_REGISTER_PIPELINE 1 \
			GROUP1_MAX_PERIOD 2.000 \
			GROUP2_MAX_PERIOD 3.500 \
			GROUP3_MAX_PERIOD 10.000 \
			ENABLE_CONTROL_SET_CHECK 0 \
			ENABLE_PERIOD_CHECK 0 \
			DEBUG 3]

		catch "delete_qor_check ${id} -quiet"
		create_qor_check -name ${id} -rule_body ::tclapp::xilinx::customqorflows::move_ff_to_imr_reg \
			-property_values [list DESCRIPTION $description \
								   AUTO $auto \
								   CATEGORY $category \
								   APPLICABLE_FOR $applicable_for \
								   NEEDS_PIPELINE_DATA $needs_pipeline_data \
								   NEEDS_CLK_PERIOD_DATA $needs_clk_period_data \
								   NEEDS_CONTROL_SET_DATA $needs_control_set_data \
								   NEEDS_UTILIZATION_DATA $needs_utilization_data \
								   PARAMS $params]
	}

	register_move_ff_to_imr_reg
}
