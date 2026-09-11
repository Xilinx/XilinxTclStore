####################################################################################
#
# move_iob_to_bli.tcl (customqorflows move IOB registers to BLI suggestion)
#
# Script created on 03/30/2026 by Madhur Chhabra, AMD
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::customqorflows {
	#namespace export timing_move_iob_to_bli
}

namespace eval ::tclapp::xilinx::customqorflows {

	proc timing_move_iob_to_bli {args} {
		set start [clock seconds]

		# Tuning parameters
		set PARAMS(ONLY_CALIBRATED_CLOCKS) 1
		set PARAMS(INPUT_MIN_REQUIREMENT) inf
		set PARAMS(OUTPUT_MAX_REQUIREMENT) inf
		set PARAMS(IOB_TRUE_FILTER) 0
		set PARAMS(FLAT_PIN_COUNT_CHECK) 1
		set PARAMS(FLAT_PIN_COUNT_VALUE) 2
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
		set target_registers ""
		set output_target_registers ""
		set input_target_registers ""
		set dont_touch_objs ""
		set command ""
		
		# Start of suggestion content
		# ===========================
		
		if {$debug >= 1} {puts "-D: Starting IOB to BLI analysis"}
		
		# STEP 1: Process Output Registers
		# Find output ports (include INOUT)
		set output_ports [get_ports -quiet -filter {DIRECTION==OUT||DIRECTION==INOUT}]
		if {$debug >= 2} {puts "-D: Found [llength $output_ports] output ports"}
		
		if {[llength $output_ports] > 0} {
			# Trace nets driving the OBUF inputs
			set output_nets [get_nets -quiet -of \
				[get_pins -quiet -filter {DIRECTION==IN} -of \
					[get_cells -quiet -of \
						[get_pins -quiet -leaf -filter {REF_NAME=~*OBUF*} -of \
							[get_nets -quiet -of $output_ports]]]]]
			# Optional fanout filter
			if {$PARAMS(FLAT_PIN_COUNT_CHECK) == 1 && [llength $output_nets] > 0} {
				set output_nets [filter $output_nets "FLAT_PIN_COUNT<=$PARAMS(FLAT_PIN_COUNT_VALUE)"]
			}
			# Resolve driving registers from those nets
			set output_registers [get_cells -quiet -of \
				[get_pins -quiet -leaf -filter {REF_NAME=~FD* && DIRECTION==OUT} -of $output_nets]]
			# Optional IOB=TRUE filter
			if {$PARAMS(IOB_TRUE_FILTER) == 1 && [llength $output_registers] > 0} {
				set output_registers [filter $output_registers {IOB==TRUE}]
			}
			
			if {$debug >= 2} {puts "-D: Found [llength $output_registers] output registers"}
			
			if {[llength $output_registers] > 0} {
				# Run report timing for output paths (setup)
				set tps [get_timing_paths -quiet -delay_type max -from $output_registers -to $output_ports -max_paths [llength $output_registers] -unique_pins -nworst 2]
				
				if {$debug >= 2} {puts "-D: Analyzing [llength $tps] timing paths from output registers"}
				
				# Process each path
				foreach tp $tps req [get_property -quiet REQUIREMENT $tps] sp [get_property -quiet STARTPOINT_PIN $tps] {
					set reg [string range $sp 0 end-2]
					
					# Check if requirement meets threshold
					if {$req eq "inf" || $req eq ""} {
						lappend output_target_registers $reg
						if {$debug >= 3} {puts "-D: Output register $reg qualifies (requirement: $req)"}
					} elseif {$PARAMS(OUTPUT_MAX_REQUIREMENT) ne "inf" && $req <= $PARAMS(OUTPUT_MAX_REQUIREMENT)} {
						lappend output_target_registers $reg
						if {$debug >= 3} {puts "-D: Output register $reg qualifies (requirement: $req <= $PARAMS(OUTPUT_MAX_REQUIREMENT))"}
					}
				}
			}
		}
		
		if {$debug >= 1} {puts "-D: Output target registers: [llength $output_target_registers]"}
		
		# STEP 2: Process Input Registers
		# Find input ports (include INOUT)
		set input_ports [get_ports -quiet -filter {DIRECTION==IN||DIRECTION==INOUT}]
		if {$debug >= 2} {puts "-D: Found [llength $input_ports] input ports"}
		
		if {[llength $input_ports] > 0} {
			# Find input buffers driven by these ports
			set ibufs [get_cells -quiet -of \
				[get_pins -quiet -leaf -filter {REF_NAME=~I*BUF*} -of \
					[get_nets -quiet -of $input_ports]]]
			# Trace nets coming out of the IBUFs
			set input_nets [get_nets -quiet -of \
				[get_pins -quiet -filter {DIRECTION==OUT} -of $ibufs]]
			# Optional fanout filter
			if {$PARAMS(FLAT_PIN_COUNT_CHECK) == 1 && [llength $input_nets] > 0} {
				set input_nets [filter $input_nets "FLAT_PIN_COUNT<=$PARAMS(FLAT_PIN_COUNT_VALUE)"]
			}
			# Resolve receiving registers from those nets
			set input_registers [get_cells -quiet -of \
				[get_pins -quiet -leaf -filter {REF_PIN_NAME==D && REF_NAME=~FD* && DIRECTION==IN} -of $input_nets]]
			# Optional IOB=TRUE filter
			if {$PARAMS(IOB_TRUE_FILTER) == 1 && [llength $input_registers] > 0} {
				set input_registers [filter $input_registers {IOB==TRUE}]
			}
			
			if {$debug >= 2} {puts "-D: Found [llength $input_registers] input registers"}
			
			if {[llength $input_registers] > 0} {
				# Run report timing for input paths (hold)
				set tps [get_timing_paths -quiet -delay_type min -from $input_ports -to $input_registers -max_paths [llength $input_registers] -unique_pins]
				
				if {$debug >= 2} {puts "-D: Analyzing [llength $tps] timing paths to input registers"}
				
				# Process each path
				foreach tp $tps req [get_property -quiet REQUIREMENT $tps] ep [get_property -quiet ENDPOINT_PIN $tps] {
					set reg [string range $ep 0 end-2]
					
					# Check if requirement meets threshold
					if {$req eq "inf" || $req eq ""} {
						lappend input_target_registers $reg
						if {$debug >= 3} {puts "-D: Input register $reg qualifies (requirement: $req)"}
					} elseif {$PARAMS(INPUT_MIN_REQUIREMENT) ne "inf" && $req <= $PARAMS(INPUT_MIN_REQUIREMENT)} {
						lappend input_target_registers $reg
						if {$debug >= 3} {puts "-D: Input register $reg qualifies (requirement: $req <= $PARAMS(INPUT_MIN_REQUIREMENT))"}
					}
				}
			}
		}
		
		if {$debug >= 1} {puts "-D: Input target registers: [llength $input_target_registers]"}
		
		# STEP 3: Combine target registers and filter for BLI compatibility
		set target_registers [concat $output_target_registers $input_target_registers]
		set target_registers [lsort -unique [get_cells $target_registers]]
		
		if {$debug >= 1} {puts "-D: Total unique target registers: [llength $target_registers]"}

        # Filter by INIT compatibility with BLI site semantics:
        #   FDRE/FDCE reset to 0 -> require INIT==1'b0
        #   FDSE/FDPE set/preset to 1 -> require INIT==1'b1
        # Drop any FF whose INIT contradicts its reset/preset polarity, and
        # drop any non-FDRE/FDSE/FDCE/FDPE primitives (latches, etc.).
        if {[llength $target_registers] > 0} {
            set before_count [llength $target_registers]
            set target_registers [filter $target_registers {((REF_NAME==FDRE || REF_NAME==FDCE) && INIT==1'b0)}]
            if {$debug >= 1} {
                puts "-D: After INIT/REF_NAME BLI compatibility filter: [llength $target_registers] registers (dropped [expr {$before_count - [llength $target_registers]}])"
            }
        }

		# STEP 4: Filter by calibrated clocks if enabled
		if {$PARAMS(ONLY_CALIBRATED_CLOCKS) == 1 && [llength $target_registers] > 0} {
			if {$debug >= 1} {puts "-D: Filtering for calibrated clocks"}
			
			# Find calibrated clock nets
			set cal_clock_nets [get_nets -quiet -hier -filter {GCLK_DESKEW==CALIBRATED&&TYPE==GLOBAL_CLOCK} -parent]
			
			if {[llength $cal_clock_nets] > 0} {
				if {$debug >= 2} {puts "-D: Found [llength $cal_clock_nets] calibrated clock nets"}
				
				# Create temporary property if it does not exist to mark calibrated cells
				if {[lsearch [list_property [lindex $target_registers 0]] RQS.CAL_CLOCK] == -1} {
					create_property -type bool RQS.CAL_CLOCK cell
				}
				set cal_cells [get_cells -quiet -of [get_pins -quiet -leaf -of $cal_clock_nets]]
				if {[llength $cal_cells] > 0} {
					set_property -quiet RQS.CAL_CLOCK 1 $cal_cells
				}
				# Filter target registers
				set target_registers [filter $target_registers {RQS.CAL_CLOCK==1}]
				
				if {$debug >= 1} {puts "-D: After calibrated clock filtering: [llength $target_registers] registers"}
			} else {
				if {$debug >= 1} {puts "-D: No calibrated clock nets found"}
				set target_registers [list]
			}
		}
		
		# Early exit if no target registers
		if {[llength $target_registers] == 0} {
			if {$debug >= 1} {puts "-D: No target registers found"}
			set stop [clock seconds]
			::tclapp::xilinx::customqorflows::compile_time $start $stop
			return
		}
		
		# STEP 5: Generate commands
		if {$debug >= 1} {puts "-D: Generating commands for [llength $target_registers] registers"}
		if {$debug >= 2} {puts "-D: Target registers: [lsort -dict $target_registers]"}
		
		# Check for DONT_TOUCH objects
		set dont_touch_objs [filter $target_registers {DONT_TOUCH == TRUE}]
		set require_dont_touch 0
		
		if {[llength $dont_touch_objs] > 0} {
			if {$debug >= 2} {puts "-D: Found [llength $dont_touch_objs] registers with DONT_TOUCH=TRUE"}
			set require_dont_touch 1
			set command [::tclapp::xilinx::customqorflows::pretty_command_property DONT_TOUCH 0 $dont_touch_objs]
			append command "\n"
		}
		
		# Generate IOB FALSE command
		set iob_cmd [::tclapp::xilinx::customqorflows::pretty_command_property IOB FALSE $target_registers]
		append command $iob_cmd
		append command "\n"
		
		# Generate BLI TRUE command
		set bli_cmd [::tclapp::xilinx::customqorflows::pretty_command_property BLI TRUE $target_registers]
		append command $bli_cmd
		
		# End of suggestion content
		# =========================

		set ret_dict [dict create]		
		if {$command ne ""} {
			dict set ret_dict COMMAND $command
			if {$require_dont_touch != 0} {
				dict set ret_dict DISABLE_DONT_TOUCH_REQUIRED 1
			}
			dict set ret_dict EST_RESOURCE_CHANGE.FF -[llength [filter $target_registers {IOB!=1}]]
			if {$debug >= 1} {puts "-D: Estimated resource change: EST_RESOURCE_CHANGE.FF - -[llength [filter $target_registers {IOB!=1}]]"}
		} else {
			if {$debug >= 1} {puts "-D: No commands generated"}
		}

		set stop [clock seconds]		
		::tclapp::xilinx::customqorflows::compile_time $start $stop
		if {[llength [dict keys $ret_dict]] == 0} {return}
		return $ret_dict
	}
	
	proc register_timing_move_iob_to_bli_checks {} {
		# The following sets up the suggestion in the Custom QoR Tools.
		# ==================================================
		set id RQS_AMD_TIMING-4
		set description "Move IOB registers to BLI to improve internal timing. Reduces clock skew between fabric and IOB registers, particularly beneficial when calibrated deskew is used."
		set auto 1
		set category Timing
		set applicable_for place_design
		set switches ""
		set needs_timing_data 0
		set params [dict create \
			ONLY_CALIBRATED_CLOCKS 0 \
			INPUT_MIN_REQUIREMENT inf \
			OUTPUT_MAX_REQUIREMENT inf \
			IOB_TRUE_FILTER 0 \
			FLAT_PIN_COUNT_CHECK 1 \
			FLAT_PIN_COUNT_VALUE 2 \
			DEBUG 0]

		catch "delete_qor_check ${id} -quiet"
		create_qor_check -name ${id} -rule_body ::tclapp::xilinx::customqorflows::timing_move_iob_to_bli \
			-property_values [list DESCRIPTION $description \
								   AUTO $auto \
								   CATEGORY $category \
								   APPLICABLE_FOR $applicable_for \
								   NEEDS_TIMING_DATA $needs_timing_data \
								   PARAMS $params]
	}
 
	register_timing_move_iob_to_bli_checks
}
