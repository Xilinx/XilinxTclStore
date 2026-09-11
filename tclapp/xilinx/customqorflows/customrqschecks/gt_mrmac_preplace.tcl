####################################################################################
#
# gt_mrmac_preplace.tcl (customqorflows GT-MRMAC/DCMAC pre-place suggestion)
#
# Script created on 03/30/2026 by Madhur Chhabra, AMD
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::customqorflows {
	#namespace export gt_mrmac_preplace
}

namespace eval ::tclapp::xilinx::customqorflows {

    # --- Helper: data pins of cells (exclude clock pins) ---
    proc _gtmr_datapins {cells dir} {
        if {[llength $cells] == 0} { return {} }
        if {$dir eq "fanin"} {
            set pins [get_pins -quiet -of [get_cells -quiet $cells] -filter {DIRECTION == IN}]
        } else {
            set pins [get_pins -quiet -of [get_cells -quiet $cells] -filter {DIRECTION == OUT}]
        }
        if {[llength $pins] == 0} { return {} }
        set flags [get_property -quiet IS_CLOCK $pins]
        set out {}
        foreach p $pins f $flags { if {$f ne "1"} { lappend out $p } }
        return $out
    }

    # --- Helper: one timing-stage hop (batched) ---
    proc _gtmr_hop {pins dir} {
        if {[llength $pins] == 0} { return {} }
        if {$dir eq "fanin"} {
            return [all_fanin  -startpoints_only -flat -only_cells $pins]
        }
        return [all_fanout -endpoints_only -flat -only_cells $pins]
    }

    # --- Helper: BFS search from MRMAC to find connected GT ---
    # Returns {depth gt_cell} or {} if no GT within cap stages.
    proc _gtmr_search {start dir cap} {
        variable _gtmr_isgt
        variable _gtmr_ismr
        variable _gtmr_gt_pat
        variable _gtmr_mrmac_pat
        variable _gtmr_dcmac_pat

        array set seen {}
        set seen($start) 1
        set sinkpins [_gtmr_datapins [list $start] $dir]
        for {set stage 1} {$stage <= [expr {$cap + 1}]} {incr stage} {
            if {[llength $sinkpins] == 0} { break }
            set sps [_gtmr_hop $sinkpins $dir]
            if {[llength $sps] == 0} { break }
            set refs [get_property -quiet REF_NAME $sps]

            # GT reached?
            foreach c $sps r $refs {
                if {[info exists _gtmr_isgt($c)] || [string match $_gtmr_gt_pat $r]} {
                    return [list [expr {$stage - 1}] $c]
                }
            }
            # Collect new register frontier (stop at other MRMAC/DCMAC)
            set newregs {}
            foreach c $sps r $refs {
                if {[string match $_gtmr_mrmac_pat $r] || [string match $_gtmr_dcmac_pat $r] || [info exists _gtmr_ismr($c)]} { continue }
                if {![info exists seen($c)]} { set seen($c) 1; lappend newregs $c }
            }
            if {[llength $newregs] == 0} { break }
            set sinkpins [_gtmr_datapins $newregs $dir]
        }
        return {}
    }

    # --- Helper: SLR name of a cell (GT always has LOC) ---
    proc _gtmr_get_slr {cell} {
        set s [get_slrs -quiet -of_objects [get_cells -quiet $cell]]
        if {[llength $s] == 0} { return "" }
        return [get_property -quiet NAME $s]
    }

    # --- Helper: clock region name of a placed cell's site ---
    proc _gtmr_cr_of_cell {cell} {
        set st [get_sites -quiet -of_objects [get_cells -quiet $cell]]
        if {[llength $st] == 0} { return "" }
        set cr [get_clock_regions -quiet -of_objects $st]
        if {[llength $cr] == 0} { return "" }
        return [get_property -quiet NAME $cr]
    }

    # --- Helper: clock region XY ---
    proc _gtmr_cr_xy {cr} {
        if {[regexp {X(\d+)Y(\d+)} $cr -> x y]} { return [list $x $y] }
        return {}
    }

    # --- Main rule proc ---
    proc gt_mrmac_preplace {args} {
        variable _gtmr_isgt
        variable _gtmr_ismr
        variable _gtmr_gt_pat
        variable _gtmr_mrmac_pat
        variable _gtmr_dcmac_pat

        set start [clock seconds]

        # PARAMS (overridable via the check's PARAMS property)
        set PARAMS(MAX_LEVELS) 3
        set PARAMS(GT_PAT)     {GT*}
        set PARAMS(MRMAC_PAT)  {MRMAC*}
        set PARAMS(DCMAC_PAT)  {DCMAC*}
        set PARAMS(DEBUG)      0

        # Custom QoR tools pass a dictionary (TIMING_PATHS / UTILIZATION / PARAMS).
        set qor_dict ""
        if {$args ne ""} {
            for {set i 0} {$i < [llength $args]} {incr i} {
                if {$i == 0} { set qor_dict [lindex $args $i] } else { puts "-E: Not expecting this arg from QoR tools" }
            }
        }
        ::tclapp::xilinx::customqorflows::update_params PARAMS $qor_dict

        set _gtmr_gt_pat    $PARAMS(GT_PAT)
        set _gtmr_mrmac_pat $PARAMS(MRMAC_PAT)
        set _gtmr_dcmac_pat $PARAMS(DCMAC_PAT)
        set max_levels      $PARAMS(MAX_LEVELS)
        set dbg             $PARAMS(DEBUG)

        # --- Find GT and MRMAC/DCMAC cells ---
        set gt_cells    [get_cells -hier -quiet -filter "REF_NAME =~ $_gtmr_gt_pat"]
        set mrmac_cells [get_cells -hier -quiet -filter "REF_NAME =~ $_gtmr_mrmac_pat || REF_NAME =~ $_gtmr_dcmac_pat"]

        if {[llength $gt_cells] == 0 || [llength $mrmac_cells] == 0} {
            return
        }

        # --- Build lookup sets ---
        array unset _gtmr_isgt; array set _gtmr_isgt {}
        array unset _gtmr_ismr; array set _gtmr_ismr {}
        foreach c $gt_cells    { set _gtmr_isgt([get_property NAME $c]) 1 }
        foreach c $mrmac_cells { set _gtmr_ismr([get_property NAME $c]) 1 }

        set deep_cap [expr {$max_levels + 3}]
        array set processed {}
        array set assigned_sites {}
        set cmd_lines [list]

        foreach mr $mrmac_cells {
            set mr_name [get_property NAME $mr]
            if {[info exists processed($mr_name)]} { continue }

            # Already LOC'd / fixed -> no need to constrain.
            set mr_loc   [get_property -quiet LOC $mr]
            set mr_fixed [get_property -quiet IS_LOC_FIXED $mr]
            if {$mr_loc ne "" || $mr_fixed eq "1"} {
                set processed($mr_name) 1
                # Under debug, surface the un-fixable case: a locked MRMAC/DCMAC sitting
                # in a different SLR than its (also locked) connected GT -- the exact
                # SLR-crossing this check exists to prevent, but both ends are pinned.
                if {$dbg} {
                    set mr_ref [get_property -quiet REF_NAME $mr]
                    set mr_slr [_gtmr_get_slr $mr_name]
                    set mr_cr  [_gtmr_cr_of_cell $mr_name]
                    foreach dir {fanin fanout} {
                        set res [_gtmr_search $mr_name $dir $deep_cap]
                        if {[llength $res] == 0} { continue }
                        set depth [lindex $res 0]
                        set gtc   [lindex $res 1]
                        if {$depth > $max_levels} { continue }
                        set gt_loc    [get_property -quiet LOC [get_cells -quiet $gtc]]
                        set gt_locked [expr {$gt_loc ne ""}]
                        set gt_slr    [_gtmr_get_slr $gtc]
                        set gt_cr     [_gtmr_cr_of_cell $gtc]
                        if {$mr_slr ne "" && $gt_slr ne "" && $mr_slr ne $gt_slr} {
                            if {$gt_locked} {
                                puts "-I(GT_MRMAC_PREPLACE/DEBUG): LOCKED cross-SLR (cannot auto-fix, both pinned): $mr_ref '$mr_name' LOC $mr_loc @ $mr_slr/$mr_cr (fixed=$mr_fixed) <-> GT '$gtc' LOC $gt_loc @ $gt_slr/$gt_cr (locked=1), stage-distance $depth"
                            } else {
                                puts "-I(GT_MRMAC_PREPLACE/DEBUG): cross-SLR, GT movable: $mr_ref '$mr_name' LOC $mr_loc @ $mr_slr/$mr_cr (fixed=$mr_fixed) <-> UNLOCKED GT '$gtc' @ $gt_slr, stage-distance $depth -- consider LOC'ing GT into $mr_slr"
                            }
                        } elseif {$mr_slr ne "" && $gt_slr ne ""} {
                            puts "-I(GT_MRMAC_PREPLACE/DEBUG): locked $mr_ref '$mr_name' (@ $mr_cr) and GT '$gtc' (@ $gt_cr) co-located in $gt_slr (OK), stage-distance $depth"
                        }
                        break
                    }
                }
                continue
            }

            # Search for connected GT in both directions (within max_levels).
            set gt_found ""
            set gt_depth -1
            foreach dir {fanin fanout} {
                set res [_gtmr_search $mr_name $dir $deep_cap]
                if {[llength $res] > 0} {
                    set depth [lindex $res 0]
                    set gtc   [lindex $res 1]
                    if {$depth <= $max_levels} {
                        set gt_found $gtc
                        set gt_depth $depth
                        break
                    }
                }
            }
            if {$gt_found eq ""} { continue }

            # GT's SLR.
            set gt_slr [_gtmr_get_slr $gt_found]
            if {$gt_slr eq ""} { continue }

            # GT clock region XY (for nearest-site distance).
            set mr_ref  [get_property REF_NAME $mr]
            set gt_site [get_sites -quiet -of_objects [get_cells -quiet $gt_found]]
            set gt_cr ""
            if {[llength $gt_site] > 0} { set gt_cr [get_property -quiet CLOCK_REGION $gt_site] }
            set gxy [_gtmr_cr_xy $gt_cr]

            # MRMAC/DCMAC site type.
            set stype ""
            if {[string match "MRMAC*" $mr_ref]} {
                set stype "MRMAC"
            } elseif {[string match "DCMAC*" $mr_ref]} {
                set stype "DCMAC"
            }
            if {$stype eq ""} { continue }

            # Nearest vacant site of this type in GT's SLR (skip already-assigned).
            set vac [list]
            foreach st [get_sites -quiet -filter "SITE_TYPE =~ ${stype}*"] {
                if {[get_property -quiet IS_USED $st] eq "1"} { continue }
                if {[info exists assigned_sites($st)]} { continue }
                set stslr [get_slrs -quiet -of_objects $st]
                if {[llength $stslr] == 0} { continue }
                if {[get_property -quiet NAME $stslr] ne $gt_slr} { continue }
                set cr  [get_property -quiet CLOCK_REGION $st]
                set cxy [_gtmr_cr_xy $cr]
                set d -1
                if {[llength $gxy] == 2 && [llength $cxy] == 2} {
                    set d [expr {abs([lindex $gxy 0]-[lindex $cxy 0]) + abs([lindex $gxy 1]-[lindex $cxy 1])}]
                }
                lappend vac [list $d $st $cr]
            }
            if {[llength $vac] == 0} { continue }

            set vac [lsort -integer -index 0 $vac]
            set best_site [lindex [lindex $vac 0] 1]

            lappend cmd_lines "catch { set_property LOC $best_site \[get_cells {$mr_name}\] }"
            set processed($mr_name) 1
            set assigned_sites($best_site) $mr_name
        }

        set stop [clock seconds]
        ::tclapp::xilinx::customqorflows::compile_time $start $stop "" GT_MRMAC_PREPLACE

        if {[llength $cmd_lines] == 0} { return }

        set command [join $cmd_lines "\n"]
        return [dict create COMMAND $command]
    }

    # --- Registration ---
    proc register_gt_mrmac_preplace_checks {} {
        set id            RQS_AMD_NETLIST-13
        set description   "Constrain un-LOC'd MRMAC/DCMAC to the SLR of its connected GT (pre-place) to avoid SLR-crossing timing failures"
        set auto          1
        set category      netlist
        set applicable_for place_design
        set needs_timing_data 0
        set params        [list MAX_LEVELS 3 GT_PAT {GT*} MRMAC_PAT {MRMAC*} DCMAC_PAT {DCMAC*} DEBUG 0]

        catch "delete_qor_check ${id} -quiet"
        create_qor_check -name ${id} -rule_body ::tclapp::xilinx::customqorflows::gt_mrmac_preplace \
            -property_values [list DESCRIPTION $description \
                                   AUTO $auto \
                                   CATEGORY $category \
                                   APPLICABLE_FOR $applicable_for \
                                   NEEDS_TIMING_DATA $needs_timing_data \
                                   PARAMS $params \
                                  ]
    }

    register_gt_mrmac_preplace_checks
}
