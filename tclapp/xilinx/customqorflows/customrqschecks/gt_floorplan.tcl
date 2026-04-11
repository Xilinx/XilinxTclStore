####################################################################################
#
# gt_floorplan.tcl (customqorflows GT floorplan suggestion)
#
# Script created on 03/30/2026 by Madhur Chhabra, AMD
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::customqorflows {
	#namespace export gt_floorplan
}

namespace eval ::tclapp::xilinx::customqorflows {

	proc gt_floorplan {args} {
		# Summary:
		# Analyze GT clock topology and hierarchy placement, then generate floorplanning guidance
		# either as Pblock Tcl commands or as synthesis KEEP_HIERARCHY property commands.

		# Argument Usage:
		# args: Optional list from Custom QoR Tools. The proc expects at most one positional entry.
		# [lindex $args 0] = qor_dict (dict): Parameter override dictionary consumed by
		#   ::tclapp::xilinx::customqorflows::update_params PARAMS $qor_dict.
		#   Supported override keys used by this proc:
		#   - SUGGESTION_MODE (Default: PBLOCKS): PBLOCKS or SYNTH_PROPERTY.
		#     PBLOCKS generates create_pblock/resize_pblock/add_cells_to_pblock commands.
		#     SYNTH_PROPERTY generates KEEP_HIERARCHY property commands.
		#   - SINGLE_CR_PRIM_CNT_THRESHOLD (Default: 2000): Floorplan decision threshold.
		#   - MULTI_CR_PRIM_CNT_THRESHOLD (Default: 10000): Floorplan decision threshold.
		#   - HALF_SLR_PRIM_CNT_THRESHOLD (Default: 20000): Floorplan decision threshold.
		#   - SLR0,Y,MIN .. SLR3,Y,MAX (Defaults: 1..13): Clock-region to SLR-side mapping.
		#   - MIN_NUM_SLRS (Default: 0): Early exit when device SLR count is smaller.
		#   - ONLY_UNPLACED_DESIGNS (Default: 1): Early exit when design is fully placed.
		#   - DEBUG (Default: 0): Enables debug prints and file dumps.
		#   - READ_DICT_INFO (Default: 0): Reuses cached dict files when set to 1/2/3.
		# Any additional args entries beyond index 0 are unexpected and only emit an error print.

		# Return Value:
		# Empty return (no value): When suggestion is not applicable or no command is generated.
		# dict with key COMMAND: [dict create COMMAND $command]
		#   COMMAND value is a Tcl command string for the selected SUGGESTION_MODE.

		# Categories: xilinxtclstore, customqorflows

		# New proc to generate GT info
		set start [clock seconds]

		# PARAMS
		set PARAMS(SUGGESTION_MODE) PBLOCKS
		#set PARAMS(SUGGESTION_MODE) SYNTH_PROPERTY
		set PARAMS(SINGLE_CR_PRIM_CNT_THRESHOLD) 2000
		set PARAMS(MULTI_CR_PRIM_CNT_THRESHOLD)  10000
		set PARAMS(HALF_SLR_PRIM_CNT_THRESHOLD)  20000
		set PARAMS(SLR0,Y,MIN)  1
		set PARAMS(SLR0,Y,MAX)  4
		set PARAMS(SLR1,Y,MIN)  5
		set PARAMS(SLR1,Y,MAX)  7
		set PARAMS(SLR2,Y,MIN)  8 
		set PARAMS(SLR2,Y,MAX)  10
		set PARAMS(SLR3,Y,MIN)  11
		set PARAMS(SLR3,Y,MAX)  13
		set PARAMS(MIN_NUM_SLRS)  0
		set PARAMS(ONLY_UNPLACED_DESIGNS)  1
		set PARAMS(DEBUG) 0
		set PARAMS(READ_DICT_INFO) 0
		
		# Custom QoR Tools will provide a dictionary to args. Users can reference this using the qor_dict variable.
		# The format might change over time but should do so by introducing new keys to not break older scripts.
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
		# The dictionary generation takes some time. When debugging, set this to 1 so that it can be sped up. Before it can be set to 1, the dictionary files must be written from a previous run.
		# This happens in the first run when it is run with it set to 0.
		set read_dict_info $PARAMS(READ_DICT_INFO)

		if {$debug == 1} {set ct_fid [open compile_time.txt a] ; puts "-D Compile time file: compile_time.txt"}
		
		set clock_net_dict [dict create]
		set hier_cell_dict [dict create]
		set analysis_dict [dict create]
		array set GCLK_ARR ""
		set c 0
			
		# STEP 0: EARLY EXIT
		# ==================
		# A) Suggestion only supports Versal but does not support XCVP1902
		set part [lindex [split [get_property -quiet PART [current_design]] -] 0]
		if {$part eq "xcvp1902"} {
			if {$debug == 1} {puts "-D: Part $part is not supported for this suggestion"}
			return
		}
		# B) Suggestion only supports unplaced designs
		if {$PARAMS(ONLY_UNPLACED_DESIGNS) == 1} {
			if {[report_route_status -quiet -boolean_check PLACED_FULLY] == 1} {
				if {$debug == 1} {puts "-D: Suggestion can not be generated on a placed design. This is disabled to prevent duplicates and save runtime"}
				return
			}
		}
		# C) Exit if number of SLRs < $PARAMS(MIN_NUM_SLRS)
		if {[llength [get_slrs -quiet]] < $PARAMS(MIN_NUM_SLRS)} {
			if {$debug == 1} {puts "-D: Part has not met the tuning parameter for minimum number of SLRs"}
			return
		}
		# D) Exit if the suggestion already exists
		if {$PARAMS(SUGGESTION_MODE) eq "PBLOCKS" && [llength [get_qor_suggestions -quiet RQS_NETLIST-11*]] > 0} {
			if {$debug == 1} {puts "-D: Suggestion is already generated. Delete the suggestion before rerunning."}
			return
		} elseif {$PARAMS(SUGGESTION_MODE) eq "SYNTH_PROPERTY" && [llength [get_qor_suggestions -quiet RQS_NETLIST-12*]] > 0} {
			if {$debug == 1} {puts "-D: Suggestion is already generated. Delete the suggestion before rerunning."}
			return
		}
		# E) Exit if the pblocks already exists
		if {$PARAMS(SUGGESTION_MODE) eq "PBLOCKS" && ([llength [get_pblocks -quiet pb_single_cr*]] > 0 || [llength [get_pblocks -quiet pb_slr_side*]] > 0 ||[llength [get_pblocks -quiet pb_row_cr_*]] > 0)} {
			if {$debug == 1} {puts "-D: Suggestion is potentially generated as Tcl already. Delete pblocks before rerunning."}
			return
		} 
		
		# STEP 1: DATA GATHER
		# A) First gather all the hierarchies we want to generate data for.
		# These are related to the RXOUTCLKs and TXOUTCLKs from the GTs
		set gt_quad_cells ""; # DEBUG using this. Set a smaller number of GTs to speed things up
		if {$gt_quad_cells eq ""} {set gt_quad_cells [get_cells -quiet -hier -filter {REF_NAME=~GT*_QUAD && LOC != ""}]} else {set gt_quad_cells [get_cells -quiet $gt_quad_cells -filter {LOC != ""}]}
		if {[llength $gt_quad_cells] == 0} {
			set stop [clock seconds]; 
			return
		}

		set num_gclks_start [clock seconds]
		::tclapp::xilinx::customqorflows::generate_gclk_hier_details GCLK_ARR
		 if {$debug == 1} {
			::tclapp::xilinx::customqorflows::write_array_to_file GCLK_ARR gclkarray.txt
			set num_gclks_stop [clock seconds]
					::tclapp::xilinx::customqorflows::compile_time $num_gclks_start $num_gclks_stop  "" _NUM_GCLKS $ct_fid
		}

		set outclk_pins [get_pins -quiet -of $gt_quad_cells -filter {NAME =~ "*XOUTCLK*"}]
		set bufg_gts [get_cells -quiet -of [get_pins -quiet -leaf -filter {REF_PIN_NAME==I&&REF_NAME=~*BUFG_GT*} -of [get_nets -quiet -of $outclk_pins]]]
		set parent_bufg_gt_nets [get_nets -quiet -of [get_pins -filter {DIRECTION==OUT} -of $bufg_gts]] 
		set bufg_gt_load_pins [get_pins -quiet -leaf -of $parent_bufg_gt_nets]
		set all_bufg_gt_parent_cells [get_cells -quiet [get_property -quiet PARENT_CELL [get_nets -quiet -segments $parent_bufg_gt_nets -filter {PARENT_CELL!=""}]]]
		set hier_cells_single_gclk [filter -quiet $all_bufg_gt_parent_cells {NUM_GCLKS==1}]
		set hier_cells_for_analysis [get_cells -quiet [get_property -quiet PARENT_CELL [get_nets -quiet -segments $parent_bufg_gt_nets -filter {PARENT_CELL!=""}]] -filter {PRIMITIVE_LEVEL!=MACRO&&NUM_GCLKS>1}]

		# Generate the hierarchical cell dictionary.
		if {$read_dict_info == 1 && [file exists hier_cell_dict.txt]} {
			set hier_cell_dict [::tclapp::xilinx::customqorflows::read_dict_from_file hier_cell_dict.txt]
		} else {   
			set hier_cell_start [clock seconds]
			# Debug speedup - Limit gt_quad_cells Single element to only process single GT while under development
			if {$debug == 2} {puts "-D: Overriding GT. Only running  with single GT."; set gt_quad_cells [lindex $gt_quad_cells end]}

			# Gathering multicell data
					::tclapp::xilinx::customqorflows::get_multi_hier_cell_data hier_cell_dict $hier_cells_for_analysis mode1
			if {$debug == 1} {
				::tclapp::xilinx::customqorflows::write_dict_to_file $hier_cell_dict hier_cell_dict.txt
				set hier_cell_stop [clock seconds]
						::tclapp::xilinx::customqorflows::compile_time $hier_cell_start $hier_cell_stop  "" _HIER_CELL  $ct_fid
			}
		}


		# Generate the hierarchical cell dictionary.
		set analysis_start [clock seconds]
		if {$read_dict_info == 2 && [file exists analysis_dict.txt]} {
			set analysis_dict  [::tclapp::xilinx::customqorflows::read_dict_from_file analysis_dict.txt]
		} else {
			# Currently have collected hierarchical data and clock data but not connected them together
			# Associate GTs wtih OUTCLKS and all parent cells
			foreach gt_quad_cell $gt_quad_cells {        
				set gt_quad_outclk_pins [get_pins -quiet -of $gt_quad_cell -filter {NAME =~ "*XOUTCLK*"}]
				set gt_quad_bufg_gts [get_cells -quiet -of [get_pins -leaf -quiet -filter {REF_PIN_NAME==I&&REF_NAME=~*BUFG_GT*} -of [get_nets -quiet -of $gt_quad_outclk_pins]]]
				set gt_quad_outclk_nets [get_nets -quiet -of [get_pins -quiet -filter {DIRECTION==OUT} -of $gt_quad_bufg_gts]]
				if {$debug == 1} {puts "-D: gt_quad_cell  is $gt_quad_cell"}
						set gt_hierarchies [::tclapp::xilinx::customqorflows::get_floorplan_hierarchy_by_celltype $gt_quad_cell]
				dict set analysis_dict $gt_quad_cell gt_single_cr [lindex $gt_hierarchies 0]
				dict set analysis_dict $gt_quad_cell gt_single_hier [lindex $gt_hierarchies 1]
				dict set analysis_dict $gt_quad_cell gt_multi_hier [lindex $gt_hierarchies 3]
				dict set analysis_dict $gt_quad_cell outclk_nets $gt_quad_outclk_nets
				dict set analysis_dict $gt_quad_cell all_parent_cells [get_property -quiet PARENT_CELL [get_nets -quiet -segments $gt_quad_outclk_nets]]
			}    
			 if {$debug == 1} {
				::tclapp::xilinx::customqorflows::write_dict_to_file $analysis_dict analysis_dict.txt
				set analysis_stop [clock seconds]
						::tclapp::xilinx::customqorflows::compile_time $analysis_start $analysis_stop  "" _ANALYSIS_DICT  $ct_fid
			 } 
		}


		# B) Now generate clock net data
		# First Generate basic clock data for all clocks
		if {$read_dict_info == 3 &&[file exists clock_net_dict.txt]} {
			set clock_net_dict [::tclapp::xilinx::customqorflows::read_dict_from_file clock_net_dict.txt]
		} else { 
			# First generate multi clock net data. This should be quick
			set multi_clock_net_start [clock seconds]
					set clock_net_dict [::tclapp::xilinx::customqorflows::get_multi_clock_net_data "" mode1]
			if {$debug == 1} {
				set multi_clock_net_stop [clock seconds]
						::tclapp::xilinx::customqorflows::compile_time $multi_clock_net_start $multi_clock_net_stop  "" _MULTI_CLOCK_COMPILE_TIME $ct_fid
			}
			# Next generate single clock net data. This is propotional to the number of clocks
			set single_clock_net_start [clock seconds]
			foreach net $parent_bufg_gt_nets {
				# Generate data for the clock net and merge with existing data
				if {$debug == 1} {puts "-D: single clock_net data: $net"}
						set new_data [::tclapp::xilinx::customqorflows::get_single_clock_net_data $net mode1]
				if {[dict exists $clock_net_dict $net]} {
					# Merge new data with existing data for this net
					dict set clock_net_dict $net [dict merge [dict get $clock_net_dict $net] $new_data]
				} else {
					# First time seeing this net, just set it
					dict set clock_net_dict $net $new_data
				}
			}
			if {$debug} {
				::tclapp::xilinx::customqorflows::write_dict_to_file $clock_net_dict clock_net_dict.txt
				set single_clock_net_stop [clock seconds]
						::tclapp::xilinx::customqorflows::compile_time $single_clock_net_start $single_clock_net_stop  "" _SINGLE_CLOCK_DICT $ct_fid
			} 
		}

		# Determine the best floorlan for the GT clocks + Print GT clock table
		set fp_start [clock seconds]
		set tbl [xilinx::designutils::prettyTable ]
		$tbl title "GT OUTCLK INFORMATION"
		$tbl header "GT GT_CR LOAD_CR LOAD_SLR FLAT_PIN_COUNT FP_SINGLE_CR 3_CR_ROW SLR_SIDE OUTCLKS"
		set val_list [list LOADS_ADVANCED_LOCS_CR LOADS_ADVANCED_LOCS_SLR FLAT_PIN_COUNT]
		foreach gt_quad_cell $gt_quad_cells {        
			set k 0
			set row $gt_quad_cell
			set alt_row [list "" ""]
			set gt_dict [dict get $analysis_dict $gt_quad_cell]
			lappend row [dict get $gt_dict gt_single_cr]
			set outclk_pins [get_pins -quiet -of $gt_quad_cell -filter {NAME =~ "*XOUTCLK*"}]
			set bufg_gts [get_cells -quiet -of [get_pins -quiet -leaf -filter {REF_PIN_NAME==I&&REF_NAME=~*BUFG_GT*} -of [get_nets -quiet -of $outclk_pins]]]
			set outclk_nets [get_nets -quiet -of [get_pins -quiet -filter {DIRECTION==OUT} -of $bufg_gts]]
			if {[llength $outclk_nets] > 0} {
				foreach gclk $outclk_nets {            
					set gclk_dict [dict get $clock_net_dict $gclk]
					if {$k == 0} {set print_row $row} else {set print_row $alt_row}
					foreach val $val_list {
						if {[dict exists $gclk_dict $val]} {
							lappend print_row [dict get $gclk_dict $val]
						} else {
							lappend print_row ""
						}
					}
					# The following captures which floorplan types should work with this clock
					# These are carefully ordered so that the final one wins
					for {set m 1} {$m <=3} {incr m} {
										if {[set rt [::tclapp::xilinx::customqorflows::get_floorplan $gt_dict $gclk_dict PARAMS $m]] eq ""} {
							lappend print_row 0
						} else {
							lappend print_row 1
							dict set clock_net_dict $gclk FLOORPLAN_${m} $rt
						}
					}
					lappend print_row $gclk
					$tbl addrow $print_row
					incr k
				}
			} else {
				# Some GT QUADs do not have connected OUTCLKs
				set print_row $row
				foreach val $val_list {
					lappend print_row ""
				}
				for {set m 1} {$m <=3} {incr m} {
					lappend print_row ""
				}
				$tbl addrow $print_row
			}
		}
		set fid stdout; # debug for now
		puts $fid "[$tbl print]\n\n"
		$tbl destroy
		if {$debug} {
			set fp_stop [clock seconds]
					::tclapp::xilinx::customqorflows::compile_time $fp_start $fp_stop  "" _FP_DATA $ct_fid
		}

		# Now generate the list of hierarchies to go into the pblocks
		set hier_list_start [clock seconds]
		if {$debug == 1} {puts "-D: Printing floorplan table and generating pblock"}
		# First we generate info that allows us to speed up processing.
		# Assign FLOORPLANABLE($hier) == [list IN_PBLOCK REASON] to allow addition to pblock
		foreach hier $hier_cells_single_gclk {
			set FLOORPLANABLE($hier) [list 1 "Single clock net"]
		}
		foreach cell_type [list DCMAC MRMAC ILKNF GT*QUAD] {
			set cells [get_cells -quiet -of [filter -quiet $bufg_gt_load_pins "REF_NAME=~$cell_type"]]
			if {$debug == 1} {puts "-D: cell_type - $cell_type : Found [llength $cells] cells"}
			foreach cell $cells {
						set hiers [::tclapp::xilinx::customqorflows::get_floorplan_hierarchy_by_celltype $cell]
				if {[lindex $hiers 3] eq ""} {set highest_single_hier [get_property -quiet PARENT $cell]} else {set highest_single_hier [lindex $hiers 1]}
				set FLOORPLANABLE($highest_single_hier) [list 1 "single hard ip hierarchy"]
						::tclapp::xilinx::customqorflows::flag_hierarchies_below $highest_single_hier FLOORPLANABLE 0 [list 0 "hierarchy below single hard IP" $cell] ""
						::tclapp::xilinx::customqorflows::flag_hierarchies_above $highest_single_hier FLOORPLANABLE 0 [list 0 "hierarchy above single hard IP" $cell] ""      
			}
		}

		# Now we process all segments from all BUFG_GT clocks. By not processing by net it saves duplication and speeds this up
		set t 0
		set all_num_gclks [get_property -quiet NUM_GCLKS $all_bufg_gt_parent_cells]
		foreach hier $all_bufg_gt_parent_cells {
			if {[info exists FLOORPLANABLE($hier)]} {incr t; continue}
			set num_gclk [lindex $all_num_gclks $t]
			set clk_cnt $num_gclk
			set pre_drv_cell_list ""
			foreach gclk $GCLK_ARR($hier) {
				if {[dict exists $clock_net_dict $gclk HIGHEST_NONGT_CLOCK_LOADS]} {
					if {[dict get $clock_net_dict $gclk HIGHEST_NONGT_CLOCK_LOADS] <= 2} {incr clk_cnt -1}
					continue
				}
				# Other clocks from the same GT are acceptable
				if {[dict exists $clock_net_dict $gclk PRE_DRIVING_CELL_REF_NAME]} {
					if {[string range [dict get $clock_net_dict $gclk PRE_DRIVING_CELL_REF_NAME] 0 1 ] eq "GT"} {
						lappend pre_drv_cell_list [dict get $clock_net_dict $gclk PRE_DRIVING_CELL]
						incr clk_cnt -1; continue
					}
				} else {
					if {$debug == 1} {puts "-D: clock $gclk does not have PRE_DRIVING_CELL info"}
				}
			}
			if {[set src_gts [llength [lsort -unique $pre_drv_cell_list]]] <= 1 && $clk_cnt == 0} {
				set FLOORPLANABLE($hier) [list 1 "Clock check passed"]
			} else {
				set FLOORPLANABLE($hier) [list 0 "Clock check failed - num gclks - $num_gclk non-discounted clocks - $clk_cnt num_gts - $src_gts"]
			}
			incr t
		}
		if {$debug} {
			set hier_list_stop [clock seconds]
					::tclapp::xilinx::customqorflows::compile_time $hier_list_start $hier_list_stop  "" __GEN_FLOORPLANNABLE $ct_fid
		}

		# Next tidy up the pblocks by only including top level pblocks that need to be in the constriant.
		# i.e., remove all lower level hierarchies that are already included because above hierarchies
		# will be in the constraint
		# THIS IS A COMPILE TIME PINCH POINT. IF WE CAN REDUCE THE TIMES PROCESSED BY FINDING TOP MODULES FIRST, IT WILL LOWER COMPILE TIME
		set hier_list_start2 [clock seconds]
		set z 0
		foreach hier $all_bufg_gt_parent_cells {
			if {[info exists FLOORPLANABLE($hier)]} {
				if {[lindex $FLOORPLANABLE($hier) 0] == 1} {
									::tclapp::xilinx::customqorflows::flag_hierarchies_below $hier FLOORPLANABLE 0 [list 0 "hierarchy below floorplan hierarchy"]
					incr z
				}
			}
		}
		if {$debug == 1} {
			puts "-D: tidied up $z hierarchies"
			set hier_list_stop [clock seconds]
					::tclapp::xilinx::customqorflows::compile_time $hier_list_start2 $hier_list_stop  "" __HIERARCHY_TIDY_UP $ct_fid
			::tclapp::xilinx::customqorflows::write_array_to_file FLOORPLANABLE floorplannable_array.txt
		}

		# Next form the hierarchy information on a per net basis
		set j 0
		foreach net $parent_bufg_gt_nets {
			set segments [get_cells -quiet [lsort -unique [get_property PARENT_CELL [get_nets -segments $net]]] -filter {PRIMITIVE_LEVEL!=MACRO}]
			set PER_CLK_CLOCK_TABLE($j,GCLK) $net
			
			foreach segment $segments {    
				if {[info exists FLOORPLANABLE($segment)]} {
					lappend PER_CLK_CLOCK_TABLE($j,HIERARCHIES) $segment
					set PER_CLK_CLOCK_TABLE($j,$segment,IN_PBLOCK) [lindex $FLOORPLANABLE($segment) 0]
					set PER_CLK_CLOCK_TABLE($j,$segment,REASON) [lindex $FLOORPLANABLE($segment) 1]
					continue
				}
			}
			incr j
		}
		if {$debug == 1} {
			::tclapp::xilinx::customqorflows::write_array_to_file PER_CLK_CLOCK_TABLE per_clk_table_array.txt
		}

		# Generate user debug commands to more easily analyze the clocks
		if {$debug == 1} {puts "-D: Generating user debug commands"}
		 for {set i 0} {$i < $j} {incr i} {
			set net $PER_CLK_CLOCK_TABLE($i,GCLK)
			set fp_cells ""
			set no_fp_cells ""
			foreach hier $PER_CLK_CLOCK_TABLE($i,HIERARCHIES) {
				if {$PER_CLK_CLOCK_TABLE($i,$hier,IN_PBLOCK) == 1} {
					lappend fp_cells "${hier}"
				}
			}
			set CMD($i) "set net \{$net\};\n show_objects \[get_cells \[get_property PARENT_CELL \[get_nets -segments \$net\]\]\];\n show_schematic \[get_nets -segments \$net\];\n highlight_objects -color_index 11 \[get_cells \[list $fp_cells \]\];\n select_objects \[get_nets -segments \$net\] "
		}  


		if {$debug} {
			# Finally print the information foreach clock
			puts "-D: Printing tables showing hierarchy decisions"
			for {set i 0} {$i < $j} {incr i} {
				set tbl [xilinx::designutils::prettyTable ]
				set net $PER_CLK_CLOCK_TABLE($i,GCLK)
				$tbl title "Floorplan Info for $net"
				$tbl header "{In Pblock} Reason Hierarchy"
				foreach hier $PER_CLK_CLOCK_TABLE($i,HIERARCHIES) {
					set row ""
					foreach val [list IN_PBLOCK REASON] {
						lappend row $PER_CLK_CLOCK_TABLE($i,$hier,$val)
					}
					lappend row $hier
					$tbl addrow $row
				}
				puts $fid "[$tbl print]"
				puts $fid "* Debug:\n $CMD($i)\n\n\n"
				$tbl destroy
			}
			::tclapp::xilinx::customqorflows::write_array_to_file PER_CLK_CLOCK_TABLE per_clock_table_array.txt     
			set hier_list_stop [clock seconds]
					::tclapp::xilinx::customqorflows::compile_time $hier_list_start $hier_list_stop  "" _HIER_LIST_DATA $ct_fid
		}  

		# Generate the floorplan constraints
		# #1 Take all the clocks from the FLOORPLAN_INFO array
		# #2 Generate the clock dictionary
		# #3 Get the floorplan keys and information in the dictionary associated with each floorplan. In this we expect the lowest index key to be the best floorplan for that net.
		#    When we create pblocks, these could get pulled into larger pblocks if no cells are left.
		set get_pblock_start [clock seconds]
		set PB(NAMES,1) ""
		set PB(NAMES,2) ""
		set PB(NAMES,3) ""
		for {set i 0} {$i < $j} {incr i} {
			set net $PER_CLK_CLOCK_TABLE($i,GCLK)
			set net_dict [dict get $clock_net_dict $net]
			set keys [lsort -dict [dict keys $net_dict FLOORPLAN_*]] ; 
			if {$debug == 1} {puts "-D: Keys are $keys for net $net"}
			set key [lindex $keys 0]
			if {[llength $key] == 0} {
				if {$debug == 1} {puts "-D: No floorplan for net $net"}
				continue
			}
			set range [dict get $net_dict $key]
			if {[regexp {CLOCKREGION_(X(\d+)Y(\d+)):CLOCKREGION_(X(\d+)Y(\d+))} $range match src_cr src_x src_y dest_cr dest_x dest_y] == 0} {
				if {$debug == 1} {
					puts "-D: Regexp not matched for clock regions in pblock range $val"
				} 
				continue
			}
			set var [string index $key end]
			if {$var == 1} {
				lappend PB(NAMES,$var) [set name pb_single_cr_${src_cr}]
			} elseif {$var == 2} {
				 lappend PB(NAMES,$var)  [set name pb_row_cr_${src_cr}_${dest_cr}]
			} elseif {$var == 3} {
				 lappend PB(NAMES,$var) [set name pb_slr_side_${src_cr}_${dest_cr}]
			}
			lappend PB(NAMES) $name
			set PB($name,RANGE) $range
			lappend PB($name,COMMENT) "Pblock for net $net"
			set PB($name,CELLS_TO_ADD) ""
			foreach hier $PER_CLK_CLOCK_TABLE($i,HIERARCHIES) {
				if {$PER_CLK_CLOCK_TABLE($i,$hier,IN_PBLOCK) == 1} {lappend PB($name,CELLS_TO_ADD) $hier}
			}
		}
		set command ""
		if {$PARAMS(SUGGESTION_MODE) eq "PBLOCKS"} {
			if {$debug} {puts "-D: Creating pblock constraints ..."}
			for {set i 1} {$i<=3} {incr i} {
				foreach name [lsort -unique $PB(NAMES,$i)] {
					if {[llength $PB($name,CELLS_TO_ADD)] == 0} {continue}
					foreach comment $PB($name,COMMENT) {
						set command "${command}\n# ${comment}\n"
					}
					set command "${command}create_pblock ${name}\n"
					set command "${command}resize_pblock -add $PB($name,RANGE) ${name}\n"
					set cell_list ""
					for {set j 0} {$j < [llength $PB($name,CELLS_TO_ADD)]} {incr j} {
						lappend cell_list [lindex $PB($name,CELLS_TO_ADD) $j]
					}
									set fmt_cell_list [::tclapp::xilinx::customqorflows::pretty_partial_command $cell_list]
					set command "${command}add_cells_to_pblock $name \[get_cells ${fmt_cell_list} \]\n"
				}
			}
		} elseif {$PARAMS(SUGGESTION_MODE) eq "SYNTH_PROPERTY"} {
			if {$debug} {puts "-D: Creating Synthesis constraints..."}
			for {set i 1} {$i<=3} {incr i} {
				foreach name [lsort -unique $PB(NAMES,$i)] {
					if {[llength $PB($name,CELLS_TO_ADD)] == 0} {continue}
					set comments ""
					foreach comment $PB($name,COMMENT) {
						set comments "${comments}# ${comment}\n"
					}
					set obj_list ""
					for {set j 0} {$j < [llength $PB($name,CELLS_TO_ADD)]} {incr j} {
						lappend obj_list [lindex $PB($name,CELLS_TO_ADD) $j]
					}
									set tmp_command [::tclapp::xilinx::customqorflows::pretty_command_property KEEP_HIERARCHY TRUE $obj_list cell 0]
					set command "${command}\n${comments}${tmp_command}\n"
				}
			}
		}

		if {$debug == 1} {
			puts "-D: Suggestion Mode: $PARAMS(SUGGESTION_MODE)"
			set gen_pblock_stop [clock seconds]
					::tclapp::xilinx::customqorflows::compile_time $get_pblock_start $gen_pblock_stop  "" _GENERATE_PBLOCKS $ct_fid
		}

		if {$debug ==1} {
			close $ct_fid
			set cmd_fid [open debug_command.tcl w]
			puts $cmd_fid $command
			close $cmd_fid
		}


		set stop [clock seconds]; 
			::tclapp::xilinx::customqorflows::compile_time $start $stop  "" GT_FLOORPLAN_V5
		if {$command eq ""} {
			return
		}  else {
			return [dict create COMMAND $command]
		}
	}
	
	# The following sets up the suggestion in the Custom QoR Tools.
	# ==================================================
	 set id RQS_AMD_NETLIST-11
	 set description "Create floorplan based on GT clocks and hard block locations"
	 set auto 1
	 set category netlist
	 set applicable_for place_design
	 set switches ""
	 set needs_timing_data 0
	 set params [list SUGGESTION_MODE pblocks]
	 
	 catch "delete_qor_check ${id} -quiet"
	 create_qor_check -name ${id} -rule_body ::tclapp::xilinx::customqorflows::gt_floorplan \
		-property_values [list DESCRIPTION $description \
							   AUTO $auto \
							   CATEGORY $category \
							   APPLICABLE_FOR $applicable_for\
							   NEEDS_TIMING_DATA $needs_timing_data \
							   PARAMS $params \
							   ]
							   
	 set id RQS_AMD_NETLIST-12
	 set description "Create hierarchy to enabled better floorplanning based on GT clocks and hard block locations"
	 set auto 1
	 set category netlist
	 set applicable_for synth_design
	 set switches ""
	 set needs_timing_data 0
	 set params [list SUGGESTION_MODE synth_property] 
	 
	 catch "delete_qor_check ${id} -quiet"
	 create_qor_check -name ${id} -rule_body ::tclapp::xilinx::customqorflows::gt_floorplan \
		-property_values [list DESCRIPTION $description \
							   AUTO $auto \
							   CATEGORY $category \
							   APPLICABLE_FOR $applicable_for\
							   NEEDS_TIMING_DATA $needs_timing_data \
							   PARAMS $params \
							   ]
	
}


