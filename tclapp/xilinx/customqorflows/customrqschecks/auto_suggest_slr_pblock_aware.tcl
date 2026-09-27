####################################################################################
#
# auto_suggest_slr_pblock_aware.tcl (customqorflows pblock-aware SLR assignment suggestion)
#
# Script created on 03/30/2026 by Madhur Chhabra, AMD
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::customqorflows {
	#namespace export new_auto_suggest_slr_pblock_aware
}

namespace eval ::tclapp::xilinx::customqorflows {

################################################################################
# fast_report_slr_crossing.tcl
#
# Fast, drop-in replacement for the full "report_slr_crossing" command.
#
# The full report builds 6 sections:
#     1. SLR Connectivity
#     2. SLR Connectivity Matrix
#     3. SLR CLB Logic and Dedicated Block Utilization
#     4. SLR Crossings by Logic Levels      <- SLOW (get_timing_paths, 30k paths)
#     5. SLR Crossings by Fanout            <- SLOW (per-net leaf enumeration)
#     6. SLR Crossings by Hierarchy of Driver
#
# auto_suggest_slr_pblock_aware.tcl only ever parses SECTION 6. This drop-in
# therefore generates ONLY section 6, skipping the expensive sections 4 & 5.
#
# The section-6 computation below is the VERBATIM phase-6 (hierarchy-of-driver)
# logic taken from /proj/DAB/gunan/scripts/report_slr_crossing.tcl, so the
# crossing counts are identical to the full report -- nothing technically
# changes, only the wasted work is removed.
#
# Sourcing this file (at file scope, before the namespace/proc below) defines
# a global "report_slr_crosssing_hierarchy" proc with the same fast section-6
# logic, called explicitly in place of the built-in command.
################################################################################

# ---- Helper: build parent map for every non-primitive cell ----
# (verbatim from report_slr_crossing.tcl)
proc build_hierarchy_tree {hier} {
    upvar $hier HIER
    set hier_cells [get_cells -hier -filter {IS_PRIMITIVE==0}]
    set parents [get_property PARENT $hier_cells]
    set i 0
    foreach hier_cell $hier_cells {
        set parent [lindex $parents $i]
        if {$parent ne ""} {set HIER($hier_cell) $parent} else {set HIER($hier_cell) TOP}
        incr i
    }
}

# ---- Helper: emit hierarchy rows in tree order with indentation ----
# (verbatim from report_slr_crossing.tcl)
proc print_hierarchy_table {table_data table_print {cell ""} {indent 0}} {
    # This needs to be ordered unlike pure data collection
    upvar $table_data TABLE_DATA
    upvar $table_print TABLE_PRINT
    if {$cell ne ""} {
        current_instance -quiet $cell
    } else {
        set ln $TABLE_PRINT(lines)
        set dat $TABLE_DATA(TOP)
        set TABLE_PRINT($ln) $dat
        incr TABLE_PRINT(lines)
        incr indent 2
    }
    set hier_cells [get_cells -quiet -filter {IS_PRIMITIVE==0}]
    current_instance -quiet

    foreach hier_cell $hier_cells {
        if {[info exists TABLE_DATA($hier_cell)]==1} {
            set dat $TABLE_DATA($hier_cell)
            set hier [lindex $dat end]
            set dat [lreplace $dat end end [string repeat " " $indent]${hier}]
            set ln $TABLE_PRINT(lines)
            set TABLE_PRINT($ln) $dat
            incr TABLE_PRINT(lines)
            print_hierarchy_table TABLE_DATA TABLE_PRINT $hier_cell [expr $indent + 2]
        }
    }
}

# ---- Fast drop-in: section 6 only ----
proc report_slr_crosssing_hierarchy {args} {
    # Accept the same options the caller uses (-file / -append); ignore the rest.
    set fn ""
    set filemode w
    set nargs [llength $args]
    for {set ai 0} {$ai < $nargs} {incr ai} {
        set a [lindex $args $ai]
        switch -regexp -- $a {
            {^-file$}   { incr ai; set fn [lindex $args $ai] }
            {^-append$} { set filemode a }
            default     { }
        }
    }

    # Preserve original behaviour on single-SLR (mono) devices: fail so the
    # caller's [catch] path flags it as a mono device. Nothing changes there.
    if {[llength [get_slrs -quiet]] < 2} {
        error "single-SLR (mono) device: no SLR crossings to report"
    }

    set fid stdout
    if {$fn ne ""} {set fid [open $fn $filemode]}

    # The section-6 computation below issues many Vivado queries; any of them
    # (or the table generation) can throw. Run it under [catch] so $fid is
    # ALWAYS closed -- even on error -- before the error is re-raised to the
    # caller's own [catch] (e.g. the "report_slr_crosssing_hierarchy -file
    # $SLR_RPT" call site). Without this, an error here leaks an open file
    # descriptor for the rest of the long-running Vivado session.
    set _err_code [catch {

    ############################################################################
    # 6. SLR Crossings by Hierarchy of Driver
    #    (verbatim phase-6 logic from /proj/DAB/gunan/scripts/report_slr_crossing.tcl)
    ############################################################################
    set nets_crossing_slrs [get_nets -quiet -parent -hier -filter {CROSSING_SLRS!=""&&TYPE==SIGNAL}]

    set driving_cells [get_cells -of [get_pins -leaf -filter {DIRECTION==OUT} -of $nets_crossing_slrs]]
    set driving_cell_parents [get_property PARENT $driving_cells]
    set driving_cell_internal [get_property PRIMITIVE_LEVEL $driving_cells]
    set driving_cell_ref_name [get_property REF_NAME $driving_cells]
    set unique_ref_names [lsort -unique -dictionary $driving_cell_ref_name]
    set HIER(TOP) ""
    build_hierarchy_tree HIER
    set i 0
    set skipped_internal 0
    foreach driving_cell $driving_cells {
        # Will skip SLR crossings driven by internal cells such as LUTCY
        set internal [lindex $driving_cell_internal $i]
        if {$internal eq "INTERNAL"} {
            incr skipped_internal
            incr i
            continue
        }
        set parent [lindex $driving_cell_parents $i]
        set ref_name [lindex $driving_cell_ref_name $i]
        if {$parent eq ""} {set parent TOP} else {set parent $parent}
        incr SLR_CROSSING_CURRENT($parent)
        incr SLR_CROSSING_CURRENT($parent,$ref_name)
        incr SLR_CROSSING_TOTAL($parent)
        incr SLR_CROSSING_TOTAL($parent,$ref_name)
        while {$parent ne "TOP"} {
            set parent $HIER($parent)
            incr SLR_CROSSING_TOTAL($parent)
            incr SLR_CROSSING_TOTAL($parent,$ref_name)
        }
        incr i
    }
    set hier_cells [get_property NAME [get_cells -hier -filter {IS_PRIMITIVE==0}]]
    lappend hier_cells TOP
    foreach hier $hier_cells {
        if {[info exists SLR_CROSSING_TOTAL($hier)]==1} {
            set slrx $SLR_CROSSING_TOTAL($hier)
            if {[info exists SLR_CROSSING_CURRENT($hier)]==1} {set slrx "${slrx} \($SLR_CROSSING_CURRENT($hier)\)"} else {set slrx "${slrx} \(0\)"}
            set TABLE($hier) [list $slrx]
            foreach unique_ref_name $unique_ref_names {
                if {[info exists SLR_CROSSING_TOTAL($hier,$unique_ref_name)]} {
                    set total_prim_count $SLR_CROSSING_TOTAL($hier,$unique_ref_name)
                    if {[info exists SLR_CROSSING_CURRENT($hier,$unique_ref_name)]} {
                        set prim_count_total_local "$total_prim_count \($SLR_CROSSING_CURRENT($hier,$unique_ref_name)\)"
                    } else {
                        set prim_count_total_local "$total_prim_count \(0\)"
                    }
                } else {
                    set prim_count_total_local "0 (0)"
                }
                lappend TABLE($hier) $prim_count_total_local
            }
            lappend TABLE($hier) $hier
        }
    }
    set TABLE_PRINT(lines) 0
    print_hierarchy_table TABLE TABLE_PRINT

    set tbl3 [xilinx::designutils::prettyTable]
    set hdr [list "# Crossings" ]
    $tbl3 header [concat $hdr $unique_ref_names Hierarchy]
    for {set i 0} {$i < $TABLE_PRINT(lines)} {incr i} {
        $tbl3 addrow $TABLE_PRINT($i)
    }

    # Emit the exact section header the parser keys on
    # ("6. SLR Crossings by Hierarchy of Driver"), then the table.
    puts $fid "6. SLR Crossings by Hierarchy of Driver"
    puts $fid "---------------------------------------"
    puts $fid ""
    puts $fid "[$tbl3 print]"
    $tbl3 destroy
    puts $fid "-I: Information excluded $skipped_internal nets driven by internal signals for compile time reasons"

    } _err_result _err_opts]

    if {$fid ne "stdout"} {close $fid}

    if {$_err_code} {
        # Re-raise with the original error code/info so the caller's [catch]
        # sees the same failure it always has -- only the leaked channel is fixed.
        return -options $_err_opts $_err_result
    }

    if {$fid ne "stdout"} {puts "-I: File [file normalize $fn] written"}
    return
}

#puts "INFO: fast_report_slr_crossing.tcl loaded - report_slr_crosssing_hierarchy now emits section 6 only."

##############################################################################################################


proc new_auto_suggest_slr_pblock_aware {args} {
    set start [clock seconds]

    set qor_dict ""
    if {$args ne ""} {
        for {set i 0} {$i < [llength $args]} {incr i} {
            set arg [lindex $args $i]
            if {$i == 0} {set qor_dict $arg}
            if {$i != 0} {puts "-E: Not expecting this arg from QoR tools"}
        }
    }

    global children_map crossing_map CROSSING_THRESHOLD assigned_slr_map
    set command [list]

################################################################################
# auto_suggest_slr_pblock_aware.tcl  (DT_no_early_exit build)
#
# Pblock-aware SLR assignment script.
#
#   1. Before assigning USER_SLR_ASSIGNMENT to any module, checks whether
#      the module's upstream (fanin) or downstream (fanout) cone contains
#      any cells/modules constrained to a pblock.  If pblocks are found in
#      the uphill or downhill path, that module is SKIPPED.
#
#   2. NO CELL_BLOAT_FACTOR / congestion constraints are generated.
#
#   3. THIS BUILD: emits ONLY two output files:
#          - suggested_slr_pblock_aware.xdc   (USER_SLR_ASSIGNMENT + net-level
#                                              USER_CROSSING_SLR 0 constraints)
#          - slr_pblock_aware_analysis.rpt    (human-readable audit trail)
#      The legacy "suggested_pblock_constraints.xdc" (hard create_pblock
#      version) is intentionally NOT produced.
#
#   4. DONT_TOUCH / MARK_DEBUG handling (CHANGED from Removing_phase_10):
#      - NONE: No DT/MD in design -> proceed normally.
#      - REMOVAL_ONLY: DT/MD exists but NOT on SLR crossings -> no removal
#        XDC written (not needed), SLR analysis continues.
#      - REMOVAL_CONTINUE: DT/MD found on SLR crossings -> write
#        remove_dont_touch_mark_debug.xdc BUT SLR analysis CONTINUES
#        (no early exit).
#
# Variables you can set BEFORE sourcing this script:
#   SLR_RPT_FROM_VANILA  - path to a pre-existing slr_crossing_vanila.rpt
#                          (e.g., ../Vanila_flow/slr_crossing_vanila.rpt)
#                          If set and the file exists, the script reuses it
#                          instead of running report_slr_crossing.
#
# Usage:
#   source auto_suggest_slr_pblock_aware.tcl
#
#   -- or, to reuse an existing crossing report --
#   set SLR_RPT_FROM_VANILA ../Vanila_flow/slr_crossing_vanila.rpt
#   source auto_suggest_slr_pblock_aware.tcl
################################################################################

# ===== User-configurable parameters =========================================
set SLR_RPT              "slr_crossing_vanila.rpt"
set CROSSING_THRESHOLD   100
set DOMINANCE_PCT        25.0
set MIN_CHILD_CROSSINGS  50
set MAX_DRILL_DEPTH      5
set OUTPUT_XDC           "suggested_slr_pblock_aware.xdc"
set OUTPUT_RPT           "slr_pblock_aware_analysis.rpt"
# -- Neighbor analysis (STEP 5a/5d) --
set NEIGHBOR_CONN_THRESH  100
set NEIGHBOR_MAX_SPLIT    40.0
set NEIGHBOR_MAX_FANOUT   500
# -- Dedicated block paths (STEP 5b) --
set DEDBLK_MAX_PATHS      10000
set DEDBLK_SLACK_THRESH   0.500
# -- Inter-SLR gap closure (STEP 6) --
set INTERSLR_MAX_PATHS    200
set INTERSLR_SLACK_THRESH 0.500
set INTERSLR_MAX_CELLS    500000
set INTERSLR_MAX_SPLIT    50.0
# -- GT/XCVR hardening (STEP 5c) --
set GT_SLACK_THRESH       0.500
set GT_MAX_PATHS          500
# -- Pipeline-reg pull-in cap (STEP 6b, ENH#5) --
set MAX_PIPELINE_REGS_PER_NEIGHBOR 50
# -- Generate-loop sibling consolidation (STEP 6, ENH#1) --
set GENLOOP_SIBLING_EXPAND 1
# -- PS9 / CIPS forced top-anchor (STEP 5, ENH#3) --
set FORCE_PS_TOP_ANCHOR    1
# -- GT-inside-module assign-to-GT-SLR (STEP 6, ENH#7) --
#    If 1: when a module contains GT(s), assign the module to the GT's SLR
#          (when single-SLR & not conflicting with boundary anchor).
#    If 0: legacy behaviour - skip module-level assignment for any GT-containing
#          module (let STEP 7 net-level USER_CROSSING_SLR 0 handle).
set GT_INSIDE_MODULE_ASSIGN 1
# -- ENH#9 (subtree-size cap): refuse to pin a hierarchy whose total cell count
#    exceeds MAX_CELL_PCT_OF_SLR%% of the target SLR's LUT capacity.
#    Rationale (Teradyne_Util54 regression): pinning a ~520k-cell subtree
#    (apg_top/ps was 99.6%% in SLR0 already) prevents the placer from spilling
#    excess logic, tripling congestion (CMR 0.06 -> 0.21) and forcing the WNS
#    path to traverse a 2.5 ns single-net cross-SLR hop. Set to 0 to disable.
set MAX_CELL_PCT_OF_SLR              60.0
# -- ENH#10 (parent-child collapse): when both a parent and its descendant
#    end up assigned, keep the one with the larger cell count and revoke the
#    other. Avoids the Util54 pattern of pinning apg_top plus 30+ of its
#    children simultaneously, which double-constrains the placer. Set 0 to
#    disable.
set COLLAPSE_PARENT_CHILD            1
# -- ENH#11 (multi-fanout USER_CROSSING_SLR=1 filter): the placer drops
#    USER_CROSSING_SLR=1 on multi-fanout nets and warns [Place 30-1228].
#    Filter at script time so we don't pollute the XDC with no-op anchors.
#    Set to a positive integer = max fanout allowed (the Vivado property is
#    only legal on single-fanout pipeline register connections, so 1 is the
#    safe default). Use a larger value to be more permissive, 0 to disable.
set CROSSING1_MAX_FANOUT             1
# -- ENH#12 (NoC-split-ancestor guard): NoC NMU/NSU/NPS primitives are
#    fixed-location silicon nodes (like GTs). If any ancestor of a target
#    module contains NoC primitives that span multiple SLRs, pinning the
#    child to a single SLR pulls soft AXI logic away from the fixed NMU/NSU
#    in the other SLR -> forces cross-SLR routing on the entire AXI/NoC
#    interface (Teradyne_Util42 regression on sys_clk312p5_buf:
#    TNS -100.7 -> -19511.8 ns, FE 3788 -> 92330 just from one S03_AXI_nmu
#    being orphaned). Set to 0 to disable.
set NOC_SPLIT_ANCESTOR_GUARD         1

# -- ENH#14 (strict pipeline-register topology): before emitting
#    USER_CROSSING_SLR=1 on a STEP 6b pipeline net, require the EXACT
#    topology Vivado expects (source is a register Q pin AND the net's single
#    load is a register D pin). Any other topology is dropped by the placer as
#    [Place 30-1228]; reject it at script time. Set 0 to fall back to ENH#11.
set STRICT_PIPELINE_REG_CHECK        1
# -- ENH#15 (SLR-consistency precheck): skip USER_CROSSING_SLR=1 when the
#    source register and its single load already resolve to the SAME SLR
#    (illusory crossing). Set 0 to disable.
set CROSSING1_SAME_SLR_SKIP          1
# -- FIX#2 (majority-based ENH#15): when resolving a pipeline endpoint's SLR
#    for the ENH#15 precheck, prefer the owning module's CELL-MAJORITY SLR
#    over the leaf cell's transient SLR_INDEX. A register placed transiently
#    in SLR0 whose module is 99% in SLR1 must resolve to SLR1, otherwise
#    ENH#15 emits a phantom crossing that perturbs placement (Util54
#    NoC->flop regression). Set 0 to use raw live SLR_INDEX.
# -- DISABLED 2026-06-07 (Barco_3screen 977408 / 977408_2 regression): the
#    majority-based resolution declared real high-speed pipeline crossings
#    "phantom" because the two parent modules shared a cell-majority SLR, even
#    though the pipeline leaf registers actually sit in the minority SLR. This
#    dropped USER_CROSSING_SLR 1 nets (319->201, 314->113) AND the neighbor
#    USER_SLR_ASSIGNMENT co-assign pins, yielding 73 sys_clk2x FLOP->FLOP
#    crossings and WNS -0.113 -> -0.339 (TNS -287 -> -843). Reverting to
#    leaf-accurate per-net resolution (ENH#15 with CROSSING1_SAME_SLR_SKIP)
#    restores the constraint set that met timing. Keep 0.
set CROSSING1_MAJORITY_SLR           0
# -- FIX#2 (DECOUPLED 2026-06-07, cross-design safe): when the assigned module
#    and a PIPELINE neighbor are both cell-MAJORITY on the SAME SLR, WITHHOLD
#    the neighbor CO-ASSIGN pin (USER_SLR_ASSIGNMENT) but STILL emit the
#    leaf-level USER_CROSSING_SLR 1 tags on its pipeline nets. Rationale from
#    the 13-design V2->V3 study:
#      * SM_Optics_rigel improved 900->95 crossings BECAUSE the old script
#        stopped PINNING 10 flexo_frm_rx/OTN_PADDING + otn_oh_proc modules.
#        Those are cell-majority on SLR1 but connectivity-pulled to SLR2
#        anchors (top_mtx_1600G/top_oduc8_sc); pinning them over-constrained
#        the placer. Re-pinning them (blanket FIX#2 disable) regresses it.
#      * Barco_3screen / Util MRMAC needed the leaf USER_CROSSING_SLR 1 tags
#        to keep high-speed pipeline regs intra-SLR.
#    Withhold-pin + keep-tags is the only variant safe for BOTH cases. The pin
#    is dropped only for already-majority modules (they place there anyway);
#    the tags still pin the actual minority-SLR leaf crossings. Set 0 to fully
#    restore co-assign pins (helps Barco zproc but risks SM_Optics regression).
set FIX2_WITHHOLD_PIN                 1
# -- ENH#17 (anchor-type conflict resolution): when a module's boundary
#    anchors of different TYPES (NoC/PCIe/PS/GT/...) land in different SLRs,
#    pinning any one orphans the others. Modes: "veto" (skip the assignment),
#    "priority" (pick by ANCHOR_PRIORITY_ORDER), "auto" (veto only on large
#    migration, else priority). Default veto.
set ANCHOR_CONFLICT_RESOLUTION       "veto"
set MIGRATION_VETO_THRESHOLD         5000
set MIGRATION_VETO_PCT               90.0
set ANCHOR_PRIORITY_ORDER            {NoC PCIe HBM MAC GT PS MMCM other}
# -- ENH#18 (cumulative SLR utilization cap): N small modules can each fit but
#    together overflow an SLR. Predict per-SLR LUT load and, on overflow,
#    fall back to the other SLR (if split small) or skip. Set 0 to disable.
set SLR_UTILIZATION_CAP_CHECK        1
set SLR_UTIL_CAP_PCT                 85.0
set SLR_UTIL_FALLBACK_SPLIT_PCT      30.0
# -- ENH#19 (PCIe-anchor timing-driven): only let a PCIe-only anchor override
#    cell-majority when a real cross-SLR setup violation exists through the
#    module. Set 0 to always honor PCIe anchor override.
set PCIE_ANCHOR_TIMING_DRIVEN        1
# -- FIX#1 (GT-split neighbor guard): in STEP 6b, do NOT pin a neighbor (or
#    emit USER_CROSSING_SLR on its pipeline path) when the neighbor or its
#    assignment ancestor contains GT primitives split across SLRs. Pinning one
#    end of a GT-split datapath forces the other SLR's GT lanes to cross
#    (Util54 idb_bridge -> pg9_mio_gtm_1_regs NoC->flop regression). This is
#    the STEP 6b analogue of the ENH#8 / ENH#12 ancestor guards. Set 0 to disable.
set GT_SPLIT_NEIGHBOR_GUARD          1
# -- ENH#20 (top-N critical-path SLR-crossing gate): gate the ENTIRE suggestion
#    (no XDC, no report, no returned constraints) on whether SLR crossings are
#    actually a meaningful contributor to the design's own worst timing paths.
#    Unless >= CRIT_PATH_GATE_PCT%% of the top CRIT_PATH_GATE_N worst setup
#    paths (by slack) cross an SLR boundary, SLR partitioning is not solving a
#    real problem for this design and the script exits early. Set 0 to disable.
set CRIT_PATH_GATE_CHECK             1
set CRIT_PATH_GATE_N                 100
set CRIT_PATH_GATE_PCT               40.0
# -- ENH#21 (Inter-SLR Compensation gate): report_timing_summary annotates the
#    clock-path delay breakdown of any path whose source/destination sit in
#    different SLRs with an "inter-SLR compensation" line (SSI derate for PVT
#    variation across SLRs). Require at least one such annotation among the
#    top CRIT_PATH_GATE_N worst setup paths before generating the SLR
#    partition suggestion; otherwise SLR crossings aren't actually incurring
#    the SSI-specific timing penalty this script exists to address. Set 0 to
#    disable.
set INTERSLR_COMPENSATION_GATE_CHECK 1
# =============================================================================

# -- Safe timestamp ----------------------------------------------------------
#    'clock format' lazy-loads tps/tcl/tcl8.6/clock.tcl from the Vivado build;
#    some nightly builds ship without that file, which makes the call throw
#    "couldn't read file .../clock.tcl".  Guard it so the script never dies on
#    a broken install - fall back to the raw epoch (or empty) if formatting
#    is unavailable.
proc _safe_timestamp {} {
    if {[catch {clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}} _ts]} {
        if {[catch {clock seconds} _epoch]} { return "" }
        return "epoch:$_epoch"
    }
    return $_ts
}

puts "========================================================================="
puts " Pblock-Aware SLR Assignment Script (No CELL_BLOAT_FACTOR, DT No Early Exit)"
puts "========================================================================="
puts " Crossing thresh    : $CROSSING_THRESHOLD"
puts " Dominance thresh   : ${DOMINANCE_PCT}%"
puts " Min child crossings: $MIN_CHILD_CROSSINGS"
puts " Max drill depth    : $MAX_DRILL_DEPTH"
puts " Output XDC         : $OUTPUT_XDC"
puts " Output Report      : $OUTPUT_RPT"
puts "=========================================================================\n"

###############################################################################
# PRE-STEP: Detect DONT_TOUCH / MARK_DEBUG on SLR-crossing drivers / nets
#
# These properties block replication and pin placement, so they are only a
# problem for SLR partitioning when they sit on (or drive) a net that
# actually crosses an SLR. This pre-step scans the design for DT/MD on:
#   - nets whose driver+loads span > 1 SLR
#   - cells whose output net drives loads in a different SLR
#
# DT_no_early_exit behavior:
#   - If DT/MD found on SLR crossings: write removal XDC but CONTINUE
#     with SLR partition suggestions (no early exit).
#   - If DT/MD exists but NOT on SLR crossings: no removal XDC written,
#     SLR analysis continues normally.
#   - If no DT/MD at all: proceed normally.
###############################################################################
puts "========================================================================="
puts " PRE-STEP: DONT_TOUCH / MARK_DEBUG SLR-Crossing Check"
puts "========================================================================="

set _dt_md_output_xdc "remove_dont_touch_mark_debug.xdc"

# ---- DT/MD status (consumed by HTML report) ---------------------------------
#   NONE             - no DT/MD found in design
#   REMOVAL_ONLY     - DT/MD found but not on SLR crossings; no removal XDC, SLR analysis continues
#   REMOVAL_CONTINUE - DT/MD found on SLR crossings; removal XDC written; SLR analysis CONTINUES
set _dt_md_status         "NONE"
set _dt_md_html_skip_reason ""

# ---- Scan all DT/MD nets, keep only those that span >1 SLR ----
set _slr_cross_dt_nets [list]
set _slr_cross_md_nets [list]

set _dt_nets_all [get_nets -quiet -hierarchical -filter {DONT_TOUCH == TRUE || DONT_TOUCH == 1}]
foreach _n $_dt_nets_all {
    set _pins  [get_pins -quiet -of_objects $_n -filter {IS_LEAF}]
    if {[llength $_pins] < 2} continue
    set _cells [get_cells -quiet -of_objects $_pins]
    if {[llength $_cells] < 2} continue
    set _slrs [lsort -unique [get_property -quiet SLR_INDEX $_cells]]
    # Drop empty strings before counting
    set _slrs_clean [list]
    foreach _s $_slrs { if {$_s ne ""} { lappend _slrs_clean $_s } }
    if {[llength $_slrs_clean] > 1} { lappend _slr_cross_dt_nets [get_property NAME $_n] }
}

set _md_nets_all [get_nets -quiet -hierarchical -filter {MARK_DEBUG == TRUE || MARK_DEBUG == 1}]
foreach _n $_md_nets_all {
    set _pins  [get_pins -quiet -of_objects $_n -filter {IS_LEAF}]
    if {[llength $_pins] < 2} continue
    set _cells [get_cells -quiet -of_objects $_pins]
    if {[llength $_cells] < 2} continue
    set _slrs [lsort -unique [get_property -quiet SLR_INDEX $_cells]]
    set _slrs_clean [list]
    foreach _s $_slrs { if {$_s ne ""} { lappend _slrs_clean $_s } }
    if {[llength $_slrs_clean] > 1} { lappend _slr_cross_md_nets [get_property NAME $_n] }
}

# ---- Scan all DT/MD cells, keep only those whose output drives a different SLR ----
set _slr_cross_dt_cells [list]
set _slr_cross_md_cells [list]

set _dt_cells_all [get_cells -quiet -hierarchical -filter {DONT_TOUCH == TRUE || DONT_TOUCH == 1}]
foreach _c $_dt_cells_all {
    set _drv_slr [get_property -quiet SLR_INDEX $_c]
    if {$_drv_slr eq ""} continue
    set _opins [get_pins -quiet -of_objects $_c -filter {DIRECTION == OUT}]
    if {[llength $_opins] == 0} continue
    set _onets [get_nets -quiet -of_objects $_opins]
    if {[llength $_onets] == 0} continue
    set _lpins [get_pins -quiet -of_objects $_onets -filter {IS_LEAF && DIRECTION == IN}]
    if {[llength $_lpins] == 0} continue
    set _lcells [get_cells -quiet -of_objects $_lpins]
    if {[llength $_lcells] == 0} continue
    set _load_slrs [lsort -unique [get_property -quiet SLR_INDEX $_lcells]]
    foreach _ls $_load_slrs {
        if {$_ls ne "" && $_ls != $_drv_slr} {
            lappend _slr_cross_dt_cells [get_property NAME $_c]
            break
        }
    }
}

set _md_cells_all [get_cells -quiet -hierarchical -filter {MARK_DEBUG == TRUE || MARK_DEBUG == 1}]
foreach _c $_md_cells_all {
    set _drv_slr [get_property -quiet SLR_INDEX $_c]
    if {$_drv_slr eq ""} continue
    set _opins [get_pins -quiet -of_objects $_c -filter {DIRECTION == OUT}]
    if {[llength $_opins] == 0} continue
    set _onets [get_nets -quiet -of_objects $_opins]
    if {[llength $_onets] == 0} continue
    set _lpins [get_pins -quiet -of_objects $_onets -filter {IS_LEAF && DIRECTION == IN}]
    if {[llength $_lpins] == 0} continue
    set _lcells [get_cells -quiet -of_objects $_lpins]
    if {[llength $_lcells] == 0} continue
    set _load_slrs [lsort -unique [get_property -quiet SLR_INDEX $_lcells]]
    foreach _ls $_load_slrs {
        if {$_ls ne "" && $_ls != $_drv_slr} {
            lappend _slr_cross_md_cells [get_property NAME $_c]
            break
        }
    }
}

set _dt_net_count   [llength $_slr_cross_dt_nets]
set _md_net_count   [llength $_slr_cross_md_nets]
set _dt_cell_count  [llength $_slr_cross_dt_cells]
set _md_cell_count  [llength $_slr_cross_md_cells]
set _total_dt_md_xslr [expr {$_dt_net_count + $_md_net_count + $_dt_cell_count + $_md_cell_count}]

# Total DT/MD present ANYWHERE in the design (not just SLR-crossing).
# Removal XDC is only produced when DT/MD is on SLR crossings.
set _total_dt_md_any [expr {[llength $_dt_nets_all] + [llength $_md_nets_all] + \
                            [llength $_dt_cells_all] + [llength $_md_cells_all]}]

puts "  SLR-crossing DONT_TOUCH nets  : $_dt_net_count   (scanned [llength $_dt_nets_all])"
puts "  SLR-crossing MARK_DEBUG nets  : $_md_net_count   (scanned [llength $_md_nets_all])"
puts "  SLR-crossing DONT_TOUCH cells : $_dt_cell_count   (scanned [llength $_dt_cells_all])"
puts "  SLR-crossing MARK_DEBUG cells : $_md_cell_count   (scanned [llength $_md_cells_all])"

if {$_total_dt_md_any > 0} {
    if {$_total_dt_md_xslr > 0} {
        # DT/MD found on SLR crossings - write removal XDC for reference, but
        # NONE of the experiment run.tcls source it. The XDC is kept on disk
        # so the user can review or apply it manually; an informational
        # summary is also embedded into suggested_slr_pblock_aware.xdc below.
        puts "  WARNING: DONT_TOUCH/MARK_DEBUG found on SLR-crossing nets/drivers."
        puts "           Writing removal XDC for reference (not auto-sourced)."
        puts "           Continuing with SLR partition analysis."
        puts ""

        puts "  Scanning entire design for ALL DONT_TOUCH/MARK_DEBUG cells and nets (for blanket removal) ..."
        set _all_dt_cells $_dt_cells_all
        set _all_md_cells $_md_cells_all
        set _all_dt_nets  $_dt_nets_all
        set _all_md_nets  $_md_nets_all

        set _all_dt_cell_count [llength $_all_dt_cells]
        set _all_md_cell_count [llength $_all_md_cells]
        set _all_dt_net_count  [llength $_all_dt_nets]
        set _all_md_net_count  [llength $_all_md_nets]

        puts "  Total DONT_TOUCH cells in design : $_all_dt_cell_count"
        puts "  Total MARK_DEBUG cells in design : $_all_md_cell_count"
        puts "  Total DONT_TOUCH nets in design  : $_all_dt_net_count"
        puts "  Total MARK_DEBUG nets in design  : $_all_md_net_count"
        puts ""
        puts "  Generating $_dt_md_output_xdc ..."

        set _dt_fp [open $_dt_md_output_xdc "w"]
        puts $_dt_fp "################################################################################"
        puts $_dt_fp "# remove_dont_touch_mark_debug.xdc"
        puts $_dt_fp "# Auto-generated by auto_suggest_slr_pblock_aware.tcl"
        puts $_dt_fp "#"
        puts $_dt_fp "# DONT_TOUCH/MARK_DEBUG detected on SLR-crossing nets / drivers."
        puts $_dt_fp "# This file removes those properties from ALL cells/nets in the design"
        puts $_dt_fp "# to allow the tool full freedom for replication and SLR placement."
        puts $_dt_fp "#"
        puts $_dt_fp "# NOTE: This XDC is NOT auto-sourced by any experiment run.tcl."
        puts $_dt_fp "#       It is written for reference only. Source it manually if you"
        puts $_dt_fp "#       want to strip the DONT_TOUCH / MARK_DEBUG properties."
        puts $_dt_fp "################################################################################"
        puts $_dt_fp ""
        puts $_dt_fp "# Offenders that triggered this XDC:"
        foreach _o $_slr_cross_dt_nets  { puts $_dt_fp "##   DT_NET (cross-SLR): $_o" }
        foreach _o $_slr_cross_md_nets  { puts $_dt_fp "##   MD_NET (cross-SLR): $_o" }
        foreach _o $_slr_cross_dt_cells { puts $_dt_fp "##   DT_CELL(cross-SLR): $_o" }
        foreach _o $_slr_cross_md_cells { puts $_dt_fp "##   MD_CELL(cross-SLR): $_o" }
        puts $_dt_fp ""

        if {$_all_dt_cell_count > 0} {
            puts $_dt_fp "## ---- Remove DONT_TOUCH from ALL cells in design ($_all_dt_cell_count) ----"
            foreach _c $_all_dt_cells {
                set _cn [get_property NAME $_c]
                puts $_dt_fp "catch \{ set_property DONT_TOUCH FALSE \[get_cells \{$_cn\}\] \}"
            }
            puts $_dt_fp ""
        }
        if {$_all_md_cell_count > 0} {
            puts $_dt_fp "## ---- Remove MARK_DEBUG from ALL cells in design ($_all_md_cell_count) ----"
            foreach _c $_all_md_cells {
                set _cn [get_property NAME $_c]
                puts $_dt_fp "catch \{ set_property MARK_DEBUG FALSE \[get_cells \{$_cn\}\] \}"
            }
            puts $_dt_fp ""
        }
        if {$_all_dt_net_count > 0} {
            puts $_dt_fp "## ---- Remove DONT_TOUCH from ALL nets in design ($_all_dt_net_count) ----"
            foreach _n $_all_dt_nets {
                set _nn [get_property NAME $_n]
                puts $_dt_fp "catch \{ set_property DONT_TOUCH FALSE \[get_nets \{$_nn\}\] \}"
            }
            puts $_dt_fp ""
        }
        if {$_all_md_net_count > 0} {
            puts $_dt_fp "## ---- Remove MARK_DEBUG from ALL nets in design ($_all_md_net_count) ----"
            foreach _n $_all_md_nets {
                set _nn [get_property NAME $_n]
                puts $_dt_fp "catch \{ set_property MARK_DEBUG FALSE \[get_nets \{$_nn\}\] \}"
            }
            puts $_dt_fp ""
        }
        close $_dt_fp
        puts "  Written: $_dt_md_output_xdc"
        puts ""

        set _dt_md_status "REMOVAL_CONTINUE"
        puts "  DT/MD on SLR crossings - removal XDC written for reference (NOT auto-sourced)."
        puts "  An informational summary is embedded inside suggested_slr_pblock_aware.xdc."
    } else {
        # DT/MD exists in design but NOT on SLR crossings - no removal XDC needed, just continue
        set _dt_md_status "REMOVAL_ONLY"
        set _all_dt_cell_count [llength $_dt_cells_all]
        set _all_md_cell_count [llength $_md_cells_all]
        set _all_dt_net_count  [llength $_dt_nets_all]
        set _all_md_net_count  [llength $_md_nets_all]
        puts "  NOTE: DONT_TOUCH/MARK_DEBUG present in design (not on SLR crossings)."
        puts "        No nets/cells crossing SLR boundaries affected - no removal XDC written."
        puts "        Continuing with SLR partition analysis."
    }
} else {
    set _dt_md_status "NONE"
    set _all_dt_cell_count 0
    set _all_md_cell_count 0
    set _all_dt_net_count  0
    set _all_md_net_count  0
    puts "  OK: No DONT_TOUCH/MARK_DEBUG anywhere in design."
}
puts "=========================================================================\n"

###############################################################################
# STEP 0: Pblock detection helper procs
#         (integrated from detect_pblock_constraints.tcl)
###############################################################################

# ---- Walk a leaf cell UP through hierarchy, collecting ancestors with pblocks
#      Returns dict: pblock_name -> list-of-hier-cells
proc _collect_hier_pblocks_slr {leaf_cell target_module} {
    set result [dict create]
    set cell_name [get_property NAME $leaf_cell]

    set path $cell_name
    while {1} {
        set idx [string last "/" $path]
        if {$idx <= 0} break
        set path [string range $path 0 [expr {$idx - 1}]]

        # Skip if this ancestor is inside the target module
        if {[string match "${target_module}/*" $path]} continue
        if {$path eq $target_module} continue

        set hier_cell [get_cells -quiet $path]
        if {[llength $hier_cell] == 0} continue

        set pb [get_pblocks -quiet -of_objects $hier_cell]
        if {[llength $pb] > 0} {
            foreach p $pb {
                set pb_name [get_property NAME $p]
                if {![dict exists $result $pb_name]} {
                    dict set result $pb_name [list]
                }
                dict lappend result $pb_name $path
            }
        }
    }
    return $result
}

# ---- Check if a module has pblocks in its upstream (fanin) or downstream
#      (fanout) cone.
#      Returns: dict with keys
#        has_conflict  (0/1)
#        module_pblock (pblock name or "")
#        upstream_pblocks   (list of pblock names)
#        downstream_pblocks (list of pblock names)
#        reason        (human-readable skip reason)
proc check_pblock_conflict {module} {

    set result [dict create has_conflict 0 module_pblock "" \
                    upstream_pblocks {} downstream_pblocks {} reason ""]

    set mod_cell [get_cells -quiet $module]
    if {[llength $mod_cell] == 0} {
        puts "    WARNING: Cell '$module' not found in design - cannot check pblocks"
        dict set result reason "cell not found"
        return $result
    }

    # ---- Check if the module itself is in a pblock -------------------------
    set mod_pblock [get_pblocks -quiet -of_objects $mod_cell]
    if {[llength $mod_pblock] > 0} {
        set pb_name [get_property NAME $mod_pblock]
        dict set result has_conflict 1
        dict set result module_pblock $pb_name
        dict set result reason "module itself assigned to pblock '$pb_name'"
        return $result
    }

    # ---- Get boundary pins of the module -----------------------------------
    set input_pins  [get_pins -quiet -of_objects $mod_cell -filter {DIRECTION == "IN"}]
    set output_pins [get_pins -quiet -of_objects $mod_cell -filter {DIRECTION == "OUT"}]

    # ---- UPSTREAM: trace fanin from module input pins ----------------------
    set upstream_pblocks [dict create]

    foreach pin $input_pins {
        set net [get_nets -quiet -of_objects $pin]
        if {[llength $net] == 0} continue

        set driver_pins [get_pins -quiet -leaf -of_objects $net \
                             -filter {DIRECTION == "OUT"}]
        foreach dpin $driver_pins {
            set dcell [get_cells -quiet -of_objects $dpin]
            if {[llength $dcell] == 0} continue

            set dcell_name [get_property NAME $dcell]
            # Skip cells inside our module
            if {[string match "${module}/*" $dcell_name]} continue

            # Check pblock on the leaf cell itself
            set pb [get_pblocks -quiet -of_objects $dcell]
            if {[llength $pb] > 0} {
                set pbn [get_property NAME $pb]
                dict set upstream_pblocks $pbn 1
            }

            # Walk UP the hierarchy from this leaf cell
            set hier_pbs [_collect_hier_pblocks_slr $dcell $module]
            dict for {pbn _} $hier_pbs {
                dict set upstream_pblocks $pbn 1
            }
        }
    }

    # ---- DOWNSTREAM: trace fanout from module output pins ------------------
    set downstream_pblocks [dict create]

    foreach pin $output_pins {
        set net [get_nets -quiet -of_objects $pin]
        if {[llength $net] == 0} continue

        set load_pins [get_pins -quiet -leaf -of_objects $net \
                           -filter {DIRECTION == "IN"}]
        foreach lpin $load_pins {
            set lcell [get_cells -quiet -of_objects $lpin]
            if {[llength $lcell] == 0} continue

            set lcell_name [get_property NAME $lcell]
            # Skip cells inside our module
            if {[string match "${module}/*" $lcell_name]} continue

            # Check pblock on the leaf cell itself
            set pb [get_pblocks -quiet -of_objects $lcell]
            if {[llength $pb] > 0} {
                set pbn [get_property NAME $pb]
                dict set downstream_pblocks $pbn 1
            }

            # Walk UP the hierarchy from this leaf cell
            set hier_pbs [_collect_hier_pblocks_slr $lcell $module]
            dict for {pbn _} $hier_pbs {
                dict set downstream_pblocks $pbn 1
            }
        }
    }

    # ---- Evaluate conflict --------------------------------------------------
    # POLICY UPDATE: Only flag has_conflict=1 when the MODULE ITSELF is in a
    # pblock. Upstream/downstream pblock cones are recorded for the report but
    # do NOT block USER_SLR_ASSIGNMENT (per spec: "if pblocks present in
    # hierarchy don't skip providing any USER_SLR suggestion to these modules").
    set up_list   [dict keys $upstream_pblocks]
    set down_list [dict keys $downstream_pblocks]

    dict set result upstream_pblocks   $up_list
    dict set result downstream_pblocks $down_list

    if {[llength $up_list] > 0 || [llength $down_list] > 0} {
        set parts {}
        if {[llength $up_list] > 0} {
            lappend parts "upstream pblock(s): [join $up_list {, }]"
        }
        if {[llength $down_list] > 0} {
            lappend parts "downstream pblock(s): [join $down_list {, }]"
        }
        dict set result reason "INFO (cone): [join $parts {; }]"
    }

    return $result
}

# NOTE: _write_pblock_assign helper removed in latest_fixes_to_partition build.
#       This version of the script intentionally generates ONLY
#       suggested_slr_pblock_aware.xdc (soft USER_SLR_ASSIGNMENT hints) and
#       slr_pblock_aware_analysis.rpt. No hard pblock constraints are emitted.

# ---- Helper: check if cell is a GT/XCVR fixed location primitive ----
proc _is_gt_primitive {cell_name} {
    set cell [get_cells -quiet $cell_name]
    if {[llength $cell] == 0} { return 0 }
    set ref [get_property REF_NAME $cell -quiet]
    # GT quad, GT channel, GT buffer primitives
    if {[string match "GTYP*" $ref] || [string match "GTM*" $ref] ||
        [string match "GTYE*" $ref] || [string match "GTHE*" $ref] ||
        [string match "BUFG_GT*" $ref] || [string match "IBUFDS_GTE*" $ref] ||
        [string match "OBUFDS_GTE*" $ref]} {
        return 1
    }
    return 0
}

# ---- Helper: check if a module contains GT fixed-location primitives ----
#      (Spec 5c.7: modules containing GTs cannot be SLR-assigned)
proc _module_contains_gt {mod_name} {
    set gt_cells [get_cells -hierarchical -filter \
        "NAME =~ ${mod_name}/* && (REF_NAME =~ GTYP* || REF_NAME =~ GTM* || REF_NAME =~ GTYE* || REF_NAME =~ GTHE* || REF_NAME =~ BUFG_GT* || REF_NAME =~ IBUFDS_GTE* || REF_NAME =~ OBUFDS_GTE*)" -quiet]
    return [expr {[llength $gt_cells] > 0}]
}

# ---- Helper (ENH#7): return the SLR_INDEX shared by ALL GT primitives inside
#      a module. Returns "SLRn" if every inside-GT sits in the same SLR n,
#      or "" if there are no GTs inside OR the GTs span multiple SLRs.
proc _inside_gt_slr {mod_name} {
    set gt_cells [get_cells -hierarchical -filter \
        "NAME =~ ${mod_name}/* && (REF_NAME =~ GTYP* || REF_NAME =~ GTM* || REF_NAME =~ GTYE* || REF_NAME =~ GTHE* || REF_NAME =~ BUFG_GT* || REF_NAME =~ IBUFDS_GTE* || REF_NAME =~ OBUFDS_GTE*)" -quiet]
    if {[llength $gt_cells] == 0} { return "" }
    array unset _slrs
    foreach gc $gt_cells {
        set s [get_property -quiet SLR_INDEX $gc]
        if {$s eq ""} continue
        set _slrs($s) 1
    }
    set keys [array names _slrs]
    if {[llength $keys] == 0} { return "" }
    if {[llength $keys] > 1} { return "" } ;# multi-SLR -> ambiguous, skip
    return "SLR[lindex $keys 0]"
}

# ---- Helper (ENH#7): detailed inside-GT breakdown for logging.
#      Returns a dict: {gt_count N  slrs {SLRa SLRb ...}  per_slr {SLR0 cnt0 SLR1 cnt1}}
proc _inside_gt_breakdown {mod_name} {
    set gt_cells [get_cells -hierarchical -filter \
        "NAME =~ ${mod_name}/* && (REF_NAME =~ GTYP* || REF_NAME =~ GTM* || REF_NAME =~ GTYE* || REF_NAME =~ GTHE* || REF_NAME =~ BUFG_GT* || REF_NAME =~ IBUFDS_GTE* || REF_NAME =~ OBUFDS_GTE*)" -quiet]
    set d [dict create gt_count [llength $gt_cells] slrs {} per_slr [dict create]]
    if {[llength $gt_cells] == 0} { return $d }
    array unset _cnt
    foreach gc $gt_cells {
        set s [get_property -quiet SLR_INDEX $gc]
        if {$s eq ""} continue
        if {![info exists _cnt($s)]} { set _cnt($s) 0 }
        incr _cnt($s)
    }
    set slrs {}
    set per [dict create]
    foreach k [lsort [array names _cnt]] {
        lappend slrs "SLR$k"
        dict set per "SLR$k" $_cnt($k)
    }
    dict set d slrs $slrs
    dict set d per_slr $per
    return $d
}

# ---- Helper (ENH#8 - GT-split ancestor guard): walks up the hierarchy of
#      $target_mod and returns the first ancestor whose subtree contains GT
#      primitives that span multiple SLRs (or are unresolved), together with a
#      breakdown dict. Returns empty list {} if no such ancestor exists.
#
#      Rationale (Teradyne_Util42 regression): when a parent like
#      matrix_io_top/mio_xcvr_top is correctly SKIPPED because its 98 GTs span
#      SLR0 and SLR1, drill-down still walks into its children (e.g.
#      mio_xcvr_link_wrapper). The child itself contains no GT primitives, so
#      the existing _module_contains_gt check passes, and the script forces all
#      ~8.6k endpoints of a GT-sourced clock (rxusrclk_out) into a single SLR.
#      That cripples skew (1.5 ns swing) and regresses WNS/TNS even when the
#      cross-SLR violation is removed. Children of a GT-split parent share the
#      same GT-sourced clock and must NOT be pinned to one SLR.
#
#      Returns: {ancestor_mod  gt_count  {SLRa SLRb ...}  "SLR0=N0, SLR1=N1"}
#      or {} if no GT-split ancestor.
proc _ancestor_with_split_gt {target_mod} {
    set parts [split $target_mod "/"]
    if {[llength $parts] < 2} { return {} }
    # Walk from immediate parent up to the L1 module (longest -> shortest path)
    for {set n [expr {[llength $parts] - 1}]} {$n >= 1} {incr n -1} {
        set ancestor [join [lrange $parts 0 [expr {$n - 1}]] "/"]
        if {$ancestor eq ""} continue
        if {![_module_contains_gt $ancestor]} continue
        set inside_slr [_inside_gt_slr $ancestor]
        if {$inside_slr ne ""} {
            # Single-SLR GTs in ancestor -> no split, safe to continue search higher
            continue
        }
        # _inside_gt_slr returned "" -> multi-SLR or unresolved GT(s) inside
        set gtb [_inside_gt_breakdown $ancestor]
        set gt_count [dict get $gtb gt_count]
        if {$gt_count == 0} { continue }
        set gt_slrs  [dict get $gtb slrs]
        set gt_per   [dict get $gtb per_slr]
        if {[llength $gt_slrs] < 2} { continue } ;# unresolved single-SLR, not a true split
        set per_str ""
        dict for {sk sv} $gt_per {
            if {$per_str ne ""} { append per_str ", " }
            append per_str "$sk=$sv"
        }
        return [list $ancestor $gt_count $gt_slrs $per_str]
    }
    return {}
}

# ---- Helper (ENH#12): check if a module contains NoC fixed-location
#      primitives (NMU/NSU/NPS, both NoC1 and NoC2 families). Mirrors the
#      primitive set recognised by _anchor_slr_for_module.
proc _module_contains_noc_anchor {mod_name} {
    set noc_cells [get_cells -hierarchical -filter \
        "NAME =~ ${mod_name}/* && (REF_NAME =~ NOC_NMU* || REF_NAME =~ NOC_NSU* || REF_NAME =~ NOC_NPS_* || REF_NAME =~ NOC2_NMU* || REF_NAME =~ NOC2_NSU* || REF_NAME =~ NOC2_NPS* || REF_NAME =~ NOC2_SCAN*)" -quiet]
    return [expr {[llength $noc_cells] > 0}]
}

# ---- Helper (ENH#12): return the SLR_INDEX shared by ALL NoC primitives
#      inside a module. "SLRn" if every inside-NoC anchor sits in the same
#      SLR n; "" if there are no NoC anchors inside OR they span multiple SLRs.
proc _inside_noc_slr {mod_name} {
    set noc_cells [get_cells -hierarchical -filter \
        "NAME =~ ${mod_name}/* && (REF_NAME =~ NOC_NMU* || REF_NAME =~ NOC_NSU* || REF_NAME =~ NOC_NPS_* || REF_NAME =~ NOC2_NMU* || REF_NAME =~ NOC2_NSU* || REF_NAME =~ NOC2_NPS* || REF_NAME =~ NOC2_SCAN*)" -quiet]
    if {[llength $noc_cells] == 0} { return "" }
    array unset _slrs
    foreach nc $noc_cells {
        set s [get_property -quiet SLR_INDEX $nc]
        if {$s eq ""} continue
        set _slrs($s) 1
    }
    set keys [array names _slrs]
    if {[llength $keys] == 0} { return "" }
    if {[llength $keys] > 1} { return "" } ;# multi-SLR -> ambiguous, skip
    return "SLR[lindex $keys 0]"
}

# ---- Helper (ENH#12): detailed inside-NoC breakdown for logging.
#      Returns dict: {noc_count N  slrs {SLRa SLRb}  per_slr {SLR0 cnt0 SLR1 cnt1}}
proc _inside_noc_breakdown {mod_name} {
    set noc_cells [get_cells -hierarchical -filter \
        "NAME =~ ${mod_name}/* && (REF_NAME =~ NOC_NMU* || REF_NAME =~ NOC_NSU* || REF_NAME =~ NOC_NPS_* || REF_NAME =~ NOC2_NMU* || REF_NAME =~ NOC2_NSU* || REF_NAME =~ NOC2_NPS* || REF_NAME =~ NOC2_SCAN*)" -quiet]
    set d [dict create noc_count [llength $noc_cells] slrs {} per_slr [dict create]]
    if {[llength $noc_cells] == 0} { return $d }
    array unset _cnt
    foreach nc $noc_cells {
        set s [get_property -quiet SLR_INDEX $nc]
        if {$s eq ""} continue
        if {![info exists _cnt($s)]} { set _cnt($s) 0 }
        incr _cnt($s)
    }
    set slrs {}
    set per [dict create]
    foreach k [lsort [array names _cnt]] {
        lappend slrs "SLR$k"
        dict set per "SLR$k" $_cnt($k)
    }
    dict set d slrs $slrs
    dict set d per_slr $per
    return $d
}

# ---- Helper (ENH#12 - NoC-split ancestor guard): walks up the hierarchy of
#      $target_mod and returns the first ancestor whose subtree contains NoC
#      NMU/NSU/NPS primitives that span multiple SLRs, together with a
#      breakdown dict. Returns empty list {} if no such ancestor.
#
#      Rationale (Teradyne_Util42 regression):
#      axi_top contained 4 NoC NMU primitives, with NMU S00/S01/S02 in SLR0
#      and S03 in SLR1. Soft AXI cell count was 94.9 %% in SLR0, so the
#      cell-distribution heuristic pinned axi_top -> SLR0. After pinning,
#      the placer dragged soft AXI logic into SLR0 but the fixed NMU S03
#      stayed in SLR1; downstream mio_cache_controller followed axi_top into
#      SLR0 -> the entire 312.5 MHz / 512-bit AXI R-channel became a SLR
#      crossing. 92k failing endpoints on sys_clk312p5_buf, TNS jumped from
#      -100 ns to -19,500 ns. The NoC NMU/NSU is exactly analogous to a GT:
#      a fixed-location silicon node that cannot be moved.
#
#      Returns: {ancestor_mod  noc_count  {SLRa SLRb ...}  "SLR0=N0, SLR1=N1"}
#      or {} if no NoC-split ancestor.
proc _ancestor_with_split_noc {target_mod} {
    set parts [split $target_mod "/"]
    if {[llength $parts] < 1} { return {} }
    # Walk from $target_mod itself, then immediate parent, up to L1.
    # Unlike ENH#8 (GT), we include $target_mod itself because the bad case
    # is the target module already containing the split NMUs (axi_top).
    for {set n [llength $parts]} {$n >= 1} {incr n -1} {
        set ancestor [join [lrange $parts 0 [expr {$n - 1}]] "/"]
        if {$ancestor eq ""} continue
        if {![_module_contains_noc_anchor $ancestor]} continue
        set inside_slr [_inside_noc_slr $ancestor]
        if {$inside_slr ne ""} {
            # Single-SLR NoC anchors in ancestor -> no split, keep searching higher
            continue
        }
        set nb [_inside_noc_breakdown $ancestor]
        set noc_count [dict get $nb noc_count]
        if {$noc_count == 0} { continue }
        set noc_slrs  [dict get $nb slrs]
        set noc_per   [dict get $nb per_slr]
        if {[llength $noc_slrs] < 2} { continue } ;# unresolved single-SLR, not a true split
        set per_str ""
        dict for {sk sv} $noc_per {
            if {$per_str ne ""} { append per_str ", " }
            append per_str "$sk=$sv"
        }
        return [list $ancestor $noc_count $noc_slrs $per_str]
    }
    return {}
}

# ---- Helper (ENH#9): per-SLR LUT capacity (cached on first call).
#      Counts SLICE sites under each SLR and multiplies by 8 (Versal SLICE
#      has 8 LUT6, conservative estimate; UltraScale+ SLICE has 8 LUT6).
#      Returns a dict {SLR0 N0 SLR1 N1 ...}. Returns empty dict on mono-SLR
#      device or if get_slrs is unavailable.
set ::_slr_lut_capacity_cache ""
proc _get_slr_lut_capacity {} {
    if {$::_slr_lut_capacity_cache ne ""} { return $::_slr_lut_capacity_cache }
    set d [dict create]
    if {[catch {set _slrs [get_slrs -quiet]} _e]} { set ::_slr_lut_capacity_cache $d; return $d }
    foreach s $_slrs {
        set sn [get_property -quiet NAME $s]
        if {$sn eq ""} continue
        set nslices [llength [get_sites -quiet -of_objects $s -filter {SITE_TYPE =~ SLICE*}]]
        dict set d $sn [expr {$nslices * 8}]
    }
    set ::_slr_lut_capacity_cache $d
    return $d
}

# ---- Helper (ENH#10): walk hierarchy of $hier and return first ancestor
#      (top-down) found as a key in the dict $map. Empty string if none.
proc _ancestor_in_map {hier map} {
    set parts [split $hier "/"]
    if {[llength $parts] < 2} { return "" }
    for {set n 1} {$n < [llength $parts]} {incr n} {
        set anc [join [lrange $parts 0 [expr {$n - 1}]] "/"]
        if {$anc eq ""} continue
        if {[dict exists $map $anc]} { return $anc }
    }
    return ""
}

# ---- Helper (ENH#10): return list of descendant keys of $hier in dict $map.
proc _descendants_in_map {hier map} {
    set out [list]
    set pre "${hier}/"
    foreach k [dict keys $map] {
        if {[string first $pre $k] == 0} { lappend out $k }
    }
    return $out
}

# ---- Helper (ENH#11): exact load count of a net (number of input-pin loads).
#      Uses FLAT_PIN_COUNT (total pins) minus 1 driver. Returns -1 on failure.
proc _net_load_fanout {net_name} {
    set _n [get_nets -quiet $net_name]
    if {[llength $_n] == 0} { return -1 }
    set fp [get_property -quiet FLAT_PIN_COUNT $_n]
    if {$fp eq "" || ![string is integer -strict $fp]} { return -1 }
    set loads [expr {$fp - 1}]
    if {$loads < 0} { set loads 0 }
    return $loads
}

# ---- Helper (ENH#14): STRICT register-pipeline topology test. Returns 1 only
#      when $net_name's driver pin is a register Q output AND the net has
#      exactly ONE load pin which is a register D input. This is the precise
#      topology Vivado will honor for USER_CROSSING_SLR=1; anything else is
#      dropped as [Place 30-1228].
proc _is_strict_pipeline_reg_net {net_name} {
    set _n [get_nets -quiet $net_name]
    if {[llength $_n] == 0} { return 0 }
    set _src [get_pins -quiet -of_objects $_n -filter {DIRECTION == "OUT"}]
    if {[llength $_src] != 1} { return 0 }
    set _loads [get_pins -quiet -of_objects $_n -filter {DIRECTION == "IN"}]
    if {[llength $_loads] != 1} { return 0 }
    # Source must be a register Q pin
    set _sref [get_property -quiet REF_NAME [get_cells -quiet -of_objects $_src]]
    set _spin [get_property -quiet REF_PIN_NAME $_src]
    if {![regexp {^(FD|LD)} $_sref] || ![regexp {^Q} $_spin]} { return 0 }
    # Load must be a register D pin
    set _lref [get_property -quiet REF_NAME [get_cells -quiet -of_objects $_loads]]
    set _lpin [get_property -quiet REF_PIN_NAME $_loads]
    if {![regexp {^(FD|LD)} $_lref] || ![regexp {^D} $_lpin]} { return 0 }
    return 1
}

# ---- Helper (ENH#15): resolve a pin's SLR using the assignment map ancestry,
#      falling back to the leaf cell's live SLR_INDEX. Reads assigned_slr_map
#      from the global scope.
proc _pin_resolved_slr {pin_obj} {
    upvar #0 assigned_slr_map _map
    set _c [get_cells -quiet -of_objects $pin_obj]
    if {[llength $_c] == 0} { return "" }
    set _cn [get_property -quiet NAME $_c]
    if {$_cn ne "" && [info exists _map]} {
        if {[dict exists $_map $_cn]} { return [dict get $_map $_cn] }
        set _parts [split $_cn "/"]
        for {set i [expr {[llength $_parts] - 1}]} {$i > 0} {incr i -1} {
            set _anc [join [lrange $_parts 0 [expr {$i - 1}]] "/"]
            if {[dict exists $_map $_anc]} { return [dict get $_map $_anc] }
        }
    }
    set _si [get_property -quiet SLR_INDEX $_c]
    if {$_si ne ""} { return "SLR$_si" }
    return ""
}

# ---- Helper (FIX#2): resolve a pin's SLR by the CELL-MAJORITY SLR of its
#      owning hierarchical module, not the leaf's transient SLR_INDEX.
#      Resolution order:
#        1. assigned_slr_map ancestry (authoritative pin already pinned)
#        2. cell-majority SLR of the immediate owning module (cached)
#        3. leaf SLR_INDEX (last resort)
#      A module-majority cache (_pin_majority_cache) avoids recomputing
#      _quiet_cell_distribution for the same module across many nets.
proc _pin_majority_slr {pin_obj} {
    upvar #0 assigned_slr_map _map
    upvar #0 _pin_majority_cache _cache
    if {![info exists _cache]} { set _cache [dict create] }
    set _c [get_cells -quiet -of_objects $pin_obj]
    if {[llength $_c] == 0} { return "" }
    set _cn [get_property -quiet NAME $_c]
    # 1. authoritative assignment ancestry
    if {$_cn ne "" && [info exists _map]} {
        if {[dict exists $_map $_cn]} { return [dict get $_map $_cn] }
        set _parts [split $_cn "/"]
        for {set i [expr {[llength $_parts] - 1}]} {$i > 0} {incr i -1} {
            set _anc [join [lrange $_parts 0 [expr {$i - 1}]] "/"]
            if {[dict exists $_map $_anc]} { return [dict get $_map $_anc] }
        }
    }
    # 2. cell-majority of the immediate owning module (parent of the leaf)
    if {$_cn ne ""} {
        set _parts [split $_cn "/"]
        if {[llength $_parts] >= 2} {
            set _owner [join [lrange $_parts 0 end-1] "/"]
            if {[dict exists $_cache $_owner]} {
                set _mv [dict get $_cache $_owner]
                if {$_mv ne ""} { return $_mv }
            } else {
                set _mv ""
                if {[llength [info commands _quiet_cell_distribution]] > 0} {
                    if {![catch {_quiet_cell_distribution $_owner} _qr]} {
                        set _mbest [lindex $_qr 1]
                        if {$_mbest ne ""} { set _mv $_mbest }
                    }
                }
                dict set _cache $_owner $_mv
                if {$_mv ne ""} { return $_mv }
            }
        }
    }
    # 3. leaf live SLR_INDEX
    set _si [get_property -quiet SLR_INDEX $_c]
    if {$_si ne ""} { return "SLR$_si" }
    return ""
}

# ---- Helper (ENH#17): classify an anchor primitive REF_NAME into a type
#      bucket. Returns one of: NoC PCIe HBM MAC GT PS MMCM other, or "" if not
#      an anchor primitive at all.
proc _anchor_classify_ref {ref} {
    if {[string match "NOC_NMU*" $ref] || [string match "NOC_NSU*" $ref]
        || [string match "NOC_NPS_*" $ref] || [string match "NOC2_NMU*" $ref]
        || [string match "NOC2_NSU*" $ref] || [string match "NOC2_NPS*" $ref]
        || [string match "NOC2_SCAN*" $ref]} { return "NoC" }
    if {[string match "PCIE*" $ref] || [string match "CPM*" $ref]} { return "PCIe" }
    if {[string match "HBMC_*" $ref] || [string match "HBM_REF_CLK*" $ref]
        || [string match "HBM_SNGLBLI*" $ref] || [string match "HBM*" $ref]} { return "HBM" }
    if {[string match "CMAC*" $ref] || [string match "MRMAC*" $ref]
        || [string match "DCMAC*" $ref] || [string match "ILKN*" $ref]} { return "MAC" }
    if {[string match "GTYP*" $ref] || [string match "GTM*" $ref]
        || [string match "GTYE*" $ref] || [string match "GTHE*" $ref]
        || [string match "BUFG_GT*" $ref] || [string match "IBUFDS_GTE*" $ref]
        || [string match "OBUFDS_GTE*" $ref]} { return "GT" }
    if {[string match "PS9*" $ref] || [string match "CIPS*" $ref]
        || [string match "PMC*" $ref] || [string match "PMCL*" $ref]
        || [string match "RPU*" $ref] || [string match "APU*" $ref]} { return "PS" }
    if {[string match "MMCME*" $ref] || [string match "PLLE*" $ref]
        || [string match "MMCM*" $ref] || [string match "PLL*" $ref]
        || [string match "XPLL*" $ref] || [string match "DPLL*" $ref]} { return "MMCM" }
    return ""
}

# ---- Helper (ENH#17): breakdown of boundary anchors by TYPE -> SLR -> count.
#      Returns dict { NoC {SLR0 N0 SLR1 N1} PCIe {...} ... }; only non-zero.
proc _anchor_breakdown_by_type {hier_mod} {
    set bd [dict create]
    set _cells [get_cells -hierarchical -filter "IS_PRIMITIVE && NAME =~ ${hier_mod}/*" -quiet]
    foreach _c $_cells {
        set _ref [get_property -quiet REF_NAME $_c]
        set _type [_anchor_classify_ref $_ref]
        if {$_type eq ""} continue
        set _si [get_property -quiet SLR_INDEX $_c]
        if {$_si eq ""} continue
        set _slr "SLR$_si"
        if {![dict exists $bd $_type]} { dict set bd $_type [dict create] }
        set _sub [dict get $bd $_type]
        if {[dict exists $_sub $_slr]} {
            dict set _sub $_slr [expr {[dict get $_sub $_slr] + 1}]
        } else {
            dict set _sub $_slr 1
        }
        dict set bd $_type $_sub
    }
    return $bd
}

# ---- Helper (ENH#17): summarise an anchor breakdown. Returns
#      {distinct_slr_list  per_type_string}.
proc _summarise_anchor_breakdown {bd} {
    set _all_slrs [dict create]
    set _parts {}
    dict for {_type _sub} $bd {
        set _ts ""
        dict for {_slr _cnt} $_sub {
            dict set _all_slrs $_slr 1
            if {$_ts ne ""} { append _ts "+" }
            append _ts "${_slr}:${_cnt}"
        }
        lappend _parts "${_type}(${_ts})"
    }
    return [list [lsort [dict keys $_all_slrs]] [join $_parts " "]]
}

# ---- Helper (ENH#17): choose the winning SLR by anchor-type priority.
#      Returns {winning_type winning_slr}; SLR is the dominant SLR within the
#      highest-priority type present. Empty if no anchors.
proc _pick_priority_anchor_slr {bd priority_order} {
    foreach _type $priority_order {
        if {![dict exists $bd $_type]} continue
        set _sub [dict get $bd $_type]
        set _best_slr ""; set _best_cnt -1
        dict for {_slr _cnt} $_sub {
            if {$_cnt > $_best_cnt} { set _best_cnt $_cnt; set _best_slr $_slr }
        }
        if {$_best_slr ne ""} { return [list $_type $_best_slr] }
    }
    return [list "" ""]
}

# ---- Helper (ENH#18): predict per-SLR LUT utilization after adding cells.
#      Reads assigned_lut_per_slr from global scope. Returns dict
#      {ok 0|1  pct <float>  cap <int>  used <int>}.
proc _predict_slr_utilization {slr_str add_cells cap_pct} {
    upvar #0 assigned_lut_per_slr _tally
    set _cap_d [_get_slr_lut_capacity]
    set _cap 0
    if {[dict exists $_cap_d $slr_str]} { set _cap [dict get $_cap_d $slr_str] }
    set _used 0
    if {[info exists _tally] && [dict exists $_tally $slr_str]} {
        set _used [dict get $_tally $slr_str]
    }
    set _new [expr {$_used + $add_cells}]
    set _pct 0.0
    if {$_cap > 0} { set _pct [expr {100.0 * $_new / $_cap}] }
    set _ok [expr {$_cap <= 0 || $_pct <= $cap_pct}]
    return [dict create ok $_ok pct $_pct cap $_cap used $_used]
}

# ---- Helper (ENH#19): does $hier_mod have a real cross-SLR setup violation
#      through it? Walks worst setup paths whose src or dst is inside the
#      module and returns 1 if any violated path crosses an SLR boundary.
proc _module_has_cross_slr_violation {hier_mod} {
    set _paths [get_timing_paths -quiet -setup -max_paths 50 -slack_less_than 0 \
        -through [get_cells -quiet -hierarchical -filter "NAME =~ ${hier_mod}/*"]]
    foreach _p $_paths {
        set _sp [get_property -quiet STARTPOINT_PIN $_p]
        set _ep [get_property -quiet ENDPOINT_PIN $_p]
        set _ss [get_property -quiet SLR_INDEX [get_cells -quiet -of_objects $_sp]]
        set _es [get_property -quiet SLR_INDEX [get_cells -quiet -of_objects $_ep]]
        if {$_ss ne "" && $_es ne "" && $_ss ne $_es} { return 1 }
    }
    return 0
}

# ---- Helper (FIX#1): GT-split neighbor guard. Returns a human-readable
#      reason string if $nmod itself, or any of its hierarchy ancestors,
#      contains GT primitives that span multiple SLRs (so pinning it / its
#      pipeline would orphan the other SLR's GT lanes); else "".
proc _gt_split_neighbor_reason {nmod} {
    # (a) the neighbor module itself holds multi-SLR GTs
    if {[_module_contains_gt $nmod]} {
        set _inside [_inside_gt_slr $nmod]
        if {$_inside eq ""} {
            set _gtb [_inside_gt_breakdown $nmod]
            if {[dict get $_gtb gt_count] > 0 && [llength [dict get $_gtb slrs]] >= 2} {
                set _per ""
                dict for {sk sv} [dict get $_gtb per_slr] {
                    if {$_per ne ""} { append _per ", " }
                    append _per "$sk=$sv"
                }
                return "neighbor $nmod has [dict get $_gtb gt_count] GTs split across SLRs ($_per)"
            }
        }
    }
    # (b) an ancestor of the neighbor is GT-split (reuses ENH#8 walker)
    set _anc [_ancestor_with_split_gt $nmod]
    if {[llength $_anc] >= 4} {
        lassign $_anc _amod _acnt _aslrs _aper
        return "neighbor ancestor $_amod has $_acnt GTs split across [llength $_aslrs] SLRs ($_aper)"
    }
    return ""
}

###############################################################################
# STEP 1: Generate / reuse the SLR crossing report
###############################################################################
puts "STEP 1: SLR crossing report..."

set is_mono_device 0

# If caller provided a pre-existing report path, reuse it
if {[info exists SLR_RPT_FROM_VANILA] && [file exists $SLR_RPT_FROM_VANILA]} {
    set SLR_RPT $SLR_RPT_FROM_VANILA
    puts "  Reusing existing report: $SLR_RPT"
} else {
    puts "  Generating SLR crossing report..."
    if {[catch {report_slr_crosssing_hierarchy -file $SLR_RPT} slr_err]} {
        puts "  WARNING: report_slr_crosssing_hierarchy failed: $slr_err"
        puts "  This is likely a mono-SLR (single-die) device. Skipping SLR analysis."
        set is_mono_device 1
    } else {
        puts "  Generated: $SLR_RPT"
    }
}

if {!$is_mono_device && ![file exists $SLR_RPT]} {
    puts "WARNING: Cannot find $SLR_RPT - treating as mono device"
    set is_mono_device 1
}

# ---- Parse all hierarchy entries from crossing report -----------------------
set all_entries {}

if {!$is_mono_device && [file exists $SLR_RPT]} {
    set fp [open $SLR_RPT r]
    set in_section6 0

    while {[gets $fp line] >= 0} {
        if {[string match "*6. SLR Crossings by Hierarchy of Driver*" $line]} {
            set in_section6 1
            continue
        }
        if {!$in_section6} continue

        if {[string match "+---*" $line]} continue
        if {[string match "*# Crossings*" $line]} continue

        if {[regexp {^\|\s+(\d+)\s+\((\d+)\)\s*\|.*\|\s+([ ]*)(\S.*?)\s*$} $line -> crossings self_crossings indent_str hier]} {
            set hier [string trimright $hier " |"]
            set hier [string trim $hier]
            if {$hier eq "TOP"} {
                set depth 0
            } else {
                set depth [expr {[llength [split $hier "/"]] }]
            }
            lappend all_entries [list $depth $hier $crossings $self_crossings]
        }
    }
    close $fp
    puts "  Parsed [llength $all_entries] hierarchy entries from report."
}

###############################################################################
# STEP 1.5: Top-N critical-path SLR-crossing gate (ENH#20)
#
# Gates the ENTIRE suggestion: unless a meaningful share of the design's own
# top-$CRIT_PATH_GATE_N worst setup paths (by slack) actually cross an SLR
# boundary, SLR partitioning isn't addressing a real problem for this design.
# Combined with the ENH#21 Inter-SLR Compensation check below via OR: the
# suggestion proceeds if EITHER check finds evidence of a real SLR-crossing
# timing problem; it is skipped only if BOTH checks come back negative.
###############################################################################
puts "\nSTEP 1.5: Top-$CRIT_PATH_GATE_N critical-path SLR-crossing gate...\n"

set crit100_total 0
set crit100_cross 0
set crit100_pct   0.0
set crit_path_gate_pass 1

if {$CRIT_PATH_GATE_CHECK && !$is_mono_device} {
    if {[catch {get_timing_paths -quiet -max_paths $CRIT_PATH_GATE_N -sort_by slack -setup} _crit100_paths]} {
        set _crit100_paths {}
    }
    set crit100_total [llength $_crit100_paths]

    foreach _c100p $_crit100_paths {
        set _c100_sp [get_property -quiet STARTPOINT_PIN $_c100p]
        set _c100_ep [get_property -quiet ENDPOINT_PIN   $_c100p]
        set _c100_sc [get_cells -quiet -of_objects [get_pins -quiet $_c100_sp]]
        set _c100_ec [get_cells -quiet -of_objects [get_pins -quiet $_c100_ep]]
        set _c100_sslr ""; set _c100_dslr ""
        if {[llength $_c100_sc] > 0} { set _c100_sslr [get_property -quiet SLR_INDEX $_c100_sc] }
        if {[llength $_c100_ec] > 0} { set _c100_dslr [get_property -quiet SLR_INDEX $_c100_ec] }
        if {$_c100_sslr ne "" && $_c100_dslr ne "" && $_c100_sslr ne $_c100_dslr} {
            incr crit100_cross
        }
    }

    if {$crit100_total > 0} {
        set crit100_pct [expr {100.0 * $crit100_cross / $crit100_total}]
    }

    puts "  Top-$CRIT_PATH_GATE_N worst setup paths analyzed : $crit100_total"
    puts "  Of those, SLR-crossing paths                     : $crit100_cross"
    puts [format "  SLR-crossing percentage                          : %.1f%%  (threshold: %.1f%%)" $crit100_pct $CRIT_PATH_GATE_PCT]

    if {$crit100_total == 0 || $crit100_pct < $CRIT_PATH_GATE_PCT} {
        set crit_path_gate_pass 0
        puts [format "  NEGATIVE: Only %.1f%% of the top $CRIT_PATH_GATE_N critical setup paths cross an" $crit100_pct]
        puts [format "            SLR boundary (< %.1f%% threshold)." $CRIT_PATH_GATE_PCT]
    } else {
        puts "  POSITIVE: SLR crossings are a significant contributor to the top critical paths."
    }
} elseif {$CRIT_PATH_GATE_CHECK} {
    puts "  Mono-SLR device - gate not applicable (no SLR crossings possible)."
} else {
    puts "  Gate disabled (CRIT_PATH_GATE_CHECK=0) - not counted against the combined decision."
}
puts "=========================================================================\n"

###############################################################################
# STEP 1.6: Inter-SLR Compensation check (report_timing_summary) (ENH#21)
#
# Additional check alongside ENH#20: report_timing_summary's path-detail
# breakdown annotates any path whose clock path crosses an SLR boundary with
# an "inter-SLR compensation" line (the SSI derate inserted for PVT variation
# between SLRs). Combined with the ENH#20 check above via OR (see decision
# block below).
###############################################################################
puts "\nSTEP 1.6: Inter-SLR Compensation check (report_timing_summary)...\n"

set interslr_comp_found 0
set interslr_comp_gate_pass 1

# ---- Helper: reserve a scratch-report path that did not previously exist as
#      a file OR a symlink. {CREAT EXCL} makes the open fail if anything is
#      already at that name (Vivado runs typically re-use the same working
#      directory across attempts), so a pre-existing file/symlink there can
#      neither redirect our output nor get silently clobbered. The pid +
#      random suffix (retried on any collision) also keeps concurrent or
#      repeated runs in the same directory from colliding on one fixed name.
proc _reserve_scratch_report {prefix} {
    for {set _try 0} {$_try < 20} {incr _try} {
        set _cand "${prefix}_[pid]_[expr {int(rand()*1000000)}]_${_try}.rpt"
        if {![catch {
            set _fh [open $_cand {WRONLY CREAT EXCL}]
            close $_fh
        }]} {
            return $_cand
        }
    }
    error "could not reserve a unique scratch report path for prefix '$prefix'"
}

if {$INTERSLR_COMPENSATION_GATE_CHECK && !$is_mono_device} {
    if {[catch {_reserve_scratch_report "interslr_compensation_check"} _rts_tmp]} {
        puts "  WARNING: $_rts_tmp"
        puts "  Treating Inter-SLR Compensation check as not found."
    } else {
        if {[catch {report_timing_summary -max_paths $CRIT_PATH_GATE_N -setup -file $_rts_tmp} _rts_err]} {
            puts "  WARNING: report_timing_summary failed: $_rts_err"
            puts "  Treating Inter-SLR Compensation check as not found."
        } elseif {[file exists $_rts_tmp]} {
            if {[catch {
                set _rts_fp [open $_rts_tmp r]
                while {[gets $_rts_fp _rts_line] >= 0} {
                    if {[string match -nocase "*inter-slr compensation*" $_rts_line]} {
                        set interslr_comp_found 1
                        break
                    }
                }
                close $_rts_fp
            } _rts_read_err]} {
                puts "  WARNING: could not read $_rts_tmp: $_rts_read_err"
            }
        }
        # Purely an internal scratch file (not a documented output) - always
        # remove it, whether the checks above succeeded or failed.
        catch {file delete -force -- $_rts_tmp}
    }

    if {$interslr_comp_found} {
        puts "  POSITIVE: At least one of the top-$CRIT_PATH_GATE_N worst setup paths reports"
        puts "            Inter-SLR Compensation."
    } else {
        set interslr_comp_gate_pass 0
        puts "  NEGATIVE: No path among the top-$CRIT_PATH_GATE_N worst setup paths reports"
        puts "            Inter-SLR Compensation."
    }
} elseif {$INTERSLR_COMPENSATION_GATE_CHECK} {
    puts "  Mono-SLR device - check not applicable (no SLR crossings possible)."
} else {
    puts "  Gate disabled (INTERSLR_COMPENSATION_GATE_CHECK=0) - not counted against the combined decision."
}
puts "=========================================================================\n"

###############################################################################
# STEP 1.7: Combined ENH#20 / ENH#21 gate decision (OR)
#
# Proceed if EITHER the top-N critical-path SLR-crossing percentage check
# (ENH#20) OR the Inter-SLR Compensation check (ENH#21) found evidence of a
# real SLR-crossing timing problem. Skip the suggestion entirely (no XDC, no
# report, no HTML, no returned COMMAND) only when BOTH come back negative.
# A disabled or not-applicable (mono-device) check never blocks on its own.
###############################################################################
if {!$crit_path_gate_pass && !$interslr_comp_gate_pass} {
    puts "STEP 1.7: Combined gate decision..."
    puts "  SKIP: Neither the top-$CRIT_PATH_GATE_N critical-path SLR-crossing check nor"
    puts "        the Inter-SLR Compensation check found evidence that SLR crossings are"
    puts "        a significant contributor to timing on this design - skipping the SLR"
    puts "        partition suggestion entirely (no XDC/report generated)."
    puts "=========================================================================\n"
    set stop [clock seconds]
    ::tclapp::xilinx::customqorflows::compile_time $start $stop
    return
}

###############################################################################
# STEP 2: Build parent-children map for drill-down
###############################################################################
puts "\nSTEP 2: Building hierarchy tree and identifying critical modules...\n"

array unset children_map
array unset crossing_map

foreach entry $all_entries {
    lassign $entry depth hier crossings self_crossings
    set crossing_map($hier) $crossings
}

for {set i 0} {$i < [llength $all_entries]} {incr i} {
    lassign [lindex $all_entries $i] parent_depth parent_hier parent_crossings parent_self

    set child_list {}

    if {$parent_hier eq "TOP"} {
        for {set j [expr {$i + 1}]} {$j < [llength $all_entries]} {incr j} {
            lassign [lindex $all_entries $j] child_depth child_hier child_crossings child_self
            if {$child_depth == 1 && [string first "/" $child_hier] == -1} {
                lappend child_list [list $child_hier $child_crossings $child_self]
            }
        }
    } else {
        for {set j [expr {$i + 1}]} {$j < [llength $all_entries]} {incr j} {
            lassign [lindex $all_entries $j] child_depth child_hier child_crossings child_self
            if {![string match "${parent_hier}/*" $child_hier]} {
                if {$child_depth <= $parent_depth} break
                continue
            }
            if {$child_depth == $parent_depth + 1} {
                lappend child_list [list $child_hier $child_crossings $child_self]
            }
        }
    }
    set children_map($parent_hier) $child_list
}

###############################################################################
# STEP 3: Identify first-level critical modules
###############################################################################
set critical_L1 {}
foreach entry $all_entries {
    lassign $entry depth hier crossings self_crossings
    if {$depth == 1 && $crossings >= $CROSSING_THRESHOLD} {
        lappend critical_L1 [list $hier $crossings]
    }
}

if {[llength $critical_L1] == 0} {
    puts "WARNING: No first-level modules found with >= $CROSSING_THRESHOLD crossings"
    if {$is_mono_device} {
        puts "  Mono-SLR device detected - no SLR assignment needed."
    } else {
        puts "  Multi-SLR device but no critical crossings."
        puts "  Skipping SLR assignment; will still check dedicated-block paths (STEP 7)."
    }
} else {
    puts "  Found [llength $critical_L1] critical first-level module(s):"
    puts [format "  %-60s %10s" "Module" "Crossings"]
    puts "  [string repeat - 72]"
    foreach entry $critical_L1 {
        lassign $entry mod xcount
        puts [format "  %-60s %10d" $mod $xcount]
    }
}

###############################################################################
# STEP 4: Deep hierarchy drill-down
###############################################################################
puts "\nSTEP 4: Drilling into hierarchy to find optimal assignment targets...\n"

# ---- Helper: check if a candidate hier module has setup-timing violations
#      passing through it. Returns 1 if at least one violating path exists.
#      Per spec: only pick a module/child if it is actually timing-critical;
#      otherwise skip it (do NOT emit any constraint).
proc _module_has_setup_violation {hier_mod} {
    set cell [get_cells -quiet $hier_mod]
    if {[llength $cell] == 0} { return 0 }
    # -through accepts cells; query a tiny budget for speed.
    if {[catch {
        set vp [get_timing_paths -quiet -through $cell -max_paths 1 -nworst 1 \
                    -setup -slack_lesser_than 0.0]
    } err]} {
        return 0
    }
    return [expr {[llength $vp] > 0}]
}

proc drill_down {parent_hier parent_crossings depth_limit current_depth dominance_pct min_child_crossings} {
    global children_map crossing_map CROSSING_THRESHOLD

    if {$current_depth >= $depth_limit} {
        return [list $parent_hier $parent_crossings "stopped at max drill depth $depth_limit"]
    }

    if {![info exists children_map($parent_hier)]} {
        return [list $parent_hier $parent_crossings "leaf module (no children in report)"]
    }

    set child_list $children_map($parent_hier)
    if {[llength $child_list] == 0} {
        return [list $parent_hier $parent_crossings "no children found"]
    }

    # Collect ALL significant children (crossings >= CROSSING_THRESHOLD)
    set significant_children {}
    set total_child_crossings 0

    foreach child_entry $child_list {
        lassign $child_entry c_hier c_crossings c_self
        set total_child_crossings [expr {$total_child_crossings + $c_crossings}]
        if {$c_crossings >= $min_child_crossings} {
            lappend significant_children [list $c_hier $c_crossings]
        }
    }

    if {[llength $significant_children] == 0} {
        set reason "no children with >= $min_child_crossings crossings"
        return [list $parent_hier $parent_crossings $reason]
    }

    # If only one significant child, drill into it (original single-path behavior)
    if {[llength $significant_children] == 1} {
        lassign [lindex $significant_children 0] sc_hier sc_crossings
        set sc_pct [expr {$parent_crossings > 0 ? double($sc_crossings) / $parent_crossings * 100.0 : 0.0}]

        if {$sc_pct >= $dominance_pct} {
            puts [format "    %s-> %s has %d/%d crossings (%.1f%%) - drilling deeper..." \
                [string repeat "  " $current_depth] $sc_hier $sc_crossings $parent_crossings $sc_pct]
            return [drill_down $sc_hier $sc_crossings $depth_limit \
                [expr {$current_depth + 1}] $dominance_pct $min_child_crossings]
        } else {
            set reason [format "single significant child %.1f%% < %.1f%% threshold" $sc_pct $dominance_pct]
            return [list $parent_hier $parent_crossings $reason]
        }
    }

    # Multiple significant children — assign at this parent level
    # (The caller in STEP 4 will handle drilling into each child separately)
    set reason [format "crossings spread across %d significant children" [llength $significant_children]]
    return [list $parent_hier $parent_crossings $reason]
}

set assignment_targets {}
set assignment_targets_seen [dict create]

foreach entry $critical_L1 {
    lassign $entry mod xcount
    puts "  Analyzing: $mod ($xcount crossings)"

    # ---- Collect all children above CROSSING_THRESHOLD --------------------
    set significant_children {}
    if {[info exists children_map($mod)]} {
        foreach child_entry $children_map($mod) {
            lassign $child_entry c_hier c_crossings c_self
            if {$c_crossings >= $CROSSING_THRESHOLD} {
                lappend significant_children [list $c_hier $c_crossings]
            }
        }
    }

    if {[llength $significant_children] <= 1} {
        # 0 or 1 significant children: use original single-target drill-down
        set result [drill_down $mod $xcount $MAX_DRILL_DEPTH 0 $DOMINANCE_PCT $MIN_CHILD_CROSSINGS]
        lassign $result target_mod target_crossings reason

        if {$target_mod eq $mod} {
            puts "    => TARGET at L1 level: $mod"
            puts "       Reason: $reason"
        } else {
            puts "    => TARGET at submodule: $target_mod"
            puts "       Drilled from $mod ($xcount) -> $target_mod ($target_crossings)"
            puts "       Stop reason: $reason"
        }
        puts ""

        if {[dict exists $assignment_targets_seen $target_mod]} {
            puts "    ** DUPLICATE: $target_mod already targeted (from [dict get $assignment_targets_seen $target_mod]) - skipping"
        } elseif {![_module_has_setup_violation $target_mod]} {
            puts "    ** TIMING-CLEAN: $target_mod has no setup-violating paths through it - skipping (no constraint emitted)"
        } else {
            lappend assignment_targets [list $target_mod $target_crossings $mod $xcount $reason]
            dict set assignment_targets_seen $target_mod $mod
        }
    } else {
        # Multiple significant children — drill each independently
        puts "    Found [llength $significant_children] children above $CROSSING_THRESHOLD crossings:"
        foreach sc [lsort -real -decreasing -index 1 $significant_children] {
            lassign $sc c_hier c_crossings
            puts [format "      %s : %d crossings (%.1f%% of parent)" \
                $c_hier $c_crossings [expr {double($c_crossings) / $xcount * 100.0}]]
        }
        puts ""

        foreach sc [lsort -real -decreasing -index 1 $significant_children] {
            lassign $sc c_hier c_crossings
            puts [format "    Drilling: %s (%d crossings, %.1f%%)" \
                $c_hier $c_crossings [expr {double($c_crossings) / $xcount * 100.0}]]

            set result [drill_down $c_hier $c_crossings $MAX_DRILL_DEPTH 1 \
                $DOMINANCE_PCT $MIN_CHILD_CROSSINGS]
            lassign $result target_mod target_crossings reason

            if {$target_mod eq $c_hier} {
                puts "       => TARGET: $target_mod"
                puts "          Reason: $reason"
            } else {
                puts "       => TARGET at submodule: $target_mod"
                puts "          Drilled from $c_hier ($c_crossings) -> $target_mod ($target_crossings)"
                puts "          Stop reason: $reason"
            }
            puts ""

            if {[dict exists $assignment_targets_seen $target_mod]} {
                puts "       ** DUPLICATE: $target_mod already targeted (from [dict get $assignment_targets_seen $target_mod]) - skipping"
            } elseif {![_module_has_setup_violation $target_mod]} {
                puts "       ** TIMING-CLEAN: $target_mod has no setup-violating paths through it - skipping (no constraint emitted)"
            } else {
                lappend assignment_targets [list $target_mod $target_crossings $mod $xcount $reason]
                dict set assignment_targets_seen $target_mod $mod
            }
        }
    }
}

###############################################################################
# STEP 5: Cell distribution per SLR for each target
###############################################################################

# ---- Helper: if a target module has any connection (fanin or fanout) to a
#      PCIE or GT/XCVR primitive that is fixed-placed in a specific SLR,
#      return that SLR string (e.g., "SLR2"). Otherwise return "".
#      Spec: "if the current module is having any connection with PCIE or GT
#      which is placed in any particular SLR, assign the module to that SLR;
#      if not go with majority of the cell utilization."
proc _anchor_slr_for_module {hier_mod} {
    set mod_cell [get_cells -quiet $hier_mod]
    if {[llength $mod_cell] == 0} { return "" }

    set boundary_pins [get_pins -quiet -of_objects $mod_cell]
    if {[llength $boundary_pins] == 0} { return "" }

    array set anchor_slr_count {}

    foreach pin $boundary_pins {
        set net [get_nets -quiet -of_objects $pin]
        if {[llength $net] == 0} continue
        # Skip huge nets (clocks/resets) for speed
        set fc [get_property -quiet FLAT_PIN_COUNT $net]
        if {$fc eq "" || $fc > 2000} continue

        set leaf_pins [get_pins -quiet -leaf -of_objects $net]
        foreach lp $leaf_pins {
            set lcell [get_cells -quiet -of_objects $lp]
            if {[llength $lcell] == 0} continue
            set lname [get_property NAME $lcell]
            if {[string match "${hier_mod}/*" $lname] || $lname eq $hier_mod} continue

            set ref [get_property -quiet REF_NAME $lcell]
            set is_anchor 0
            # PCIE primitives
            if {[string match "PCIE*" $ref] || [string match "CPM*" $ref]} {
                set is_anchor 1
            }
            # GT/XCVR primitives
            if {!$is_anchor && (
                [string match "GTYP*" $ref] || [string match "GTM*" $ref] ||
                [string match "GTYE*" $ref] || [string match "GTHE*" $ref] ||
                [string match "BUFG_GT*" $ref] || [string match "IBUFDS_GTE*" $ref] ||
                [string match "OBUFDS_GTE*" $ref])} {
                set is_anchor 1
            }
            # NoC primitives (NMU/NSU/NPS - both NoC1 and NoC2 families)
            if {!$is_anchor && (
                [string match "NOC_NMU*"  $ref] || [string match "NOC_NSU*"  $ref] ||
                [string match "NOC_NPS_*" $ref] || [string match "NOC2_NMU*" $ref] ||
                [string match "NOC2_NSU*" $ref] || [string match "NOC2_NPS*" $ref] ||
                [string match "NOC2_SCAN*" $ref])} {
                set is_anchor 1
            }
            # HBM primitives
            if {!$is_anchor && (
                [string match "HBMC_*"      $ref] || [string match "HBM_REF_CLK*" $ref] ||
                [string match "HBM_SNGLBLI*" $ref] || [string match "HBM*"         $ref])} {
                set is_anchor 1
            }
            # MMCM / PLL / clocking site-locked primitives
            if {!$is_anchor && (
                [string match "MMCME*"  $ref] || [string match "PLLE*"   $ref] ||
                [string match "MMCM*"   $ref] || [string match "PLL*"    $ref] ||
                [string match "XPLL*"   $ref] || [string match "DPLL*"   $ref])} {
                set is_anchor 1
            }
            # High-speed MAC / Ethernet hard blocks
            if {!$is_anchor && (
                [string match "CMAC*"   $ref] || [string match "MRMAC*"  $ref] ||
                [string match "DCMAC*"  $ref] || [string match "ILKN*"   $ref])} {
                set is_anchor 1
            }
            # SYSMON / system-monitor / management blocks
            if {!$is_anchor && (
                [string match "SYSMON*" $ref] || [string match "PMV*"    $ref] ||
                [string match "BSCAN*"  $ref] || [string match "DNA_*"   $ref] ||
                [string match "EFUSE_*" $ref] || [string match "STARTUP*" $ref] ||
                [string match "ICAP*"   $ref] || [string match "FRAME_ECC*" $ref])} {
                set is_anchor 1
            }
            # AI Engine / DSP58-locked / VCU / VDU / HSC site-locked tiles
            if {!$is_anchor && (
                [string match "AIE*"    $ref] || [string match "VCU*"    $ref] ||
                [string match "VDU*"    $ref] || [string match "HSC*"    $ref] ||
                [string match "PS*"     $ref] || [string match "RPU*"    $ref] ||
                [string match "APU*"    $ref])} {
                set is_anchor 1
            }
            if {!$is_anchor} continue

            set s [get_property -quiet SLR_INDEX $lcell]
            if {$s eq ""} continue
            if {![info exists anchor_slr_count($s)]} { set anchor_slr_count($s) 0 }
            incr anchor_slr_count($s)
        }
    }

    if {[array size anchor_slr_count] == 0} { return "" }

    # Pick the anchor SLR with most connections
    set best -1
    set best_slr ""
    foreach s [array names anchor_slr_count] {
        if {$anchor_slr_count($s) > $best} {
            set best $anchor_slr_count($s)
            set best_slr "SLR$s"
        }
    }
    return $best_slr
}

proc report_leaf_cells_per_slr {cell_name} {
    if {$cell_name eq ""} {
        set leaves [get_cells -hierarchical -filter {IS_PRIMITIVE}]
    } else {
        set leaves [get_cells -hierarchical -filter "IS_PRIMITIVE && NAME =~ ${cell_name}/*"]
    }
    set total [llength $leaves]
    if {$total == 0} { puts "No leaf cells found under '$cell_name'."; return [list 0 "" 0 0 0.0 ""] }

    array set slr_count {}
    set unplaced 0

    set slrs [get_property SLR_INDEX $leaves]
    foreach slr $slrs {
        if {$slr eq ""} {
            incr unplaced
        } else {
            if {![info exists slr_count($slr)]} { set slr_count($slr) 0 }
            incr slr_count($slr)
        }
    }

    puts "----------------------------------------------"
    puts " Leaf Cell SLR Distribution for: $cell_name"
    puts "----------------------------------------------"
    set best_slr ""
    set best_count 0
    set dist_str ""
    foreach slr [lsort -integer [array names slr_count]] {
        set pct [format "%.1f" [expr {100.0 * $slr_count($slr) / $total}]]
        puts [format " SLR%-4s : %8d cells  (%s%%)" $slr $slr_count($slr) $pct]
        if {$dist_str ne ""} { append dist_str "  " }
        append dist_str [format "SLR%s=%d (%s%%)" $slr $slr_count($slr) $pct]
        if {$slr_count($slr) > $best_count} {
            set best_count $slr_count($slr)
            set best_slr "SLR$slr"
        }
    }
    if {$unplaced > 0} {
        set pct [format "%.1f" [expr {100.0 * $unplaced / $total}]]
        puts [format " Unplaced: %8d cells  (%s%%)" $unplaced $pct]
    }
    puts "----------------------------------------------"
    puts [format " Total   : %8d cells" $total]
    puts "----------------------------------------------"

    set minority_count [expr {$total - $best_count}]
    set split_pct [expr {$total > 0 ? double($minority_count) / $total * 100.0 : 0.0}]

    return [list $total $best_slr $best_count $minority_count $split_pct $dist_str]
}

puts "========================================================================="
puts " STEP 5: Analyzing cell distribution per SLR for assignment targets..."
puts "=========================================================================\n"

# ============================================================================
# ENH#3 (PS9/CIPS forced top-anchor): the PS9 / CIPS / PMC subsystem is a
# site-locked Versal hard block that anchors a specific SLR but rarely shows
# up in report_slr_crosssing_hierarchy as a hot module (its boundary nets are short).
# Walk every PS9/CIPS/PMC primitive, ascend to the TOP-LEVEL wrapper cell,
# and inject that wrapper into the assignment_targets list (if not already
# present) with the SLR of the PS primitive.
# ============================================================================
if {$FORCE_PS_TOP_ANCHOR && !$is_mono_device} {
    puts "  ENH#3: Scanning for PS9/CIPS/PMC anchors to force top-level assignment..."
    set _ps_prims [get_cells -quiet -hierarchical \
        -filter {REF_NAME =~ PS9* || REF_NAME =~ CIPS* || REF_NAME =~ PMC* || REF_NAME =~ PMCL*}]
    if {[llength $_ps_prims] > 0} {
        array unset _ps_top_slr
        foreach _pp $_ps_prims {
            set _pname [get_property NAME $_pp]
            set _pslr [get_property -quiet SLR_INDEX $_pp]
            if {$_pslr eq ""} continue
            # Top-level wrapper = first hier component
            set _top [lindex [split $_pname "/"] 0]
            if {$_top eq ""} continue
            if {![info exists _ps_top_slr($_top)]} {
                set _ps_top_slr($_top) "SLR$_pslr"
                puts "    PS anchor: $_top -> SLR$_pslr (from [get_property REF_NAME $_pp] '$_pname')"
            }
        }
        foreach _top [array names _ps_top_slr] {
            # Skip if already in assignment_targets
            set _already 0
            foreach _t $assignment_targets {
                if {[lindex $_t 0] eq $_top} { set _already 1; break }
            }
            if {$_already} {
                puts "    PS top '$_top' already in targets - skipping inject"
                continue
            }
            set _xc 0
            if {[info exists crossing_map($_top)]} { set _xc $crossing_map($_top) }
            lappend assignment_targets [list $_top $_xc "" 0 "PS/CIPS forced anchor (ENH#3) -> $_ps_top_slr($_top)"]
            puts "    INJECTED into assignment_targets: $_top (crossings=$_xc, forced=$_ps_top_slr($_top))"
        }
    } else {
        puts "    No PS9/CIPS/PMC primitives found - skipping forced anchor pre-pass."
    }
    puts ""
}

set rpt_lines {}
# ENH#17 veto map: target_mod -> human-readable veto reason (STEP 6 will skip)
set anchor_conflict_veto [dict create]
# ENH#17 / ENH#19 telemetry counters (visible to STEP 6 too)
set _enh17_conflict_detected   0
set _enh17_veto_applied        0
set _enh17_priority_picked     0
set _enh19_pcie_timing_skipped 0

foreach target_entry $assignment_targets {
    lassign $target_entry target_mod target_crossings orig_mod orig_crossings reason

    lassign [report_leaf_cells_per_slr $target_mod] \
        total_cells best_slr best_count minority_count split_pct dist_str

    # ---- ENH#17: anchor-type conflict detection ---------------------------
    # When boundary anchors of different TYPES (NoC, PCIe, PS, GT, MMCM, ...)
    # land in DIFFERENT SLRs, picking any one of them silently orphans the
    # others. Resolve via "priority" / "veto" / "auto" (see knob block).
    set _anchor_bd [_anchor_breakdown_by_type $target_mod]
    set _anchor_summary [_summarise_anchor_breakdown $_anchor_bd]
    set _anchor_distinct_slrs [lindex $_anchor_summary 0]
    set _anchor_per_type_str  [lindex $_anchor_summary 1]
    set _has_anchor_conflict  [expr {[llength $_anchor_distinct_slrs] >= 2}]

    if {$_has_anchor_conflict} {
        incr _enh17_conflict_detected
        lassign [_pick_priority_anchor_slr $_anchor_bd $ANCHOR_PRIORITY_ORDER] _pri_type _pri_slr
        puts "  ENH#17 ANCHOR-TYPE CONFLICT on $target_mod: $_anchor_per_type_str"
        puts "    priority-pick = $_pri_type -> $_pri_slr ; cell-majority = $best_slr ($best_count/$total_cells)"

        set _migration [expr {$total_cells - $best_count}]
        set _maj_pct   [expr {$total_cells > 0 ? 100.0 * $best_count / $total_cells : 0.0}]

        set _resolve $ANCHOR_CONFLICT_RESOLUTION
        if {$_resolve eq "auto"} {
            if {$_pri_slr ne "" && $_pri_slr ne $best_slr
                && $_migration > $MIGRATION_VETO_THRESHOLD
                && $_maj_pct   > $MIGRATION_VETO_PCT} {
                set _resolve "veto"
            } else {
                set _resolve "priority"
            }
        }

        if {$_resolve eq "veto"} {
            set _veto_msg [format "anchors split across %s {%s}; priority would pick %s -> %s; cell-majority is %s (%.1f%%); migration=%d cells" \
                [join $_anchor_distinct_slrs ","] $_anchor_per_type_str $_pri_type $_pri_slr $best_slr $_maj_pct $_migration]
            dict set anchor_conflict_veto $target_mod $_veto_msg
            puts "    ENH#17 VETO: $_veto_msg"
            incr _enh17_veto_applied
            # leave best_slr untouched; STEP 6 will skip emitting USER_SLR_ASSIGNMENT
        } elseif {$_pri_slr ne "" && $_pri_slr ne $best_slr} {
            puts "    ENH#17 PRIORITY-PICK: switching $best_slr -> $_pri_slr ($_pri_type wins)"
            set best_slr $_pri_slr
            set _idx [string range $_pri_slr 3 end]
            set _ac 0
            set _lvs [get_cells -hierarchical -filter "IS_PRIMITIVE && NAME =~ ${target_mod}/*" -quiet]
            foreach _c [get_property SLR_INDEX $_lvs] { if {$_c eq $_idx} { incr _ac } }
            if {$total_cells > 0} {
                set best_count $_ac
                set minority_count [expr {$total_cells - $_ac}]
                set split_pct [expr {double($minority_count) / $total_cells * 100.0}]
            }
            incr _enh17_priority_picked
        } else {
            puts "    ENH#17: priority-pick agrees with cell-majority - keeping $best_slr"
        }
    }

    # ---- Anchor override: if module connects to PCIE/GT placed in a
    #      specific SLR, prefer that SLR over the cell-majority best_slr.
    # NB: skipped when ENH#17 already vetoed or already priority-picked an
    # anchor in this iteration.
    set _skip_anchor_override [dict exists $anchor_conflict_veto $target_mod]
    set anchor_slr [_anchor_slr_for_module $target_mod]
    if {!$_skip_anchor_override && $anchor_slr ne "" && $anchor_slr ne $best_slr} {
        # ---- ENH#19: PCIe-anchor timing-driven emission ------------------
        # If the only anchor type forcing the override is PCIe (no NoC/HBM/
        # MAC pulling), demand a real cross-SLR setup violation through the
        # module before letting PCIe override cell-majority.
        set _pcie_only 0
        if {$PCIE_ANCHOR_TIMING_DRIVEN && [dict exists $_anchor_bd PCIe]} {
            set _types_present [dict keys $_anchor_bd]
            set _strong {NoC HBM MAC}
            set _has_strong 0
            foreach _t $_strong { if {[lsearch -exact $_types_present $_t] >= 0} { set _has_strong 1; break } }
            if {!$_has_strong} { set _pcie_only 1 }
        }
        set _do_override 1
        if {$_pcie_only} {
            puts "  ENH#19: PCIe-only anchor override candidate on $target_mod ($best_slr -> $anchor_slr)"
            puts "         Checking for cross-SLR setup violation through module..."
            if {[_module_has_cross_slr_violation $target_mod]} {
                puts "         Cross-SLR violation FOUND - keeping PCIe override"
            } else {
                puts "         No cross-SLR violation - SKIPPING PCIe-driven override (letting cell-majority $best_slr stand)"
                set _do_override 0
                incr _enh19_pcie_timing_skipped
            }
        }
        if {$_do_override} {
            puts "  ANCHOR OVERRIDE: $target_mod connects to PCIE/GT placed in $anchor_slr"
            puts "                   (was majority=$best_slr, switching to anchor=$anchor_slr)"
            set best_slr $anchor_slr
            # Recompute minority/split with respect to the anchor SLR
            set anchor_idx [string range $anchor_slr 3 end]
            set anchor_cells 0
            set leaves [get_cells -hierarchical -filter "IS_PRIMITIVE && NAME =~ ${target_mod}/*" -quiet]
            foreach c [get_property SLR_INDEX $leaves] {
                if {$c eq $anchor_idx} { incr anchor_cells }
            }
            if {$total_cells > 0} {
                set best_count    $anchor_cells
                set minority_count [expr {$total_cells - $anchor_cells}]
                set split_pct      [expr {double($minority_count) / $total_cells * 100.0}]
            }
        }
    }

    lappend rpt_lines [list $target_mod $target_crossings $orig_mod $orig_crossings \
        $total_cells $best_slr $best_count $minority_count $split_pct $reason $dist_str]
}

###############################################################################
# STEP 6: Pblock-aware filtering and XDC generation (USER_SLR_ASSIGNMENT ONLY)
###############################################################################
puts "\n========================================================================="
puts " STEP 6: Pblock-Aware SLR Assignment (checking uphill/downhill cones)"
puts "=========================================================================\n"

# ---- Quick check: does the design have ANY pblocks at all? ----
set all_pblocks [get_pblocks -quiet *]
set design_has_pblocks [expr {[llength $all_pblocks] > 0}]

if {$design_has_pblocks} {
    puts "  Design has [llength $all_pblocks] pblock(s): $all_pblocks"
    puts "  Will check each candidate module's upstream/downstream cone.\n"
} else {
    puts "  Design has NO pblocks - all modules eligible for SLR assignment.\n"
}

set xdc_fp [open $OUTPUT_XDC w]
puts $xdc_fp "################################################################################"
puts $xdc_fp "# Pblock-Aware USER_SLR_ASSIGNMENT Constraints (SLR ONLY - No CELL_BLOAT_FACTOR)"
puts $xdc_fp "# Generated by: auto_suggest_slr_pblock_aware.tcl"
puts $xdc_fp "# Source report: $SLR_RPT"
puts $xdc_fp "# Crossing threshold: >= $CROSSING_THRESHOLD"
puts $xdc_fp "# Dominance threshold: >= ${DOMINANCE_PCT}%"
puts $xdc_fp "#"
puts $xdc_fp "# Modules with pblocks in upstream/downstream cone are SKIPPED."
puts $xdc_fp "#"
puts $xdc_fp "# Apply AFTER opt_design and BEFORE place_design:"
puts $xdc_fp "#   source $OUTPUT_XDC"
puts $xdc_fp "################################################################################"
puts $xdc_fp ""

# ---- DT/MD informational block (inform-only; no removal commands) -----------
if {[info exists _dt_md_status] && $_dt_md_status eq "REMOVAL_CONTINUE"} {
    puts $xdc_fp "################################################################################"
    puts $xdc_fp "# INFO: This design has DONT_TOUCH / MARK_DEBUG properties on SLR-crossing"
    puts $xdc_fp "#       nets or drivers. These properties block replication and pin placement,"
    puts $xdc_fp "#       which can hurt SLR-crossing timing. SLR partition suggestions are"
    puts $xdc_fp "#       still applied below; this header is INFORMATIONAL ONLY and does NOT"
    puts $xdc_fp "#       remove any DONT_TOUCH / MARK_DEBUG properties."
    puts $xdc_fp "#"
    puts $xdc_fp "#  Cross-SLR DT/MD counts:"
    puts $xdc_fp "#    DONT_TOUCH nets  (cross-SLR): $_dt_net_count"
    puts $xdc_fp "#    MARK_DEBUG nets  (cross-SLR): $_md_net_count"
    puts $xdc_fp "#    DONT_TOUCH cells (cross-SLR): $_dt_cell_count"
    puts $xdc_fp "#    MARK_DEBUG cells (cross-SLR): $_md_cell_count"
    puts $xdc_fp "#"
    puts $xdc_fp "#  Total DT/MD in design (any net/cell):"
    puts $xdc_fp "#    DONT_TOUCH cells : $_all_dt_cell_count"
    puts $xdc_fp "#    MARK_DEBUG cells : $_all_md_cell_count"
    puts $xdc_fp "#    DONT_TOUCH nets  : $_all_dt_net_count"
    puts $xdc_fp "#    MARK_DEBUG nets  : $_all_md_net_count"
    puts $xdc_fp "#"
    puts $xdc_fp "#  Offenders on SLR-crossing paths:"
    foreach _o $_slr_cross_dt_nets  { puts $xdc_fp "#    DT_NET  (cross-SLR): $_o" }
    foreach _o $_slr_cross_md_nets  { puts $xdc_fp "#    MD_NET  (cross-SLR): $_o" }
    foreach _o $_slr_cross_dt_cells { puts $xdc_fp "#    DT_CELL (cross-SLR): $_o" }
    foreach _o $_slr_cross_md_cells { puts $xdc_fp "#    MD_CELL (cross-SLR): $_o" }
    puts $xdc_fp "################################################################################"
    puts $xdc_fp ""
} elseif {[info exists _dt_md_status] && $_dt_md_status eq "REMOVAL_ONLY"} {
    puts $xdc_fp "# INFO: DONT_TOUCH / MARK_DEBUG present in design but NOT on SLR crossings."
    puts $xdc_fp ""
}


set rpt_fp [open $OUTPUT_RPT w]
puts $rpt_fp "================================================================================"
puts $rpt_fp " Pblock-Aware SLR Assignment Analysis Report"
puts $rpt_fp " Generated by: auto_suggest_slr_pblock_aware.tcl"
puts $rpt_fp " Source report: $SLR_RPT"
puts $rpt_fp " Crossing threshold: >= $CROSSING_THRESHOLD"
puts $rpt_fp " Dominance threshold: >= ${DOMINANCE_PCT}%"
puts $rpt_fp "================================================================================"
puts $rpt_fp ""

puts [format "  %-55s %8s %8s %8s %8s  %s" \
    "Target Module" "XCount" "Cells" "Assign" "Pblock?" "Status"]
puts "  [string repeat - 120]"

set suggestion_count 0
set skipped_count    0
set assigned_slr_map [dict create]
# ENH#10: track total_cells per assigned module so the parent-child collapse
# pass can pick the larger entry when a chain conflict appears.
set assigned_cells_map [dict create]
# ENH#18: cumulative LUT cells assigned per SLR (running tally)
set assigned_lut_per_slr [dict create]
# ENH#9/#10/#11/#12/#14/#15/#17/#18 telemetry
set _enh9_size_cap_skipped       0
set _enh10_ancestor_skipped      0
set _enh10_descendants_revoked   0
set _enh10_parent_skipped        0
set _enh11_crossing1_filtered    0
set _enh12_noc_split_skipped     0
set _enh14_strict_pipeline_filtered 0
set _enh15_same_slr_skipped      0
set _enh17_veto_skipped          0
set _enh18_overflow_skipped      0
set _enh18_overflow_fallback     0
set _fix1_gt_split_neighbor_skipped 0
set _fix2_majority_crossing_skipped 0
# HTML diagram tracking: per-module record
# [mname action slr crossings cells minority majpct dist reason source parent]
set _diag_modules    [list]
set _diag_connections [list]

foreach rinfo $rpt_lines {
    lassign $rinfo target_mod target_crossings orig_mod orig_crossings \
        total_cells best_slr best_count minority_count split_pct reason

    set dist_str ""
    if {[llength $rinfo] > 10} {
        set dist_str [lindex $rinfo 10]
    }

    puts $rpt_fp [format "%-65s" $target_mod]
    puts $rpt_fp "  Original L1 module : $orig_mod ($orig_crossings crossings)"
    puts $rpt_fp "  Target crossings   : $target_crossings"
    puts $rpt_fp "  Drill-down reason  : $reason"

    if {$total_cells == 0} {
        puts [format "  %-55s %8d %8s %8s %8s  SKIP (no cells)" \
            $target_mod $target_crossings "N/A" "-" "-"]
        puts $rpt_fp "  >> SKIPPED: No cells found"
        puts $rpt_fp ""
        lappend _diag_modules [list $target_mod skip "" $target_crossings 0 0 0.0 "" "No cells found" step6 ""]
        incr skipped_count
        continue
    }

    if {$best_slr eq ""} {
        puts [format "  %-55s %8d %8d %8s %8s  SKIP (all unplaced)" \
            $target_mod $target_crossings $total_cells "-" "-"]
        puts $rpt_fp "  >> SKIPPED: All cells unplaced - no SLR determined"
        puts $rpt_fp ""
        lappend _diag_modules [list $target_mod skip "" $target_crossings $total_cells 0 0.0 $dist_str "All cells unplaced" step6 ""]
        incr skipped_count
        continue
    }

    puts $rpt_fp "  Total cells        : $total_cells"
    puts $rpt_fp "  Cell distribution  : $dist_str"
    puts $rpt_fp "  Best SLR           : $best_slr ($best_count cells, [format %.1f [expr {100.0 - $split_pct}]]%)"
    puts $rpt_fp "  Split percentage   : [format %.1f $split_pct]%"

    # ---- ENH#17: ANCHOR-TYPE CONFLICT VETO ----------------------------------
    # STEP 5 set anchor_conflict_veto for modules with anchors split across
    # SLRs (e.g. axi_top with NoC in SLR0 and PCIe/PS in SLR1). Honor that
    # veto here by skipping the USER_SLR_ASSIGNMENT emission entirely. STEP 7
    # net-level USER_CROSSING_SLR 0 anchors will still handle the crossings.
    if {[dict exists $anchor_conflict_veto $target_mod]} {
        set _vmsg [dict get $anchor_conflict_veto $target_mod]
        puts "    ** ENH#17 ANCHOR-CONFLICT VETO: $_vmsg"
        puts "    ** SKIPPING USER_SLR_ASSIGNMENT - placer will resolve naturally"
        puts [format "  %-55s %8d %8d %8s %8s  SKIP (ENH#17 anchor-conflict veto)" \
            $target_mod $target_crossings $total_cells $best_slr "-"]
        puts $rpt_fp "  >> SKIPPED: ENH#17 anchor-type conflict veto"
        puts $rpt_fp "  Detail             : $_vmsg"
        puts $rpt_fp ""
        puts $xdc_fp "# SKIPPED: $target_mod"
        puts $xdc_fp "#   Reason: ENH#17 anchor-type conflict veto - $_vmsg"
        puts $xdc_fp "#   STEP 7 net-level USER_CROSSING_SLR 0 will still handle anchor nets"
        puts $xdc_fp ""
        lappend _diag_modules [list $target_mod skip $best_slr $target_crossings $total_cells $minority_count [expr {100.0 - $split_pct}] $dist_str "ENH#17 anchor-conflict veto: $_vmsg" step6 ""]
        incr _enh17_veto_skipped
        incr skipped_count
        continue
    }

    # ---- PBLOCK CONFLICT CHECK ----
    set pblock_status "CLEAN"
    if {$design_has_pblocks} {
        puts "    Checking pblock cone for: $target_mod ..."
        set pb_result [check_pblock_conflict $target_mod]
        set has_conflict [dict get $pb_result has_conflict]
        set conflict_reason [dict get $pb_result reason]

        if {$has_conflict} {
            set pblock_status "CONFLICT"
            puts "    ** PBLOCK CONFLICT: $conflict_reason"
            puts "    ** SKIPPING SLR assignment for this module"

            puts [format "  %-55s %8d %8d %8s %8s  SKIP (pblock: %s)" \
                $target_mod $target_crossings $total_cells $best_slr "YES" $conflict_reason]

            puts $rpt_fp "  Pblock check       : CONFLICT"
            puts $rpt_fp "  Conflict detail    : $conflict_reason"

            set up_pbs [dict get $pb_result upstream_pblocks]
            set dn_pbs [dict get $pb_result downstream_pblocks]
            set mod_pb [dict get $pb_result module_pblock]
            if {$mod_pb ne ""} {
                puts $rpt_fp "    Module pblock    : $mod_pb"
            }
            if {[llength $up_pbs] > 0} {
                puts $rpt_fp "    Upstream pblocks : [join $up_pbs {, }]"
            }
            if {[llength $dn_pbs] > 0} {
                puts $rpt_fp "    Downstream pblocks: [join $dn_pbs {, }]"
            }

            puts $rpt_fp "  >> SKIPPED: Pblock conflict in uphill/downhill cone"
            puts $rpt_fp ""

            puts $xdc_fp "# SKIPPED: $target_mod"
            puts $xdc_fp "#   Reason: $conflict_reason"
            puts $xdc_fp "#   Would assign: $best_slr (crossings: $target_crossings, cells: $total_cells)"
            puts $xdc_fp ""


            lappend _diag_modules [list $target_mod skip $best_slr $target_crossings $total_cells $minority_count [expr {100.0 - $split_pct}] $dist_str "Pblock conflict: $conflict_reason" step6 ""]
            incr skipped_count
            continue
        } else {
            puts "    No pblock conflicts found - eligible for SLR assignment"
        }
    }

    # ---- ENH#8: GT-SPLIT ANCESTOR CHECK -------------------------------------
    # If any ancestor of $target_mod was skipped because it contains GT
    # primitives spanning multiple SLRs (e.g. matrix_io_top/mio_xcvr_top with
    # GTs in SLR0 AND SLR1), this child shares the GT-sourced clock(s) and
    # must NOT be pinned to a single SLR. Pinning it forces 1000s of endpoints
    # of a GT-sourced clock (e.g. rxusrclk_out) into one SLR, blowing clock
    # skew and regressing WNS/TNS even when the cross-SLR violation is gone.
    # STEP 7 net-level USER_CROSSING_SLR will still handle the crossings.
    if {$pblock_status eq "CLEAN" && ![_module_contains_gt $target_mod]} {
        set _split_anc [_ancestor_with_split_gt $target_mod]
        if {[llength $_split_anc] > 0} {
            lassign $_split_anc _anc_mod _anc_gt _anc_slrs _anc_per
            set pblock_status "GT_SPLIT_ANCESTOR"
            set _msg "ancestor $_anc_mod has $_anc_gt GTs split across [llength $_anc_slrs] SLRs ($_anc_per) - assigning child to one SLR would cripple GT clock skew"
            puts "    ** GT-SPLIT ANCESTOR SKIP (ENH#8): $_msg"
            puts "    ** SKIPPING SLR assignment - STEP 7 will handle anchor nets"

            puts [format "  %-55s %8d %8d %8s %8s  SKIP (GT-split ancestor: %s)" \
                $target_mod $target_crossings $total_cells $best_slr "-" $_anc_mod]
            puts $rpt_fp "  GT-split ancestor  : $_anc_mod ($_anc_gt GTs in [llength $_anc_slrs] SLRs: $_anc_per)"
            puts $rpt_fp "  >> SKIPPED: $_msg"
            puts $rpt_fp ""

            puts $xdc_fp "# SKIPPED: $target_mod"
            puts $xdc_fp "#   Reason: GT-split ancestor $_anc_mod ($_anc_per) - child shares GT-sourced clock"
            puts $xdc_fp "#   Would assign: $best_slr (crossings: $target_crossings, cells: $total_cells)"
            puts $xdc_fp "#   Pinning to one SLR would cripple clock skew on the GT user clock"
            puts $xdc_fp "#   Will be handled by STEP 7 anchor net-level USER_CROSSING_SLR 0"
            puts $xdc_fp ""
            lappend _diag_modules [list $target_mod skip $best_slr $target_crossings $total_cells $minority_count [expr {100.0 - $split_pct}] $dist_str "ENH#8 GT-split ancestor: $_anc_mod ($_anc_per)" step6 ""]
            incr skipped_count
            continue
        }
    }

    # ---- ENH#12: NoC-SPLIT ANCESTOR CHECK -----------------------------------
    # NoC NMU/NSU/NPS primitives are fixed-location silicon nodes (like GTs).
    # If $target_mod (or any ancestor) contains NoC anchors spanning multiple
    # SLRs, pinning to one SLR pulls soft AXI/NoC logic away from the fixed
    # NMU/NSU in the other SLR -> forces cross-SLR routing on the entire
    # AXI/NoC interface. (Teradyne_Util42: axi_top had S00/01/02 NMU in SLR0
    # and S03_AXI_nmu in SLR1; pinning axi_top -> SLR0 because 94.9% of soft
    # cells were in SLR0 orphaned S03 and blew TNS from -100 ns to -19500 ns.)
    # STEP 7 net-level USER_CROSSING_SLR will still handle the crossings.
    if {$NOC_SPLIT_ANCESTOR_GUARD && $pblock_status eq "CLEAN"} {
        set _noc_anc [_ancestor_with_split_noc $target_mod]
        if {[llength $_noc_anc] > 0} {
            lassign $_noc_anc _nanc_mod _nanc_cnt _nanc_slrs _nanc_per
            set pblock_status "NOC_SPLIT_ANCESTOR"
            if {$_nanc_mod eq $target_mod} {
                set _msg "this module has $_nanc_cnt NoC NMU/NSU/NPS primitives split across [llength $_nanc_slrs] SLRs ($_nanc_per) - assigning to one SLR would orphan the fixed NoC anchor(s) in the other SLR(s)"
            } else {
                set _msg "ancestor $_nanc_mod has $_nanc_cnt NoC NMU/NSU/NPS primitives split across [llength $_nanc_slrs] SLRs ($_nanc_per) - assigning child to one SLR would force cross-SLR routing on the AXI/NoC interface"
            }
            puts "    ** NoC-SPLIT ANCESTOR SKIP (ENH#12): $_msg"
            puts "    ** SKIPPING SLR assignment - STEP 7 will handle anchor nets"

            puts [format "  %-55s %8d %8d %8s %8s  SKIP (NoC-split ancestor: %s)" \
                $target_mod $target_crossings $total_cells $best_slr "-" $_nanc_mod]
            puts $rpt_fp "  NoC-split ancestor : $_nanc_mod ($_nanc_cnt NoC anchors in [llength $_nanc_slrs] SLRs: $_nanc_per)"
            puts $rpt_fp "  >> SKIPPED: $_msg"
            puts $rpt_fp ""

            puts $xdc_fp "# SKIPPED: $target_mod"
            puts $xdc_fp "#   Reason: ENH#12 NoC-split ancestor $_nanc_mod ($_nanc_per) - fixed NoC anchors span SLRs"
            puts $xdc_fp "#   Would assign: $best_slr (crossings: $target_crossings, cells: $total_cells)"
            puts $xdc_fp "#   Pinning would orphan NMU/NSU in non-target SLR -> forced AXI/NoC SLR crossings"
            puts $xdc_fp "#   Will be handled by STEP 7 anchor net-level USER_CROSSING_SLR 0"
            puts $xdc_fp ""
            lappend _diag_modules [list $target_mod skip $best_slr $target_crossings $total_cells $minority_count [expr {100.0 - $split_pct}] $dist_str "ENH#12 NoC-split ancestor: $_nanc_mod ($_nanc_per)" step6 ""]
            incr skipped_count
            incr _enh12_noc_split_skipped
            continue
        }
    }

    # ---- GT/XCVR MODULE CHECK (Spec 5c.7 + ENH#7) ----
    # GT primitives are fixed-location and cannot be moved via
    # USER_SLR_ASSIGNMENT. BUT a hierarchical cell that *contains* GT(s)
    # CAN still take USER_SLR_ASSIGNMENT - the GTs themselves stay put
    # (Vivado obeys their site constraint), and the surrounding logic gets
    # steered toward the GT's SLR. This is usually exactly what we want.
    #
    # ENH#7 decision tree (when GT_INSIDE_MODULE_ASSIGN=1):
    #   inside_gt_slr  | boundary anchor_slr      | action
    #   --------------------------------------------------------------
    #   <none>         | (n/a)                    | normal flow (no GT)
    #   <multi-SLR>    | (n/a)                    | SKIP (ambiguous)
    #   SLRx           | <none>                   | ASSIGN to SLRx (ENH#7-A)
    #   SLRx           | SLRx (same)              | ASSIGN to SLRx (ENH#7-B)
    #   SLRx           | SLRy (different)         | SKIP (conflict, ENH#7-C)
    if {$pblock_status eq "CLEAN" && [_module_contains_gt $target_mod]} {
        if {$GT_INSIDE_MODULE_ASSIGN} {
            set _inside_gt [_inside_gt_slr $target_mod]
            set _boundary_anchor [_anchor_slr_for_module $target_mod]

            if {$_inside_gt eq ""} {
                # Multi-SLR or unresolved -> legacy skip with detailed breakdown
                set _gtb [_inside_gt_breakdown $target_mod]
                set _gt_count [dict get $_gtb gt_count]
                set _gt_slrs  [dict get $_gtb slrs]
                set _gt_per   [dict get $_gtb per_slr]
                set _per_str ""
                dict for {_sk _sv} $_gt_per {
                    if {$_per_str ne ""} { append _per_str ", " }
                    append _per_str "$_sk=$_sv"
                }
                set pblock_status "GT_FIXED"
                if {[llength $_gt_slrs] > 1} {
                    set _msg "found $_gt_count GTs in different SLRs ([llength $_gt_slrs] SLRs: $_gt_slrs; counts: $_per_str)"
                } else {
                    set _msg "found $_gt_count GTs but SLR_INDEX unresolved"
                }
                puts "    ** GT/XCVR MULTI-SLR SKIP (ENH#7): $_msg"
                puts "    ** SKIPPING SLR assignment - STEP 7 will handle anchor nets"

                puts [format "  %-55s %8d %8d %8s %8s  SKIP (%s)" \
                    $target_mod $target_crossings $total_cells $best_slr "-" \
                    "GTs in [llength $_gt_slrs] SLRs"]
                puts $rpt_fp "  GT/XCVR check      : MULTI-SLR GTs INSIDE - $_msg"
                puts $rpt_fp "  >> SKIPPED: $_msg"
                puts $rpt_fp ""

                puts $xdc_fp "# SKIPPED: $target_mod"
                puts $xdc_fp "#   Reason: $_msg"
                puts $xdc_fp "#   Will be handled by STEP 7 anchor net-level USER_CROSSING_SLR 0"
                puts $xdc_fp ""
                lappend _diag_modules [list $target_mod skip $best_slr $target_crossings $total_cells $minority_count [expr {100.0 - $split_pct}] $dist_str "ENH#7 multi-SLR GTs: $_msg" step6 ""]
                incr skipped_count
                continue
            }

            if {$_boundary_anchor ne "" && $_boundary_anchor ne $_inside_gt} {
                # CONFLICT - inside GT says X, boundary anchor says Y -> skip
                set pblock_status "GT_CONFLICT"
                puts "    ** GT CONFLICT (ENH#7-C): inside GT in $_inside_gt, boundary anchor in $_boundary_anchor"
                puts "    ** SKIPPING SLR assignment - STEP 7 will handle anchor nets"

                puts [format "  %-55s %8d %8d %8s %8s  SKIP (GT conflict %s vs %s)" \
                    $target_mod $target_crossings $total_cells $best_slr "-" $_inside_gt $_boundary_anchor]
                puts $rpt_fp "  GT/XCVR check      : CONFLICT inside=$_inside_gt boundary=$_boundary_anchor"
                puts $rpt_fp "  >> SKIPPED: inside-GT vs boundary anchor disagree"
                puts $rpt_fp ""

                puts $xdc_fp "# SKIPPED: $target_mod"
                puts $xdc_fp "#   Reason: GT conflict (inside GT=$_inside_gt, boundary anchor=$_boundary_anchor)"
                puts $xdc_fp "#   Will be handled by STEP 7 anchor net-level USER_CROSSING_SLR 0"
                puts $xdc_fp ""
                lappend _diag_modules [list $target_mod skip $best_slr $target_crossings $total_cells $minority_count [expr {100.0 - $split_pct}] $dist_str "GT conflict inside=$_inside_gt boundary=$_boundary_anchor (ENH#7-C)" step6 ""]
                incr skipped_count
                continue
            }

            # ENH#7-A or ENH#7-B: assign to inside-GT SLR
            if {$_boundary_anchor eq ""} {
                set _tag "ENH#7-A (no boundary anchor)"
            } else {
                set _tag "ENH#7-B (boundary anchor agrees: $_boundary_anchor)"
            }
            puts "    ** GT INSIDE (ENH#7): assigning $target_mod to inside-GT SLR $_inside_gt  ($_tag)"
            puts $rpt_fp "  GT/XCVR check      : ASSIGN to inside-GT SLR $_inside_gt  ($_tag)"
            set best_slr $_inside_gt
            # fall through to normal write-assignment path below
        } else {
            # Legacy behaviour - always skip GT-containing modules
            set pblock_status "GT_FIXED"
            puts "    ** GT/XCVR FIXED (legacy): Module contains GT/XCVR fixed-location primitives"
            puts "    ** SKIPPING SLR assignment - will be handled via net-level constraints"

            puts [format "  %-55s %8d %8d %8s %8s  SKIP (GT/XCVR fixed-location)" \
                $target_mod $target_crossings $total_cells $best_slr "-"]
            puts $rpt_fp "  GT/XCVR check      : CONTAINS FIXED-LOCATION PRIMITIVES"
            puts $rpt_fp "  >> SKIPPED: Module contains GT/XCVR primitives (legacy, GT_INSIDE_MODULE_ASSIGN=0)"
            puts $rpt_fp ""

            puts $xdc_fp "# SKIPPED: $target_mod"
            puts $xdc_fp "#   Reason: contains GT/XCVR fixed-location primitives (legacy skip)"
            puts $xdc_fp "#   Would assign: $best_slr (crossings: $target_crossings, cells: $total_cells)"
            puts $xdc_fp "#   Will be handled by STEP 7 anchor net-level USER_CROSSING_SLR 0"
            puts $xdc_fp ""
            lappend _diag_modules [list $target_mod skip $best_slr $target_crossings $total_cells $minority_count [expr {100.0 - $split_pct}] $dist_str "Contains GT/XCVR fixed-location primitives (legacy)" step6 ""]
            incr skipped_count
            continue
        }
    }

    # ---- ENH#9: SUBTREE-SIZE CAP ----------------------------------------
    #      Refuse to pin a hierarchy whose total cell count would exceed
    #      MAX_CELL_PCT_OF_SLR%% of the target SLR's LUT capacity. Pinning
    #      ~520k cells (Util54 apg_top/ps) chokes placer spill and triples
    #      congestion. Disabled if MAX_CELL_PCT_OF_SLR <= 0.
    if {$MAX_CELL_PCT_OF_SLR > 0 && $total_cells > 0} {
        set _slr_caps [_get_slr_lut_capacity]
        if {[dict exists $_slr_caps $best_slr]} {
            set _cap [dict get $_slr_caps $best_slr]
            if {$_cap > 0} {
                set _pct [expr {100.0 * $total_cells / $_cap}]
                if {$_pct > $MAX_CELL_PCT_OF_SLR} {
                    set _msg [format "subtree has %d cells = %.1f%% of %s LUT capacity (%d), exceeds %.1f%% cap - pinning would block placer spill" \
                        $total_cells $_pct $best_slr $_cap $MAX_CELL_PCT_OF_SLR]
                    puts "    ** ENH#9 SUBTREE-SIZE SKIP: $_msg"
                    puts [format "  %-55s %8d %8d %8s %8s  SKIP (ENH#9 subtree-size %s=%.1f%%)" \
                        $target_mod $target_crossings $total_cells $best_slr "-" $best_slr $_pct]
                    puts $xdc_fp "# SKIPPED: $target_mod"
                    puts $xdc_fp "#   Reason: ENH#9 subtree-size-cap - $_msg"
                    puts $xdc_fp "#   Would assign: $best_slr (crossings: $target_crossings, cells: $total_cells)"
                    puts $xdc_fp "#   Cross-SLR endpoints will be handled by STEP 7 net-level USER_CROSSING_SLR 0"
                    puts $xdc_fp ""
                    puts $rpt_fp "  >> SKIPPED: ENH#9 $_msg"
                    puts $rpt_fp ""
                    lappend _diag_modules [list $target_mod skip $best_slr $target_crossings $total_cells $minority_count [expr {100.0 - $split_pct}] $dist_str "ENH#9 subtree-size-cap: $_msg" step6 ""]
                    incr skipped_count
                    incr _enh9_size_cap_skipped
                    continue
                }
            }
        }
    }

    # ---- ENH#10: PARENT-CHILD COLLAPSE ---------------------------------
    #      If any ancestor of this target is already assigned, skip the child
    #      (parent already covers the descendants). If any descendants are
    #      already assigned with a LARGER summed cell count, skip this
    #      parent. Otherwise, if this parent has more cells than the sum of
    #      already-assigned descendants, revoke the descendants and continue
    #      to assign this parent.
    if {$COLLAPSE_PARENT_CHILD} {
        set _anc [_ancestor_in_map $target_mod $assigned_slr_map]
        if {$_anc ne ""} {
            set _anc_slr [dict get $assigned_slr_map $_anc]
            set _msg "ancestor $_anc already assigned to $_anc_slr - parent covers this child"
            puts "    ** ENH#10 COLLAPSE SKIP: $_msg"
            puts [format "  %-55s %8d %8d %8s %8s  SKIP (ENH#10 ancestor=%s)" \
                $target_mod $target_crossings $total_cells $best_slr "-" $_anc]
            puts $xdc_fp "# SKIPPED: $target_mod"
            puts $xdc_fp "#   Reason: ENH#10 parent-child collapse - $_msg"
            puts $xdc_fp ""
            puts $rpt_fp "  >> SKIPPED: ENH#10 $_msg"
            puts $rpt_fp ""
            lappend _diag_modules [list $target_mod skip $best_slr $target_crossings $total_cells $minority_count [expr {100.0 - $split_pct}] $dist_str "ENH#10 ancestor-already-assigned: $_anc ($_anc_slr)" step6 ""]
            incr skipped_count
            incr _enh10_ancestor_skipped
            continue
        }
        set _descs [_descendants_in_map $target_mod $assigned_slr_map]
        if {[llength $_descs] > 0} {
            set _desc_total 0
            foreach _d $_descs {
                if {[dict exists $assigned_cells_map $_d]} {
                    incr _desc_total [dict get $assigned_cells_map $_d]
                }
            }
            if {$total_cells > $_desc_total} {
                puts "    ** ENH#10 COLLAPSE: parent $target_mod ($total_cells cells) > [llength $_descs] descendants ($_desc_total cells); revoking children"
                puts $xdc_fp "# ENH#10 COLLAPSE: revoking [llength $_descs] descendant assignment(s) ($_desc_total cells) in favor of larger parent $target_mod ($total_cells cells)"
                foreach _d $_descs {
                    set _d_slr [dict get $assigned_slr_map $_d]
                    puts $xdc_fp "# ENH#10 revoke: $_d (was assigned to $_d_slr)"
                    puts $xdc_fp "catch { reset_property USER_SLR_ASSIGNMENT \[get_cells \{$_d\}\] }"
                    lappend command "reset_property USER_SLR_ASSIGNMENT \[get_cells \{$_d\}\]"
                    set assigned_slr_map   [dict remove $assigned_slr_map   $_d]
                    set assigned_cells_map [dict remove $assigned_cells_map $_d]
                    lappend _diag_modules [list $_d revoke $_d_slr 0 0 0 0.0 "" "ENH#10 revoked in favor of larger parent $target_mod" step6 ""]
                    incr _enh10_descendants_revoked
                }
                puts $xdc_fp ""
            } else {
                set _msg "[llength $_descs] descendant(s) already assigned with larger total ($_desc_total cells > parent $total_cells cells); skipping parent"
                puts "    ** ENH#10 COLLAPSE SKIP: $_msg"
                puts [format "  %-55s %8d %8d %8s %8s  SKIP (ENH#10 desc_total=%d)" \
                    $target_mod $target_crossings $total_cells $best_slr "-" $_desc_total]
                puts $xdc_fp "# SKIPPED: $target_mod"
                puts $xdc_fp "#   Reason: ENH#10 parent-child collapse - $_msg"
                puts $xdc_fp ""
                puts $rpt_fp "  >> SKIPPED: ENH#10 $_msg"
                puts $rpt_fp ""
                lappend _diag_modules [list $target_mod skip $best_slr $target_crossings $total_cells $minority_count [expr {100.0 - $split_pct}] $dist_str "ENH#10 descendants-total-larger: $_desc_total > $total_cells" step6 ""]
                incr skipped_count
                incr _enh10_parent_skipped
                continue
            }
        }
    }

    # ---- ENH#18: CUMULATIVE SLR UTILIZATION CAP -----------------------------
    # Per-module ENH#9 only catches a single oversize module. ENH#18 catches
    # the case where N small modules each fit but together push an SLR past
    # SLR_UTIL_CAP_PCT % of its LUT capacity. When overflow predicted, try the
    # OPPOSITE SLR if cell-majority gap is small (SLR_UTIL_FALLBACK_SPLIT_PCT);
    # otherwise SKIP the module entirely and let the placer decide.
    if {$SLR_UTILIZATION_CAP_CHECK && !$is_mono_device} {
        set _u [_predict_slr_utilization $best_slr $total_cells $SLR_UTIL_CAP_PCT]
        if {![dict get $_u ok] && [dict get $_u cap] > 0} {
            puts [format "    ** ENH#18 UTIL OVERFLOW: %s would reach %.1f%% (cap=%.1f%%, +%d cells)" \
                $best_slr [dict get $_u pct] $SLR_UTIL_CAP_PCT $total_cells]
            set _alt_slr ""
            set _cap_d [_get_slr_lut_capacity]
            foreach _k [dict keys $_cap_d] {
                if {$_k ne $best_slr} { set _alt_slr $_k; break }
            }
            set _alt_ok 0
            if {$_alt_slr ne "" && $split_pct <= $SLR_UTIL_FALLBACK_SPLIT_PCT} {
                set _u2 [_predict_slr_utilization $_alt_slr $total_cells $SLR_UTIL_CAP_PCT]
                if {[dict get $_u2 ok] && [dict get $_u2 cap] > 0} {
                    set _alt_ok 1
                    puts [format "       Fallback to %s (would reach %.1f%%, split=%.1f%% acceptable)" \
                        $_alt_slr [dict get $_u2 pct] $split_pct]
                    set best_slr $_alt_slr
                    set _idx [string range $_alt_slr 3 end]
                    set _ac 0
                    set _lvs [get_cells -hierarchical -filter "IS_PRIMITIVE && NAME =~ ${target_mod}/*" -quiet]
                    foreach _c [get_property SLR_INDEX $_lvs] { if {$_c eq $_idx} { incr _ac } }
                    if {$total_cells > 0} {
                        set best_count $_ac
                        set minority_count [expr {$total_cells - $_ac}]
                        set split_pct [expr {double($minority_count) / $total_cells * 100.0}]
                    }
                    incr _enh18_overflow_fallback
                }
            }
            if {!$_alt_ok} {
                set _msg [format "%s would reach %.1f%% (cap=%.1f%%); split=%.1f%% rules out fallback" \
                    $best_slr [dict get $_u pct] $SLR_UTIL_CAP_PCT $split_pct]
                puts "    ** ENH#18 SKIP (no fallback): $_msg"
                puts [format "  %-55s %8d %8d %8s %8s  SKIP (ENH#18 SLR overflow)" \
                    $target_mod $target_crossings $total_cells $best_slr "-"]
                puts $xdc_fp "# SKIPPED: $target_mod"
                puts $xdc_fp "#   Reason: ENH#18 cumulative SLR utilization cap - $_msg"
                puts $xdc_fp ""
                puts $rpt_fp "  >> SKIPPED: ENH#18 $_msg"
                puts $rpt_fp ""
                lappend _diag_modules [list $target_mod skip $best_slr $target_crossings $total_cells $minority_count [expr {100.0 - $split_pct}] $dist_str "ENH#18 SLR overflow: $_msg" step6 ""]
                incr _enh18_overflow_skipped
                incr skipped_count
                continue
            }
        }
    }

    # ---- WRITE SLR ASSIGNMENT ----
    set from_str ""
    if {$target_mod ne $orig_mod} {
        set from_str "(from $orig_mod)"
    }

    set rationale [format "%.0f%% in %s, consolidate %d cells %s" \
        [expr {100.0 - $split_pct}] $best_slr $minority_count $from_str]

    puts [format "  %-55s %8d %8d %8s %8s  ASSIGN (%s)" \
        $target_mod $target_crossings $total_cells $best_slr "CLEAN" $rationale]

    puts $xdc_fp "# Target: $target_mod"
    if {$target_mod ne $orig_mod} {
        puts $xdc_fp "#   Drilled from: $orig_mod ($orig_crossings crossings)"
    }
    puts $xdc_fp "#   Crossings at this level: $target_crossings"
    puts $xdc_fp "#   Cell distribution: $dist_str"
    puts $xdc_fp "#   Assign to $best_slr ([format %.1f [expr {100.0 - $split_pct}]]% majority, $minority_count cells to move)"
    puts $xdc_fp "#   Pblock check: CLEAN (no conflicts in upstream/downstream)"
    puts $xdc_fp "#   Drill-down: $reason"
    puts $xdc_fp "catch { set_property USER_SLR_ASSIGNMENT $best_slr \[get_cells \{$target_mod\}\] }"
    lappend command "set_property USER_SLR_ASSIGNMENT $best_slr \[get_cells \{$target_mod\}\]"
    puts $xdc_fp ""

    # ----------------------------------------------------------------------
    # ENH#1 (generate-loop sibling consolidation): when target_mod matches a
    # generate-loop instance like 'foo/g_x[0].bar', look for siblings
    # 'foo/g_x[*].bar' (and any sibling whose immediate-parent's parent has
    # the same suffix). Co-assign all siblings to the SAME SLR.
    # ----------------------------------------------------------------------
    if {$GENLOOP_SIBLING_EXPAND && [regexp {^(.*)\[(\d+)\]\.([^/]+)$} $target_mod _ _gprefix _gidx _gsuffix]} {
        set _sib_pat "${_gprefix}\\\[*\\\].${_gsuffix}"
        set _sibs [get_cells -quiet $_sib_pat]
        set _sib_assigned 0
        foreach _sib $_sibs {
            set _sname [get_property NAME $_sib]
            if {$_sname eq $target_mod} continue
            if {[dict exists $assigned_slr_map $_sname]} continue
            # GT check
            if {[_module_contains_gt $_sname]} continue
            # pblock check (only if design has pblocks)
            if {$design_has_pblocks} {
                set _pbr [check_pblock_conflict $_sname]
                if {[dict get $_pbr has_conflict]} continue
            }
            puts $xdc_fp "# ENH#1 sibling co-assign of $target_mod: $_sname -> $best_slr"
            puts $xdc_fp "catch { set_property USER_SLR_ASSIGNMENT $best_slr \[get_cells \{$_sname\}\] }"
            lappend command "set_property USER_SLR_ASSIGNMENT $best_slr \[get_cells \{$_sname\}\]"
            puts $xdc_fp ""
            dict set assigned_slr_map   $_sname $best_slr
            # ENH#10: track cells for parent-child collapse (sibling shares the
            # generate-loop parent's cell count budget - approximate by parent's
            # total_cells; better than 0 which would lose collapse decisions).
            dict set assigned_cells_map $_sname $total_cells
            # ENH#18: update cumulative LUT tally for sibling on same SLR.
            if {[dict exists $assigned_lut_per_slr $best_slr]} {
                dict set assigned_lut_per_slr $best_slr [expr {[dict get $assigned_lut_per_slr $best_slr] + $total_cells}]
            } else {
                dict set assigned_lut_per_slr $best_slr $total_cells
            }
            lappend _diag_modules [list $_sname assign $best_slr 0 0 0 0.0 "sibling-of(${target_mod})" "ENH#1 generate-loop sibling consolidation" step6 ""]
            incr _sib_assigned
        }
        if {$_sib_assigned > 0} {
            puts "  ENH#1: co-assigned $_sib_assigned generate-loop sibling(s) of $target_mod to $best_slr"
            puts $rpt_fp "  ENH#1: $_sib_assigned sibling(s) co-assigned to $best_slr"
        }
    }

    # ---- WRITE PBLOCK CONSTRAINT (parallel to USER_SLR_ASSIGNMENT) ----
    if {$target_mod ne $orig_mod} {
    }

    puts $rpt_fp "  Pblock check       : CLEAN"
    puts $rpt_fp "  >> ASSIGNED: set_property USER_SLR_ASSIGNMENT $best_slr \[get_cells \{$target_mod\}\]"
    puts $rpt_fp ""

    dict set assigned_slr_map   $target_mod $best_slr
    dict set assigned_cells_map $target_mod $total_cells
    # ENH#18: update cumulative LUT tally for this SLR
    if {[dict exists $assigned_lut_per_slr $best_slr]} {
        dict set assigned_lut_per_slr $best_slr [expr {[dict get $assigned_lut_per_slr $best_slr] + $total_cells}]
    } else {
        dict set assigned_lut_per_slr $best_slr $total_cells
    }
    lappend _diag_modules [list $target_mod assign $best_slr $target_crossings $total_cells $minority_count [expr {100.0 - $split_pct}] $dist_str $rationale step6 ""]
    incr suggestion_count
}

close $xdc_fp
close $rpt_fp

# ---- ENH#9/#10/#11/#12 SUMMARY (STEP 6) ---------------------------------
puts ""
puts "  ----- ENH#9/#10/#11/#12/#17/#18/#19 STEP 6 telemetry -----"
puts [format "    ENH#9  subtree-size-cap skipped     : %d (cap=%.1f%% of SLR LUT capacity)"  $_enh9_size_cap_skipped     $MAX_CELL_PCT_OF_SLR]
puts [format "    ENH#10 ancestor-already-assigned    : %d"                                  $_enh10_ancestor_skipped]
puts [format "    ENH#10 parent-skipped (desc bigger) : %d"                                  $_enh10_parent_skipped]
puts [format "    ENH#10 descendants revoked          : %d"                                  $_enh10_descendants_revoked]
puts [format "    ENH#12 NoC-split-ancestor skipped   : %d (NoC NMU/NSU/NPS span >=2 SLRs)"   $_enh12_noc_split_skipped]
puts [format "    ENH#17 anchor-type conflicts found  : %d"                                  $_enh17_conflict_detected]
puts [format "    ENH#17 priority-picked (anchor wins): %d"                                  $_enh17_priority_picked]
puts [format "    ENH#17 vetoed (skipped USER_SLR)    : %d (mode=%s, threshold=%d cells/%.1f%%)" \
    $_enh17_veto_skipped $ANCHOR_CONFLICT_RESOLUTION $MIGRATION_VETO_THRESHOLD $MIGRATION_VETO_PCT]
puts [format "    ENH#18 cumulative SLR overflow skip : %d (cap=%.1f%% of SLR LUT capacity)" \
    $_enh18_overflow_skipped $SLR_UTIL_CAP_PCT]
puts [format "    ENH#18 fallback-to-other-SLR        : %d (split<=%.1f%%)" \
    $_enh18_overflow_fallback $SLR_UTIL_FALLBACK_SPLIT_PCT]
puts [format "    ENH#19 PCIe-anchor timing-skipped   : %d (PCIe override needed cross-SLR violation, none found)" \
    $_enh19_pcie_timing_skipped]
# Final cumulative LUT load per SLR snapshot
if {[dict size $assigned_lut_per_slr] > 0} {
    set _cap_d [_get_slr_lut_capacity]
    puts "    ----- Cumulative LUT load per SLR (ENH#18) -----"
    foreach _s [lsort [dict keys $assigned_lut_per_slr]] {
        set _used [dict get $assigned_lut_per_slr $_s]
        set _cap 0
        if {[dict exists $_cap_d $_s]} { set _cap [dict get $_cap_d $_s] }
        set _pct 0.0
        if {$_cap > 0} { set _pct [expr {100.0 * $_used / $_cap}] }
        puts [format "      %s : %10d cells assigned  (cap=%d, %.1f%% of capacity)" $_s $_used $_cap $_pct]
    }
}
puts "  -----------------------------------------------------------"

###############################################################################
# STEP 6b: Connectivity-Aware Neighbor Pull-in & Pipeline Register Detection
#
# For each module assigned in STEP 6, traces boundary connections to find
# heavily-connected neighbor modules:
#
#   1. If the path between the assigned module and neighbor goes through
#      pipeline registers (staging flops outside both modules), those
#      registers are assigned to facilitate clean SLR crossing.
#
#   2. If no pipeline registers are found on the path, the neighbor
#      module is co-assigned to the same SLR (if its cell majority agrees
#      and there are no pblock conflicts).
###############################################################################

puts "\n========================================================================="
puts " STEP 6b: Connectivity-Aware Neighbor Pull-in & Pipeline Detection"
puts " Neighbor connection threshold : >= $NEIGHBOR_CONN_THRESH"
puts " Max split for co-assignment   : <= ${NEIGHBOR_MAX_SPLIT}%"
puts " Max net fanout to trace       : $NEIGHBOR_MAX_FANOUT"
puts "=========================================================================\n"

set neighbor_suggestion_count 0
set pipeline_reg_count        0

# ---------------------------------------------------------------------------
# Helper procs (HOISTED to file scope so STEP 7 can use _resolve_assigned_slr
# even when STEP 6b is skipped because no modules were assigned in STEP 6).
# ---------------------------------------------------------------------------
proc _resolve_to_neighbor_level {cell_name assigned_mod} {
    set asgn_parts [split $assigned_mod "/"]
    set target_depth [llength $asgn_parts]
    set cell_parts [split $cell_name "/"]
    if {[llength $cell_parts] <= 1} { return "" }
    set use_depth $target_depth
    if {$use_depth >= [llength $cell_parts]} {
        set use_depth [expr {[llength $cell_parts] - 1}]
    }
    if {$use_depth <= 0} { return "" }
    return [join [lrange $cell_parts 0 [expr {$use_depth - 1}]] "/"]
}

proc _is_inside_any {cell_name mod_list} {
    foreach m $mod_list {
        if {[string match "${m}/*" $cell_name]} { return 1 }
    }
    return 0
}

proc _resolve_assigned_slr {cell_name} {
    upvar #0 assigned_slr_map _map
    if {![info exists _map]} { return "" }
    if {$cell_name eq ""} { return "" }
    if {[dict exists $_map $cell_name]} { return [dict get $_map $cell_name] }
    set parts [split $cell_name "/"]
    for {set i [expr {[llength $parts] - 1}]} {$i > 0} {incr i -1} {
        set anc [join [lrange $parts 0 [expr {$i - 1}]] "/"]
        if {[dict exists $_map $anc]} { return [dict get $_map $anc] }
    }
    return ""
}

proc _quiet_cell_distribution {cell_name} {
    if {$cell_name eq ""} { return [list 0 "" 0 0 0.0 ""] }
    set leaves [get_cells -hierarchical -filter "IS_PRIMITIVE && NAME =~ ${cell_name}/*" -quiet]
    set total [llength $leaves]
    if {$total == 0} { return [list 0 "" 0 0 0.0 ""] }
    array set slr_count {}
    set slrs [get_property SLR_INDEX $leaves]
    foreach slr $slrs {
        if {$slr eq ""} continue
        if {![info exists slr_count($slr)]} { set slr_count($slr) 0 }
        incr slr_count($slr)
    }
    set best_slr ""
    set best_count 0
    set dist_str ""
    foreach slr [lsort -integer [array names slr_count]] {
        set pct [format "%.1f" [expr {100.0 * $slr_count($slr) / $total}]]
        if {$dist_str ne ""} { append dist_str "  " }
        append dist_str [format "SLR%s=%d (%s%%)" $slr $slr_count($slr) $pct]
        if {$slr_count($slr) > $best_count} {
            set best_count $slr_count($slr)
            set best_slr "SLR$slr"
        }
    }
    set minority_count [expr {$total - $best_count}]
    set split_pct [expr {$total > 0 ? double($minority_count) / $total * 100.0 : 0.0}]
    return [list $total $best_slr $best_count $minority_count $split_pct $dist_str]
}

if {[dict size $assigned_slr_map] == 0} {
    puts "  No modules assigned in STEP 6. Skipping neighbor analysis."
} elseif {$is_mono_device} {
    puts "  Mono-SLR device. Skipping neighbor analysis."
} else {

# --- Helper: resolve a leaf cell to the neighbor module at the same
#     hierarchy depth as the assigned module.
#     e.g., assigned_mod = "A/B/C" (depth 3), cell = "A/D/E/foo_reg"
#           → returns "A/D/E" (depth 3, sibling of A/B/C)
#     If cell is shallower than assigned_mod depth, returns its parent.
proc _resolve_to_neighbor_level {cell_name assigned_mod} {
    set asgn_parts [split $assigned_mod "/"]
    set target_depth [llength $asgn_parts]

    set cell_parts [split $cell_name "/"]
    # The leaf cell itself is the last part; we want its hier parent's level
    # to match the assigned module's depth
    if {[llength $cell_parts] <= 1} { return "" }

    # Take the first target_depth components (or fewer if cell is shallower)
    set use_depth $target_depth
    if {$use_depth >= [llength $cell_parts]} {
        # Cell is at same depth or shallower — return its immediate parent
        set use_depth [expr {[llength $cell_parts] - 1}]
    }
    if {$use_depth <= 0} { return "" }
    return [join [lrange $cell_parts 0 [expr {$use_depth - 1}]] "/"]
}

# --- Helper: check if a cell name is inside any of the given modules -----
proc _is_inside_any {cell_name mod_list} {
    foreach m $mod_list {
        if {[string match "${m}/*" $cell_name]} { return 1 }
    }
    return 0
}

# --- Helper: resolve which assigned SLR a (hierarchical) cell belongs to.
#     Looks up `assigned_slr_map` (built in STEP 6 / 6b) for the cell itself
#     or any of its hierarchical ancestors. Longest ancestor wins.
#     Returns the SLR index/string, or "" if the cell is not under any
#     assigned module.
proc _resolve_assigned_slr {cell_name} {
    upvar #0 assigned_slr_map _map
    if {![info exists _map]} { return "" }
    if {$cell_name eq ""} { return "" }
    if {[dict exists $_map $cell_name]} { return [dict get $_map $cell_name] }
    set parts [split $cell_name "/"]
    for {set i [expr {[llength $parts] - 1}]} {$i > 0} {incr i -1} {
        set anc [join [lrange $parts 0 [expr {$i - 1}]] "/"]
        if {[dict exists $_map $anc]} { return [dict get $_map $anc] }
    }
    return ""
}

# --- Helper: quiet version of leaf cell SLR distribution (no stdout) -----
proc _quiet_cell_distribution {cell_name} {
    if {$cell_name eq ""} { return [list 0 "" 0 0 0.0 ""] }
    set leaves [get_cells -hierarchical -filter "IS_PRIMITIVE && NAME =~ ${cell_name}/*" -quiet]
    set total [llength $leaves]
    if {$total == 0} { return [list 0 "" 0 0 0.0 ""] }

    array set slr_count {}
    set slrs [get_property SLR_INDEX $leaves]
    foreach slr $slrs {
        if {$slr eq ""} continue
        if {![info exists slr_count($slr)]} { set slr_count($slr) 0 }
        incr slr_count($slr)
    }

    set best_slr ""
    set best_count 0
    set dist_str ""
    foreach slr [lsort -integer [array names slr_count]] {
        set pct [format "%.1f" [expr {100.0 * $slr_count($slr) / $total}]]
        if {$dist_str ne ""} { append dist_str "  " }
        append dist_str [format "SLR%s=%d (%s%%)" $slr $slr_count($slr) $pct]
        if {$slr_count($slr) > $best_count} {
            set best_count $slr_count($slr)
            set best_slr "SLR$slr"
        }
    }
    set minority_count [expr {$total - $best_count}]
    set split_pct [expr {$total > 0 ? double($minority_count) / $total * 100.0 : 0.0}]
    return [list $total $best_slr $best_count $minority_count $split_pct $dist_str]
}

set assigned_modules [dict keys $assigned_slr_map]

# Track modules already processed to avoid duplicates across assigned modules
set neighbor_already_processed [dict create]

set xdc_fp [open $OUTPUT_XDC a]
set rpt_fp [open $OUTPUT_RPT a]

puts $xdc_fp ""
puts $xdc_fp "################################################################################"
puts $xdc_fp "# STEP 6b: Connectivity-Aware Neighbor Pull-in & Pipeline Register Adjustment"
puts $xdc_fp "#"
puts $xdc_fp "# For assigned modules, traces boundary connections to neighbor modules."
puts $xdc_fp "# If pipeline registers exist on the path → assigns them for clean SLR crossing."
puts $xdc_fp "# If no pipeline → co-assigns neighbor to same SLR (when majority agrees)."
puts $xdc_fp "################################################################################"
puts $xdc_fp ""


puts $rpt_fp ""
puts $rpt_fp "================================================================================"
puts $rpt_fp " STEP 6b: Connectivity-Aware Neighbor Pull-in & Pipeline Detection"
puts $rpt_fp "================================================================================"
puts $rpt_fp ""

dict for {assigned_mod assigned_slr} $assigned_slr_map {

    puts "\n  ================================================================="
    puts "  Analyzing neighbors of: $assigned_mod (assigned to $assigned_slr)"
    puts "  =================================================================\n"
    puts $rpt_fp "  Assigned module: $assigned_mod -> $assigned_slr"

    set mod_cell [get_cells -quiet $assigned_mod]
    if {[llength $mod_cell] == 0} {
        puts "    WARNING: Cell '$assigned_mod' not found, skipping"
        continue
    }

    # --- Collect boundary pins ---
    set out_pins [get_pins -quiet -of_objects $mod_cell -filter {DIRECTION == "OUT"}]
    set in_pins  [get_pins -quiet -of_objects $mod_cell -filter {DIRECTION == "IN"}]

    puts "    Boundary pins: [llength $out_pins] outputs, [llength $in_pins] inputs"

    # --- Data structures ---
    # neighbor_direct(L1_mod) → count of direct (non-pipeline) connections
    # neighbor_pipeline(L1_mod) → list of {reg_cell_name direction}
    array unset neighbor_direct
    array unset neighbor_pipeline

    # --- Trace OUTPUT pins → find loads ---------------------------------
    puts "    Tracing output connections..."
    set out_traced 0

    foreach pin $out_pins {
        set net [get_nets -quiet -of_objects $pin]
        if {[llength $net] == 0} continue

        # Skip high-fanout nets (clock/reset/enable) — too noisy
        set fanout [get_property FLAT_PIN_COUNT $net -quiet]
        if {$fanout eq "" || $fanout > $NEIGHBOR_MAX_FANOUT} continue

        set load_pins [get_pins -quiet -leaf -of_objects $net -filter {DIRECTION == "IN"}]
        foreach lp $load_pins {
            set lcell [get_cells -quiet -of_objects $lp]
            if {[llength $lcell] == 0} continue
            set lcell_name [get_property NAME $lcell]

            # Skip cells inside our assigned module
            if {[string match "${assigned_mod}/*" $lcell_name]} continue

            set pg [get_property PRIMITIVE_GROUP $lcell -quiet]
            set is_reg [expr {$pg eq "REGISTER"}]

            # Check if inside any OTHER already-assigned module
            set inside_assigned [_is_inside_any $lcell_name $assigned_modules]

            if {$is_reg && !$inside_assigned} {
                # Potential pipeline register — trace its Q pin one hop further
                set reg_q_pins [get_pins -quiet -of_objects $lcell -filter {DIRECTION == "OUT"}]
                set found_dest 0
                foreach qp $reg_q_pins {
                    set next_net [get_nets -quiet -of_objects $qp]
                    if {[llength $next_net] == 0} continue
                    set nf [get_property FLAT_PIN_COUNT $next_net -quiet]
                    if {$nf eq "" || $nf > $NEIGHBOR_MAX_FANOUT} continue

                    set next_loads [get_pins -quiet -leaf -of_objects $next_net -filter {DIRECTION == "IN"}]
                    foreach nlp $next_loads {
                        set ncell [get_cells -quiet -of_objects $nlp]
                        if {[llength $ncell] == 0} continue
                        set ncell_name [get_property NAME $ncell]
                        if {[string match "${assigned_mod}/*" $ncell_name]} continue

                        set dest_L1 [_resolve_to_neighbor_level $ncell_name $assigned_mod]
                        if {$dest_L1 eq ""} continue

                        # Pipeline: assigned_mod → reg → dest_L1
                        if {![info exists neighbor_pipeline($dest_L1)]} {
                            set neighbor_pipeline($dest_L1) {}
                        }
                        lappend neighbor_pipeline($dest_L1) [list $lcell_name "outbound"]
                        set found_dest 1
                    }
                }
                # If we couldn't trace further, count as direct to reg's L1
                if {!$found_dest} {
                    set l1 [_resolve_to_neighbor_level $lcell_name $assigned_mod]
                    if {$l1 ne ""} {
                        if {![info exists neighbor_direct($l1)]} { set neighbor_direct($l1) 0 }
                        incr neighbor_direct($l1)
                    }
                }
            } else {
                # Direct connection (non-register or inside assigned module)
                set l1 [_resolve_to_neighbor_level $lcell_name $assigned_mod]
                if {$l1 eq ""} continue
                if {[_is_inside_any $lcell_name $assigned_modules]} continue
                if {![info exists neighbor_direct($l1)]} { set neighbor_direct($l1) 0 }
                incr neighbor_direct($l1)
            }
        }
        incr out_traced
    }
    puts "    Traced $out_traced output nets"

    # --- Trace INPUT pins → find drivers --------------------------------
    puts "    Tracing input connections..."
    set in_traced 0

    foreach pin $in_pins {
        set net [get_nets -quiet -of_objects $pin]
        if {[llength $net] == 0} continue

        set fanout [get_property FLAT_PIN_COUNT $net -quiet]
        if {$fanout eq "" || $fanout > $NEIGHBOR_MAX_FANOUT} continue

        set driver_pins [get_pins -quiet -leaf -of_objects $net -filter {DIRECTION == "OUT"}]
        foreach dp $driver_pins {
            set dcell [get_cells -quiet -of_objects $dp]
            if {[llength $dcell] == 0} continue
            set dcell_name [get_property NAME $dcell]

            if {[string match "${assigned_mod}/*" $dcell_name]} continue

            set pg [get_property PRIMITIVE_GROUP $dcell -quiet]
            set is_reg [expr {$pg eq "REGISTER"}]

            set inside_assigned [_is_inside_any $dcell_name $assigned_modules]

            if {$is_reg && !$inside_assigned} {
                # Potential pipeline register — trace its D pin one hop back
                set reg_d_pins [get_pins -quiet -of_objects $dcell -filter {DIRECTION == "IN" && REF_PIN_NAME == "D"}]
                set found_src 0
                foreach dp_in $reg_d_pins {
                    set prev_net [get_nets -quiet -of_objects $dp_in]
                    if {[llength $prev_net] == 0} continue
                    set pf [get_property FLAT_PIN_COUNT $prev_net -quiet]
                    if {$pf eq "" || $pf > $NEIGHBOR_MAX_FANOUT} continue

                    set prev_drivers [get_pins -quiet -leaf -of_objects $prev_net -filter {DIRECTION == "OUT"}]
                    foreach pdp $prev_drivers {
                        set pcell [get_cells -quiet -of_objects $pdp]
                        if {[llength $pcell] == 0} continue
                        set pcell_name [get_property NAME $pcell]
                        if {[string match "${assigned_mod}/*" $pcell_name]} continue

                        set src_L1 [_resolve_to_neighbor_level $pcell_name $assigned_mod]
                        if {$src_L1 eq ""} continue

                        # Pipeline: src_L1 → reg → assigned_mod
                        if {![info exists neighbor_pipeline($src_L1)]} {
                            set neighbor_pipeline($src_L1) {}
                        }
                        lappend neighbor_pipeline($src_L1) [list $dcell_name "inbound"]
                        set found_src 1
                    }
                }
                if {!$found_src} {
                    set l1 [_resolve_to_neighbor_level $dcell_name $assigned_mod]
                    if {$l1 ne ""} {
                        if {![info exists neighbor_direct($l1)]} { set neighbor_direct($l1) 0 }
                        incr neighbor_direct($l1)
                    }
                }
            } else {
                set l1 [_resolve_to_neighbor_level $dcell_name $assigned_mod]
                if {$l1 eq ""} continue
                if {[_is_inside_any $dcell_name $assigned_modules]} continue
                if {![info exists neighbor_direct($l1)]} { set neighbor_direct($l1) 0 }
                incr neighbor_direct($l1)
            }
        }
        incr in_traced
    }
    puts "    Traced $in_traced input nets"

    # --- Merge all neighbors into a sorted list --------------------------
    set all_neighbor_mods [dict create]
    foreach n [array names neighbor_direct] {
        dict set all_neighbor_mods $n direct $neighbor_direct($n)
        if {![dict exists $all_neighbor_mods $n pipeline]} {
            dict set all_neighbor_mods $n pipeline {}
        }
    }
    foreach n [array names neighbor_pipeline] {
        if {![dict exists $all_neighbor_mods $n]} {
            dict set all_neighbor_mods $n direct 0
        }
        # De-duplicate pipeline regs for this neighbor
        set unique_regs [dict create]
        foreach preg $neighbor_pipeline($n) {
            lassign $preg rname rdir
            dict set unique_regs $rname $rdir
        }
        set deduped {}
        dict for {rname rdir} $unique_regs { lappend deduped [list $rname $rdir] }
        dict set all_neighbor_mods $n pipeline $deduped
    }

    # Sort neighbors by total connection count (direct + pipeline)
    set sorted_neighbors {}
    dict for {nmod ninfo} $all_neighbor_mods {
        set dc [dict get $ninfo direct]
        set pl [dict get $ninfo pipeline]
        set total [expr {$dc + [llength $pl]}]
        lappend sorted_neighbors [list $nmod $total $dc $pl]
    }
    set sorted_neighbors [lsort -integer -decreasing -index 1 $sorted_neighbors]

    set n_above_thresh 0
    foreach ne $sorted_neighbors {
        if {[lindex $ne 1] >= $NEIGHBOR_CONN_THRESH} { incr n_above_thresh }
    }
    puts "\n    Neighbors above threshold ($NEIGHBOR_CONN_THRESH): $n_above_thresh / [llength $sorted_neighbors] total"
    puts $rpt_fp "    Neighbors above threshold: $n_above_thresh / [llength $sorted_neighbors]"
    puts ""

    foreach nentry $sorted_neighbors {
        lassign $nentry nmod total_conn direct_conn pipeline_list
        set n_pipeline [llength $pipeline_list]

        # Only consider significant neighbors
        if {$total_conn < $NEIGHBOR_CONN_THRESH} continue

        # FIX#1 (decoupled): when set, withhold the CO-ASSIGN pin only; still
        # emit USER_CROSSING_SLR 1 on the neighbor's pipeline nets.
        set _gt_no_pin 0
        # FIX#2 (decoupled): when set, withhold the CO-ASSIGN pin for an
        # already-cell-majority pipeline neighbor; still emit leaf-level tags.
        set _fix2_no_pin 0

        puts [format "    %-55s  direct:%-5d  pipeline_regs:%-4d  total:%-5d" \
            $nmod $direct_conn $n_pipeline $total_conn]
        puts $rpt_fp [format "    %-55s  direct:%-5d  pipeline_regs:%-4d  total:%-5d" \
            $nmod $direct_conn $n_pipeline $total_conn]

        # ---- FIX#1: GT-SPLIT NEIGHBOR GUARD ----------------------------------
        # Do NOT pin this neighbor or emit USER_CROSSING_SLR on its pipeline
        # path when the neighbor (or an ancestor) holds GT primitives split
        # across SLRs. Pinning one end of a GT-split datapath forces the other
        # SLR's GT lanes to cross (Util54 idb_bridge -> pg9_mio_gtm_1_regs
        # NoC->flop regression). STEP 6b analogue of ENH#8 / ENH#12.
        # ---- FIX#1 (DECOUPLED 2026-06-07): withhold PIN only, keep CROSSING
        # tags. The blanket `continue` here dropped the USER_CROSSING_SLR 1
        # pipeline-net constraints on GT-split neighbors as well as the pin.
        # For Util54 that skipped matrix_io_top entirely (the module holding
        # the MRMAC), removing the 50 USER_CROSSING_SLR 1 tags on its
        # .../mrmac_1/.../rx_serdes_data[*] pipeline nets that V2 emitted -> the
        # MRMAC RX datapath floated across the SLR on rxusrclk_out (253 MAC
        # crossings, WNS -0.331 -> -0.466). The PIN must still be withheld
        # (pinning one end of a GT-split datapath orphans the other SLR's GT
        # lanes - the idb_bridge -> pg9_mio_gtm_1_regs case), but the pipeline
        # crossing tags must be preserved. Set a flag and fall through; the
        # CASE A / CASE B co-assign branches honor $_gt_no_pin to skip the pin.
        if {$GT_SPLIT_NEIGHBOR_GUARD} {
            set _gtsplit_reason [_gt_split_neighbor_reason $nmod]
            if {$_gtsplit_reason ne ""} {
                set _gt_no_pin 1
                puts "      >> FIX#1 GT-SPLIT NEIGHBOR GUARD: withholding PIN for $nmod (crossing tags kept)"
                puts "         Reason: $_gtsplit_reason"
                puts $rpt_fp "      >> FIX#1 GT-split neighbor guard: PIN withheld, USER_CROSSING_SLR 1 still emitted ($_gtsplit_reason)"
                puts $xdc_fp "# FIX#1 GT-split neighbor guard: PIN withheld for neighbor $nmod (USER_CROSSING_SLR 1 still emitted on its pipeline nets)"
                puts $xdc_fp "#   Reason: $_gtsplit_reason"
                puts $xdc_fp "#   (pinning one end of a GT-split datapath would orphan the other SLR's GT lanes; crossing tags keep the pipeline path intra-SLR)"
                puts $xdc_fp ""
                incr _fix1_gt_split_neighbor_skipped
            }
        }

        # Skip if already processed as neighbor of another assignee
        if {[dict exists $neighbor_already_processed $nmod]} {
            puts "      >> Already processed (neighbor of another assigned module)"
            continue
        }

        # ENH#6 (correct cross-SLR test): if neighbor IS already assigned, only
        # emit pipeline-reg crossing constraints when the two SLRs DIFFER.
        # Same-SLR pair => pipeline regs are NOT crossing, so skip entirely.
        # Different-SLR pair => fall through to emit USER_CROSSING_SLR 1 with
        # the neighbor's known SLR.
        if {[dict exists $assigned_slr_map $nmod]} {
            set _nmod_assigned_slr [dict get $assigned_slr_map $nmod]
            if {$_nmod_assigned_slr eq $assigned_slr} {
                puts "      >> Same SLR ($assigned_slr) as assigned module - NOT a crossing, skipping pipeline-reg emission"
                puts $rpt_fp "      >> Same SLR ($assigned_slr): pipeline regs NOT a crossing - skipped"
                continue
            } else {
                puts "      >> Both assigned: ${assigned_mod}($assigned_slr) <-> ${nmod}($_nmod_assigned_slr) - VALID cross-SLR, emitting USER_CROSSING_SLR 1"
                puts $rpt_fp "      >> Cross-SLR pair: $assigned_slr <-> $_nmod_assigned_slr - pipeline regs will be tagged"
            }
        }

        # ================================================================
        # CASE A: Pipeline registers found on the path
        # ================================================================
        if {$n_pipeline > 0} {
            puts "      PIPELINE PATH: $n_pipeline register(s) found between modules"
            puts $rpt_fp "      PIPELINE PATH: $n_pipeline register(s)"

            # Get neighbor B's natural SLR (needed for inbound reg placement)
            lassign [_quiet_cell_distribution $nmod] \
                np_total np_best_slr np_best_count np_minority np_split_pct np_dist

            # Determine B's effective SLR for inbound pipeline reg placement
            # Use B's cell-majority SLR if it has cells, else fall back to A's SLR
            if {$np_total > 0 && $np_best_slr ne ""} {
                set nmod_slr $np_best_slr
            } else {
                set nmod_slr $assigned_slr
            }

            # ---- FIX#2 (DECOUPLED): MODULE-LEVEL MAJORITY -> PIN WITHHOLD ---
            # When the assigned module and this pipeline neighbor are both
            # cell-MAJORITY on the SAME SLR, the old V3 code `continue`d here,
            # dropping BOTH the pipeline USER_CROSSING_SLR net tags AND the
            # co-assign pin -> Barco_3screen / Util MRMAC regressions. A blanket
            # disable (always pin) instead regresses SM_Optics_rigel (re-pinning
            # 10 connectivity-pulled flexo/OTN modules -> 95->900 crossings).
            # SAFE MIDDLE GROUND: withhold only the PIN (these modules are
            # already cell-majority on this SLR, so the placer keeps them here
            # without an explicit USER_SLR_ASSIGNMENT) while KEEPING the
            # leaf-level USER_CROSSING_SLR 1 tags emitted below (which pin the
            # actual minority-SLR pipeline-reg crossings). Fall through; the
            # CASE A co-assign branch honors $_fix2_no_pin to skip the pin.
            if {$FIX2_WITHHOLD_PIN && $np_total > 0 && $nmod_slr eq $assigned_slr} {
                set _fix2_no_pin 1
                puts "      >> FIX#2 PIN WITHHELD: ${nmod} cell-majority on $assigned_slr (== ${assigned_mod}); crossing tags kept, pin skipped"
                puts $rpt_fp "      >> FIX#2 PIN withheld (both cell-majority $assigned_slr): USER_CROSSING_SLR 1 still emitted, USER_SLR_ASSIGNMENT not set"
                incr _fix2_majority_crossing_skipped
            }

            # Direction-aware pipeline register placement:
            #   Outbound (A → reg → B): reg in A's SLR (source-side)
            #     A(SLR_A) → reg(SLR_A) → [crossing] → B(SLR_B)
            #     Pipeline absorbs A's launch delay; crossing is after the flop.
            #
            #   Inbound  (B → reg → A): reg in B's SLR (source-side)
            #     B(SLR_B) → reg(SLR_B) → [crossing] → A(SLR_A)
            #     Pipeline absorbs B's launch delay; crossing is after the flop.
            #
            # Rule: always place the pipeline reg on the SOURCE side so the
            # SLR crossing wire is in the capture path after the flop.
            # ENH#4: skip pipeline regs whose nearest assigned ancestor is in a
            #        different SLR (would conflict with parent USER_SLR_ASSIGNMENT).
            # ENH#5: cap pipeline reg emissions per neighbor to avoid 1000s of
            #        leaf-level constraints fragmenting placement.
            # BUG FIX: leaf cells DO NOT support USER_SLR_ASSIGNMENT (Vivado warn
            #        12-8092). Instead, mark the reg's OUTPUT net (the crossing
            #        wire) with USER_CROSSING_SLR 1 so router knows it crosses
            #        exactly one SLR. This is a net-level property that the
            #        placer honors and is the correct constraint for pipeline
            #        crossings.
            set reg_written 0
            set reg_skipped_ancestor 0
            set reg_skipped_cap 0
            set nets_marked 0
            foreach preg $pipeline_list {
                if {$reg_written >= $MAX_PIPELINE_REGS_PER_NEIGHBOR} {
                    incr reg_skipped_cap
                    continue
                }
                lassign $preg reg_name direction

                set reg_cell [get_cells -quiet $reg_name]
                if {[llength $reg_cell] == 0} continue

                set reg_slr [get_property SLR_INDEX $reg_cell -quiet]
                set reg_slr_str ""
                if {$reg_slr ne ""} { set reg_slr_str "SLR$reg_slr" }

                if {$direction eq "outbound"} {
                    set target_slr $assigned_slr
                    set tag "source-side (${assigned_mod} → ${nmod}), net -> USER_CROSSING_SLR 1"
                } else {
                    set target_slr $nmod_slr
                    set tag "source-side (${nmod} → ${assigned_mod}), net -> USER_CROSSING_SLR 1"
                }

                # ENH#4: ancestor-conflict guard
                # Walk up the hier of reg_name; if any ancestor exists in
                # assigned_slr_map with a different SLR than target_slr, skip.
                set _anc_conflict 0
                set _anc_parts [split $reg_name "/"]
                for {set _ai [expr {[llength $_anc_parts] - 1}]} {$_ai >= 1} {incr _ai -1} {
                    set _anc [join [lrange $_anc_parts 0 [expr {$_ai - 1}]] "/"]
                    if {$_anc eq ""} break
                    if {[dict exists $assigned_slr_map $_anc]} {
                        set _anc_slr [dict get $assigned_slr_map $_anc]
                        if {$_anc_slr ne $target_slr} {
                            set _anc_conflict 1
                        }
                        break
                    }
                }
                if {$_anc_conflict} {
                    incr reg_skipped_ancestor
                    continue
                }

                # BUG FIX: use USER_CROSSING_SLR 1 on the register's OUTPUT net
                # (Q pin → load). Leaf cells cannot take USER_SLR_ASSIGNMENT.
                set out_pins [get_pins -quiet -of_objects $reg_cell -filter {DIRECTION == "OUT"}]
                if {[llength $out_pins] == 0} continue
                set out_nets {}
                foreach _op $out_pins {
                    foreach _n [get_nets -quiet -of_objects $_op] {
                        set _nn [get_property -quiet NAME $_n]
                        if {$_nn ne "" && [lsearch -exact $out_nets $_nn] == -1} {
                            lappend out_nets $_nn
                        }
                    }
                }
                if {[llength $out_nets] == 0} continue

                puts $xdc_fp "# Pipeline reg: $tag"
                puts $xdc_fp "#   Register: $reg_name (current: $reg_slr_str)"
                puts $xdc_fp "#   Target crossing direction: $target_slr (source-side reg)"
                foreach _nn $out_nets {
                    # ---- ENH#14: STRICT single-fanout pipeline-reg net check --
                    # Vivado honors USER_CROSSING_SLR=1 only on a genuine
                    # single-driver/single-load FD-Q -> FD-D pipeline net. If the
                    # net is not exactly that shape, the placer drops the anchor
                    # (and may warn). Skip emission entirely for non-pipeline nets.
                    if {$STRICT_PIPELINE_REG_CHECK} {
                        if {![_is_strict_pipeline_reg_net $_nn]} {
                            puts $xdc_fp "# ENH#14 skip USER_CROSSING_SLR=1 on $_nn (not a strict single-fanout FD-Q->FD-D pipeline net)"
                            incr _enh14_strict_pipeline_filtered
                            continue
                        }
                    }

                    # ---- ENH#11: multi-fanout USER_CROSSING_SLR=1 backstop ----
                    # Vivado [Place 30-1228] drops USER_CROSSING_SLR=1 on
                    # multi-fanout nets ("only single-fanout pipeline register
                    # connections"). Filter at script time to avoid polluting
                    # the XDC with no-op anchors and triggering placer warnings.
                    if {$CROSSING1_MAX_FANOUT > 0} {
                        set _fo [_net_load_fanout $_nn]
                        if {$_fo > $CROSSING1_MAX_FANOUT} {
                            puts $xdc_fp "# ENH#11 skip USER_CROSSING_SLR=1 on $_nn (load fanout $_fo > $CROSSING1_MAX_FANOUT) - placer would drop it"
                            incr _enh11_crossing1_filtered
                            continue
                        }
                    }

                    # ---- ENH#15 / FIX#2: same-SLR endpoint precheck -----------
                    # Resolve the SLR of the net's SOURCE (reg Q) pin and its
                    # LOAD (reg D) pin. If both resolve to the SAME SLR, the net
                    # is NOT a real crossing and tagging USER_CROSSING_SLR=1
                    # would harden a phantom crossing. When CROSSING1_MAJORITY_SLR
                    # is set, resolve by owning-module cell-MAJORITY (FIX#2) so a
                    # transiently-misplaced leaf does not masquerade as a crossing;
                    # otherwise resolve by assignment-ancestry + leaf SLR_INDEX.
                    if {$CROSSING1_SAME_SLR_SKIP} {
                        set _net_o [get_nets -quiet $_nn]
                        set _src_pin [get_pins -quiet -of_objects $_net_o -filter {DIRECTION == "OUT"}]
                        set _load_pin [get_pins -quiet -of_objects $_net_o -filter {DIRECTION == "IN"}]
                        if {[llength $_src_pin] == 1 && [llength $_load_pin] >= 1} {
                            if {$CROSSING1_MAJORITY_SLR} {
                                set _src_slr  [_pin_majority_slr $_src_pin]
                                set _load_slr [_pin_majority_slr [lindex $_load_pin 0]]
                            } else {
                                set _src_slr  [_pin_resolved_slr $_src_pin]
                                set _load_slr [_pin_resolved_slr [lindex $_load_pin 0]]
                            }
                            if {$_src_slr ne "" && $_load_slr ne "" && $_src_slr eq $_load_slr} {
                                puts $xdc_fp "# ENH#15 skip USER_CROSSING_SLR=1 on $_nn (src & load both resolve to $_src_slr - not a real crossing)"
                                incr _enh15_same_slr_skipped
                                continue
                            }
                        }
                    }

                    puts $xdc_fp "catch { set_property USER_CROSSING_SLR 1 \[get_nets \{$_nn\}\] }"
                    lappend command "set_property USER_CROSSING_SLR 1 \[get_nets \{$_nn\}\]"
                    incr nets_marked
                }
                puts $xdc_fp ""

                incr reg_written
                incr pipeline_reg_count
            }

            puts "      Marked $nets_marked crossing net(s) from $reg_written pipeline reg(s) with USER_CROSSING_SLR 1"
            if {$reg_skipped_ancestor > 0} {
                puts "      Skipped $reg_skipped_ancestor reg(s): ancestor SLR conflict (ENH#4)"
                puts $rpt_fp "      >> Skipped $reg_skipped_ancestor reg(s) due to ancestor SLR conflict"
            }
            if {$reg_skipped_cap > 0} {
                puts "      Skipped $reg_skipped_cap reg(s): MAX_PIPELINE_REGS_PER_NEIGHBOR=$MAX_PIPELINE_REGS_PER_NEIGHBOR (ENH#5)"
                puts $rpt_fp "      >> Skipped $reg_skipped_cap reg(s) due to per-neighbor cap"
            }
            puts $rpt_fp "      >> $nets_marked nets marked USER_CROSSING_SLR 1 from $reg_written pipeline regs (outbound->$assigned_slr, inbound->$nmod_slr)"

            # Also check if neighbor module B itself qualifies for co-assignment
            puts "      Checking if neighbor module also qualifies for co-assignment..."

            # np_* variables already computed above from _quiet_cell_distribution

            if {$np_total > 0 && $np_best_slr ne "" && $np_best_slr eq $assigned_slr \
                && $np_split_pct <= $NEIGHBOR_MAX_SPLIT} {

                set np_pblock_ok 1
                if {$design_has_pblocks} {
                    set pb_r [check_pblock_conflict $nmod]
                    if {[dict get $pb_r has_conflict]} { set np_pblock_ok 0 }
                }

                # GT/XCVR check (Spec 5c.7): cannot SLR-assign GT modules
                if {$np_pblock_ok && [_module_contains_gt $nmod]} {
                    set np_pblock_ok 0
                    puts "      >> SKIP module co-assign: contains GT/XCVR fixed-location primitives"
                    puts $rpt_fp "      >> SKIP module co-assign: GT/XCVR fixed-location"
                }

                # FIX#1 (decoupled): GT-split neighbor - withhold PIN only.
                # The USER_CROSSING_SLR 1 emission above already ran.
                if {$np_pblock_ok && $_gt_no_pin} {
                    set np_pblock_ok 0
                    puts "      >> FIX#1 SKIP module co-assign PIN (GT-split neighbor); USER_CROSSING_SLR 1 tags kept"
                    puts $rpt_fp "      >> FIX#1 PIN withheld (GT-split): USER_CROSSING_SLR 1 emitted, USER_SLR_ASSIGNMENT not set"
                }

                # FIX#2 (decoupled): already-cell-majority neighbor - withhold
                # PIN only. The leaf-level USER_CROSSING_SLR 1 tags above keep
                # the real minority-SLR pipeline crossings pinned; the module
                # itself places on its majority SLR without an explicit pin
                # (avoids the SM_Optics over-constraint regression).
                if {$np_pblock_ok && $_fix2_no_pin} {
                    set np_pblock_ok 0
                    puts "      >> FIX#2 SKIP module co-assign PIN (already cell-majority on $assigned_slr); USER_CROSSING_SLR 1 tags kept"
                    puts $rpt_fp "      >> FIX#2 PIN withheld (cell-majority): USER_CROSSING_SLR 1 emitted, USER_SLR_ASSIGNMENT not set"
                }

                if {$np_pblock_ok} {
                    puts "      >> CO-ASSIGN (with pipeline): $nmod -> $assigned_slr ([format %.1f [expr {100.0 - $np_split_pct}]]% majority)"
                    puts $rpt_fp "      >> CO-ASSIGN (with pipeline): $nmod -> $assigned_slr"

                    puts $xdc_fp "# Neighbor co-assignment (pipeline path): $nmod -> $assigned_slr"
                    puts $xdc_fp "#   Neighbor of assigned module: $assigned_mod"
                    puts $xdc_fp "#   Direct connections: $direct_conn  Pipeline regs: $n_pipeline"
                    puts $xdc_fp "#   Cell distribution: $np_dist"
                    puts $xdc_fp "#   Majority: $np_best_slr ([format %.1f [expr {100.0 - $np_split_pct}]]%)"
                    puts $xdc_fp "catch { set_property USER_SLR_ASSIGNMENT $assigned_slr \[get_cells \{$nmod\}\] }"
                    lappend command "set_property USER_SLR_ASSIGNMENT $assigned_slr \[get_cells \{$nmod\}\]"
                    puts $xdc_fp ""

                    # Pblock XDC: module co-assignment
                    incr neighbor_suggestion_count
                    dict set assigned_slr_map $nmod $assigned_slr
                    lappend _diag_modules [list $nmod assign $assigned_slr 0 $np_total $np_minority [expr {100.0 - $np_split_pct}] $np_dist "Neighbor co-assign (pipeline): direct=$direct_conn pipeline=$n_pipeline" step6b $assigned_mod]
                    lappend _diag_connections [list $assigned_mod $nmod $direct_conn $n_pipeline pipeline]
                } else {
                    puts "      >> SKIP module co-assign: pblock conflict"
                }
            } else {
                if {$np_total == 0} {
                    puts "      >> SKIP module co-assign: no cells"
                } elseif {$np_best_slr eq ""} {
                    puts "      >> SKIP module co-assign: all unplaced"
                } elseif {$np_best_slr ne $assigned_slr} {
                    puts "      >> SKIP module co-assign: majority in $np_best_slr, not $assigned_slr"
                } else {
                    puts "      >> SKIP module co-assign: split too high ([format %.1f $np_split_pct]%)"
                }
            }

            puts $rpt_fp ""
            dict set neighbor_already_processed $nmod 1

        # ================================================================
        # CASE B: No pipeline — consider co-assigning neighbor to same SLR
        # ================================================================
        } else {
            puts "      NO PIPELINE: Checking co-assignment eligibility..."
            puts $rpt_fp "      No pipeline regs — co-assignment check"

            # Get neighbor's cell distribution (quiet — no stdout spam)
            lassign [_quiet_cell_distribution $nmod] \
                n_total n_best_slr n_best_count n_minority n_split_pct n_dist

            if {$n_total == 0} {
                puts "      >> SKIP: No cells found under '$nmod'"
                puts $rpt_fp "      >> SKIP: No cells"
                puts $rpt_fp ""
                continue
            }

            if {$n_best_slr eq ""} {
                puts "      >> SKIP: All cells unplaced"
                puts $rpt_fp "      >> SKIP: All unplaced"
                puts $rpt_fp ""
                continue
            }

            puts "      Cells: $n_total  Best: $n_best_slr ($n_best_count, [format %.1f [expr {100.0 - $n_split_pct}]]%)  Dist: $n_dist"
            puts $rpt_fp "      Cells: $n_total  Best: $n_best_slr  Split: [format %.1f $n_split_pct]%"

            # Does neighbor's majority agree with the assigned SLR?
            if {$n_best_slr ne $assigned_slr} {
                puts "      >> SKIP: Majority in $n_best_slr, not $assigned_slr"
                puts $rpt_fp "      >> SKIP: Majority disagrees ($n_best_slr vs $assigned_slr)"
                puts $rpt_fp ""
                continue
            }

            # Is the split acceptable?
            if {$n_split_pct > $NEIGHBOR_MAX_SPLIT} {
                puts "      >> SKIP: Split too high ([format %.1f $n_split_pct]% > ${NEIGHBOR_MAX_SPLIT}%)"
                puts $rpt_fp "      >> SKIP: Split [format %.1f $n_split_pct]% > ${NEIGHBOR_MAX_SPLIT}%"
                puts $rpt_fp ""
                continue
            }

            # Pblock conflict check
            if {$design_has_pblocks} {
                set pb_result [check_pblock_conflict $nmod]
                if {[dict get $pb_result has_conflict]} {
                    set pr [dict get $pb_result reason]
                    puts "      >> SKIP: Pblock conflict ($pr)"
                    puts $rpt_fp "      >> SKIP: Pblock conflict"
                    puts $rpt_fp ""
                    continue
                }
            }

            # GT/XCVR check (Spec 5c.7): cannot SLR-assign GT modules
            if {[_module_contains_gt $nmod]} {
                puts "      >> SKIP: Contains GT/XCVR fixed-location primitives"
                puts $rpt_fp "      >> SKIP: Contains GT/XCVR fixed-location primitives"
                puts $rpt_fp ""
                continue
            }

            # FIX#1 (decoupled): GT-split neighbor with NO pipeline regs - there
            # are no crossing nets to tag, so withhold the PIN and move on
            # (pinning a GT-split datapath end orphans the other SLR's GT lanes).
            if {$_gt_no_pin} {
                puts "      >> FIX#1 SKIP co-assign PIN (GT-split neighbor, no pipeline regs to tag)"
                puts $rpt_fp "      >> FIX#1 PIN withheld (GT-split, no pipeline)"
                puts $rpt_fp ""
                continue
            }

            # --- Co-assign neighbor ---
            puts "      >> CO-ASSIGN: $nmod -> $assigned_slr ([format %.1f [expr {100.0 - $n_split_pct}]]% majority, $direct_conn direct connections)"
            puts $rpt_fp "      >> CO-ASSIGN: $nmod -> $assigned_slr"
            puts $rpt_fp ""

            puts $xdc_fp "# Neighbor co-assignment: $nmod -> $assigned_slr"
            puts $xdc_fp "#   Neighbor of assigned module: $assigned_mod"
            puts $xdc_fp "#   Direct connections: $direct_conn"
            puts $xdc_fp "#   Cell distribution: $n_dist"
            puts $xdc_fp "#   Majority: $n_best_slr ([format %.1f [expr {100.0 - $n_split_pct}]]%)"
            puts $xdc_fp "catch { set_property USER_SLR_ASSIGNMENT $assigned_slr \[get_cells \{$nmod\}\] }"
            lappend command "set_property USER_SLR_ASSIGNMENT $assigned_slr \[get_cells \{$nmod\}\]"
            puts $xdc_fp ""

            # Pblock XDC: module co-assignment

            incr neighbor_suggestion_count
            dict set assigned_slr_map $nmod $assigned_slr
            dict set neighbor_already_processed $nmod 1
            lappend _diag_modules [list $nmod assign $assigned_slr 0 $n_total $n_minority [expr {100.0 - $n_split_pct}] $n_dist "Neighbor co-assign: $direct_conn direct connections" step6b $assigned_mod]
            lappend _diag_connections [list $assigned_mod $nmod $direct_conn 0 direct]
        }
    }
    puts ""
    puts $rpt_fp ""
}

close $xdc_fp
close $rpt_fp

puts "  ================================================================="
puts "  STEP 6b Summary"
puts "  ================================================================="
puts "  Neighbor modules co-assigned   : $neighbor_suggestion_count"
puts "  Pipeline registers assigned    : $pipeline_reg_count"
puts [format "  ENH#11 USER_CROSSING_SLR=1 filtered : %d (multi-fanout, would be dropped by placer)" $_enh11_crossing1_filtered]
puts [format "  ENH#14 strict-pipeline filtered     : %d (net not a single-fanout FD-Q->FD-D pipeline net)" $_enh14_strict_pipeline_filtered]
puts [format "  ENH#15 same-SLR endpoint skipped    : %d (src & load resolve to same SLR%s)" \
    $_enh15_same_slr_skipped [expr {$CROSSING1_MAJORITY_SLR ? ", majority-based" : ""}]]
puts [format "  FIX#1  GT-split neighbor skipped     : %d (neighbor or ancestor has GTs split across SLRs)" $_fix1_gt_split_neighbor_skipped]
puts [format "  FIX#2  majority short-circuit skipped: %d (assigned & neighbor both cell-majority on same SLR)" $_fix2_majority_crossing_skipped]
puts ""

;# end of "else" block (not mono device and has assignments)
}

###############################################################################
# STEP 7: GT/XCVR + PCIE + MMCM + BRAM/URAM/DSP + DCMAC/MRMAC
#         Inter-SLR Constraint Hardening (USER_CROSSING_SLR 0)
#
# GT quad instances (GTYP, GTM, GTYE, GTHE) are FIXED-LOCATION primitives.
# They cannot be moved by USER_SLR_ASSIGNMENT. When a timing path crosses
# SLR boundaries and one endpoint is a GT primitive:
#
#   - The GT side CANNOT move → constrain the OTHER side, or
#   - Apply USER_CROSSING_SLR 0 on the connecting net
#
# This step specifically targets paths from/to GT quad channel pins
# (RXUSRCLK, TXUSRCLK, RXDATA, TXDATA, etc.) that cross SLR.
###############################################################################

set step9_net_count 0

puts "\n========================================================================="
puts " STEP 7: Anchor-Aware Inter-SLR Constraint Hardening"
puts "         (GT/XCVR + PCIE/CPM + MMCM + BRAM/URAM/DSP + DCMAC/MRMAC)"
puts "=========================================================================\n"

if {$is_mono_device} {
    puts "  Mono-SLR device. Skipping STEP 7."
} else {

# ---- 7a: Find all anchor (fixed/placement-sensitive) primitive cells ----
set gt_all_cells [get_cells -hier -filter {
    REF_NAME =~ GTYP* || REF_NAME =~ GTM* || REF_NAME =~ GTYE* ||
    REF_NAME =~ GTHE* || REF_NAME =~ BUFG_GT* || REF_NAME =~ IBUFDS_GTE* ||
    REF_NAME =~ OBUFDS_GTE* || REF_NAME =~ MMCM* || REF_NAME =~ PCIE* ||
    REF_NAME =~ CPM* || PRIMITIVE_GROUP == BLOCKRAM || PRIMITIVE_GROUP == URAM ||
    PRIMITIVE_GROUP == ARITHMETIC || REF_NAME =~ DCMAC* || REF_NAME =~ MRMAC*
} -quiet]

puts "  Anchor primitive cells found: [llength $gt_all_cells]"

if {[llength $gt_all_cells] == 0} {
    puts "  No anchor primitives in design. Skipping STEP 7."
} else {

# ---- 7b: Query ALL timing paths from/to anchor cells (no slack filter) ----
puts "  Querying anchor -> non-anchor paths (no slack filter)..."
set gt_paths_from [get_timing_paths -from $gt_all_cells \
    -max_paths $GT_MAX_PATHS -nworst 1 -quiet]
puts "    Found [llength $gt_paths_from] paths"

puts "  Querying non-anchor -> anchor paths (no slack filter)..."
set gt_paths_to [get_timing_paths -to $gt_all_cells \
    -max_paths $GT_MAX_PATHS -nworst 1 -quiet]
puts "    Found [llength $gt_paths_to] paths"

set gt_all_paths [concat $gt_paths_from $gt_paths_to]
puts "  Total GT paths: [llength $gt_all_paths]\n"

if {[llength $gt_all_paths] == 0} {
    puts "  No tight GT inter-SLR paths found."
} else {

# ---- 9c: Filter for cross-SLR, extract nets ----
array unset gt_net_map

set gt_cross_slr_count 0

foreach path $gt_all_paths {
    set sp_pin  [get_property STARTPOINT_PIN $path]
    set ep_pin  [get_property ENDPOINT_PIN   $path]
    set slack   [get_property SLACK          $path]

    set sp_cell [get_cells -of_objects [get_pins $sp_pin] -quiet]
    set ep_cell [get_cells -of_objects [get_pins $ep_pin] -quiet]
    if {[llength $sp_cell] == 0 || [llength $ep_cell] == 0} continue

    set sp_slr [get_property SLR_INDEX $sp_cell -quiet]
    set ep_slr [get_property SLR_INDEX $ep_cell -quiet]

    # Only cross-SLR paths
    if {$sp_slr eq "" || $ep_slr eq "" || $sp_slr == $ep_slr} continue
    incr gt_cross_slr_count

    set sp_name [get_property NAME $sp_cell]
    set ep_name [get_property NAME $ep_cell]

    # Skip when both endpoints already assigned to the SAME SLR via STEP 6/6b
    set sp_asgn [_resolve_assigned_slr $sp_name]
    set ep_asgn [_resolve_assigned_slr $ep_name]
    if {$sp_asgn ne "" && $ep_asgn ne "" && $sp_asgn eq $ep_asgn} continue

    # Extract nets
    set path_nets [get_nets -of_objects $path -quiet]
    foreach net $path_nets {
        set net_name [get_property NAME $net]

        if {![info exists gt_net_map($net_name)]} {
            set gt_net_map($net_name) [list $slack $sp_name $ep_name]
        } else {
            set prev_slack [lindex $gt_net_map($net_name) 0]
            if {$slack < $prev_slack} {
                set gt_net_map($net_name) [list $slack $sp_name $ep_name]
            }
        }
    }
}

set gt_unique_nets [llength [array names gt_net_map]]
puts "  Anchor cross-SLR paths: $gt_cross_slr_count"
puts "  Unique anchor inter-SLR nets: $gt_unique_nets"

if {$gt_unique_nets > 0} {
    set xdc_fp [open $OUTPUT_XDC a]
    set rpt_fp [open $OUTPUT_RPT a]

    puts $xdc_fp ""
    puts $xdc_fp "################################################################################"
    puts $xdc_fp "# STEP 7: Anchor-Aware Inter-SLR Constraint Hardening"
    puts $xdc_fp "#"
    puts $xdc_fp "# Nets connect anchor primitives (GT/XCVR, PCIE/CPM, MMCM, BRAM, URAM,"
    puts $xdc_fp "# DSP, DCMAC, MRMAC) to other cells across SLR boundaries. These"
    puts $xdc_fp "# anchors are fixed-location or placement-sensitive — apply"
    puts $xdc_fp "# USER_CROSSING_SLR 0 to keep both endpoints in the same SLR."
    puts $xdc_fp "#"
    puts $xdc_fp "# Total anchor cross-SLR nets constrained: $gt_unique_nets"
    puts $xdc_fp "################################################################################"
    puts $xdc_fp ""


    puts $rpt_fp ""
    puts $rpt_fp "================================================================================"
    puts $rpt_fp " STEP 7: Anchor-Aware Inter-SLR Constraint Hardening"
    puts $rpt_fp "================================================================================"
    puts $rpt_fp "  Anchor primitives: [llength $gt_all_cells]"
    puts $rpt_fp "  Cross-SLR anchor paths: $gt_cross_slr_count"
    puts $rpt_fp "  Unique nets constrained: $gt_unique_nets"
    puts $rpt_fp ""

    # Sort by worst slack
    set gt_sorted_nets {}
    foreach net_name [array names gt_net_map] {
        lassign $gt_net_map($net_name) slack src dst
        lappend gt_sorted_nets [list $net_name $slack $src $dst]
    }
    set gt_sorted_nets [lsort -real -index 1 $gt_sorted_nets]

    foreach entry $gt_sorted_nets {
        lassign $entry net_name slack src_name dst_name
        puts $xdc_fp "# Anchor inter-SLR | worst slack: [format %.3f $slack]"
        puts $xdc_fp "#   src: [string range $src_name 0 89]"
        puts $xdc_fp "#   dst: [string range $dst_name 0 89]"
        puts $xdc_fp "catch { set_property USER_CROSSING_SLR 0 \[get_nets \{$net_name\}\] }"
        lappend command "set_property USER_CROSSING_SLR 0 \[get_nets \{$net_name\}\]"
        puts $xdc_fp ""


        puts $rpt_fp "    NET: $net_name  slack=[format %.3f $slack]"
        incr step9_net_count
    }

    close $xdc_fp
    close $rpt_fp
}

;# end of gt_all_paths > 0
}

;# end of gt_all_cells > 0
}

;# end of !is_mono_device
}

puts "\n  ================================================================="
puts "  STEP 7 Summary"
puts "  ================================================================="
if {[info exists gt_all_cells]} {
    puts "  Anchor primitive cells          : [llength $gt_all_cells]"
} else {
    puts "  Anchor primitive cells          : 0 (skipped: mono-SLR device)"
}
puts "  Anchor inter-SLR nets constrained: $step9_net_count"
puts ""

###############################################################################
# STEP 7.5: Top-N timing path SLR-crossing analysis (with cell-category
#           breakdown)
#
# Walks the worst-N timing paths and:
#   - classifies each as crossing an SLR boundary or not
#   - records per-path REF_NAME for src/dst, logic levels, path group, status
#   - aggregates cross-SLR paths by (source-cell-family -> destination-cell-
#     family), with per-category WNS / min / max / avg logic levels
#
# Produces:
#   - slr_crossing_top1000_summary.rpt  (plain-text audit, all sections)
#   - Stats stored in script variables (consumed by the HTML report below)
###############################################################################
set TOP_PATHS_N         1000
set TOP_PATHS_RPT       "slr_crossing_top1000_summary.rpt"

set _topn_total         0
set _topn_cross         0
set _topn_viol_cross    0
set _topn_met_cross     0
set _topn_pair_counts   [dict create]   ;# "srcSLR->dstSLR" -> count
set _topn_pair_wns      [dict create]   ;# "srcSLR->dstSLR" -> worst slack
set _topn_worst         [list]          ;# top-20 worst cross-SLR (full info)
set _topn_cat_stats     [dict create]   ;# "SRC_CAT -> DST_CAT" -> {count wns min_ll max_ll sum_ll viol_cnt}
set _clk_period_cache   [dict create]   ;# clock name -> PERIOD (ns) requirement

# ---------------------------------------------------------------------------
# Helper: classify a Vivado REF_NAME into a coarse cell family
# (FLOP, SRL, BRAM, URAM, LUTRAM, DSP, GT, MAC, PCIE, CLK, IO, LUT, HARDIP,
# OTHER, UNKNOWN). Mirrors qor_detailed_html.py.
# ---------------------------------------------------------------------------
proc _slrx_cell_category {ref_name} {
    if {$ref_name eq ""} { return "UNKNOWN" }
    set u [string toupper $ref_name]
    if {[regexp {^FD[CRPS]?E?$|^FDPE?$|^FDSE?$|^FDCE?$|^FDRE?$|^FF$|^LDC?E?$|^IDDR.*$|^ODDR.*$|^CFF.*$|^XCVR.*FF$} $u]} { return "FLOP" }
    if {[regexp {^SRL\d+.*$|^SRLC\d+.*$} $u]} { return "SRL" }
    if {[regexp {^RAMB\d+.*$|^BRAM.*$|^FIFO\d+.*$} $u]} { return "BRAM" }
    if {[regexp {^URAM.*$} $u]} { return "URAM" }
    if {[regexp {^RAMD.*$|^RAMS.*$|^DRAM.*$} $u]} { return "LUTRAM" }
    if {[regexp {^DSP.*$} $u]} { return "DSP" }
    if {[regexp {^GT[A-Z]+.*$|^BUFG_GT.*$|^[IO]?BUFDS_GTE.*$} $u]} { return "GT" }
    if {[regexp {^DCMAC.*$|^MRMAC.*$|^CMAC.*$} $u]} { return "MAC" }
    if {[regexp {^PCIE.*$|^CPM.*$} $u]} { return "PCIE" }
    if {[regexp {^MMCM.*$|^PLL.*$|^BUFG.*$|^BUFGCE.*$|^MBUFG.*$} $u]} { return "CLK" }
    if {[regexp {^I[OB]?BUF.*$|^O[OB]?BUF.*$|^DIFF.*$|^XPIO.*$|^IBUFDS.*$|^OBUFDS.*$|^IOB.*$|^OBUF.*$} $u]} { return "IO" }
    if {[regexp {^LUT\d+.*$} $u]} { return "LUT" }
    if {[regexp {^NOC.*$|^HBM.*$|^SYSMON.*$|^AIE.*$|^VCU.*$|^VDU.*$|^PS.*$|^RPU.*$|^APU.*$|^HSC.*$} $u]} { return "HARDIP" }
    return "OTHER"
}

puts "\n========================================================================="
puts " STEP 7.5: Top-$TOP_PATHS_N Path SLR-Crossing Analysis"
puts "=========================================================================\n"

set _slrs_for_topn [get_slrs -quiet]
if {[llength $_slrs_for_topn] <= 1} {
    puts "  INFO: Mono-SLR device - skipping top-path SLR-crossing analysis."
    set _topn_skipped 1
    set _topn_skip_reason "Mono-SLR device - no SLR crossings possible."
    if {[catch {
        set _trf [open $TOP_PATHS_RPT "w"]
        puts $_trf "Mono-SLR device - no SLR crossing paths possible."
        close $_trf
    } _msg]} { puts "  WARNING: unable to write $TOP_PATHS_RPT: $_msg" }
} else {
    set _topn_skipped 0
    set _topn_skip_reason ""

    puts "  Collecting worst-$TOP_PATHS_N timing paths ..."
    set _paths [get_timing_paths -max_paths $TOP_PATHS_N -sort_by slack]
    set _topn_total [llength $_paths]
    puts "  Got $_topn_total paths.  Classifying SLR crossings and cell families ..."

    set _topn_cross_paths [list]            ;# list of dicts (slack, sslr, dslr, sref, dref, ll, group, sname, dname, status)
    set _full_records     [list]            ;# parallel list for FULL PATH LIST section
    set _idx 0
    foreach _p $_paths {
        incr _idx
        set _slack [get_property -quiet SLACK $_p]
        if {$_slack eq ""} { set _slack 0.0 }
        set _spin  [get_property -quiet STARTPOINT_PIN $_p]
        set _dpin  [get_property -quiet ENDPOINT_PIN   $_p]
        set _scell [get_cells -quiet -of_objects [get_pins -quiet $_spin]]
        set _dcell [get_cells -quiet -of_objects [get_pins -quiet $_dpin]]
        set _sslr "" ; set _dslr ""
        set _sname ""; set _dname ""
        set _sref ""; set _dref ""
        if {[llength $_scell] > 0} {
            set _sslr  [get_property -quiet SLR_INDEX $_scell]
            set _sname [get_property -quiet NAME      $_scell]
            set _sref  [get_property -quiet REF_NAME  $_scell]
        }
        if {[llength $_dcell] > 0} {
            set _dslr  [get_property -quiet SLR_INDEX $_dcell]
            set _dname [get_property -quiet NAME      $_dcell]
            set _dref  [get_property -quiet REF_NAME  $_dcell]
        }
        set _ll   [get_property -quiet LOGIC_LEVELS $_p]
        if {$_ll eq ""} { set _ll 0 }
        set _grp  [get_property -quiet GROUP $_p]
        if {$_grp eq ""} { set _grp "-" }
        set _clk  [get_property -quiet STARTPOINT_CLOCK $_p]
        if {$_clk eq ""} { set _clk [get_property -quiet ENDPOINT_CLOCK $_p] }
        if {$_clk eq ""} { set _clk $_grp }
        if {$_clk eq ""} { set _clk "-" }
        set _req "-"
        if {$_clk ne "-" && $_clk ne ""} {
            if {[dict exists $_clk_period_cache $_clk]} {
                set _req [dict get $_clk_period_cache $_clk]
            } else {
                set _pclk [get_clocks -quiet $_clk]
                if {[llength $_pclk] > 0} {
                    set _req [get_property -quiet PERIOD $_pclk]
                }
                if {$_req eq ""} { set _req "-" }
                dict set _clk_period_cache $_clk $_req
            }
        }
        set _status "MET"
        if {$_slack < 0} { set _status "VIOLATED" }

        set _scat [_slrx_cell_category $_sref]
        set _dcat [_slrx_cell_category $_dref]

        set _cross "NO"
        if {$_sslr ne "" && $_dslr ne "" && $_sslr ne $_dslr} {
            set _cross "YES"
            incr _topn_cross
            if {$_status eq "VIOLATED"} { incr _topn_viol_cross } else { incr _topn_met_cross }

            set _pair "${_sslr}->${_dslr}"
            if {[dict exists $_topn_pair_counts $_pair]} {
                dict set _topn_pair_counts $_pair [expr {[dict get $_topn_pair_counts $_pair] + 1}]
                set _old_w [dict get $_topn_pair_wns $_pair]
                if {$_slack < $_old_w} { dict set _topn_pair_wns $_pair $_slack }
            } else {
                dict set _topn_pair_counts $_pair 1
                dict set _topn_pair_wns    $_pair $_slack
            }

            # category aggregation (cross-SLR only)
            set _ck "${_scat} -> ${_dcat}"
            if {[dict exists $_topn_cat_stats $_ck]} {
                set _cs [dict get $_topn_cat_stats $_ck]
                dict set _cs count    [expr {[dict get $_cs count] + 1}]
                dict set _cs sum_ll   [expr {[dict get $_cs sum_ll] + $_ll}]
                if {$_slack < [dict get $_cs wns]}    { dict set _cs wns    $_slack }
                if {$_ll    < [dict get $_cs min_ll]} { dict set _cs min_ll $_ll }
                if {$_ll    > [dict get $_cs max_ll]} { dict set _cs max_ll $_ll }
                if {$_status eq "VIOLATED"} {
                    dict set _cs viol_cnt [expr {[dict get $_cs viol_cnt] + 1}]
                }
                set _cl [dict get $_cs clocks]
                dict set _cl $_clk 1
                dict set _cs clocks $_cl
                dict set _topn_cat_stats $_ck $_cs
            } else {
                set _viol_init 0
                if {$_status eq "VIOLATED"} { set _viol_init 1 }
                dict set _topn_cat_stats $_ck [dict create \
                    count 1 wns $_slack \
                    min_ll $_ll max_ll $_ll sum_ll $_ll \
                    viol_cnt $_viol_init \
                    example_sname $_sname example_dname $_dname \
                    example_clock $_clk example_req $_req clocks [dict create $_clk 1]]
            }

            lappend _topn_cross_paths [dict create \
                idx $_idx slack $_slack sslr $_sslr dslr $_dslr \
                sref $_sref dref $_dref scat $_scat dcat $_dcat \
                ll $_ll group $_grp status $_status \
                sname $_sname dname $_dname]
        }

        lappend _full_records [dict create \
            idx $_idx slack $_slack sslr $_sslr dslr $_dslr cross $_cross \
            sref $_sref dref $_dref scat $_scat dcat $_dcat \
            ll $_ll group $_grp status $_status \
            sname $_sname dname $_dname]
    }

    set _topn_pct 0.0
    if {$_topn_total > 0} {
        set _topn_pct [expr {100.0 * $_topn_cross / $_topn_total}]
    }

    set _trf [open $TOP_PATHS_RPT "w"]
    puts $_trf "###############################################################################"
    puts $_trf "# SLR Crossing Summary - Top $TOP_PATHS_N Timing Paths (Post-Route)"
    puts $_trf "# Generated: [_safe_timestamp]"
    puts $_trf "# Design State: Routed"
    puts $_trf "###############################################################################"
    puts $_trf ""
    puts $_trf "==============================================================================="
    puts $_trf " OVERALL SUMMARY"
    puts $_trf "==============================================================================="
    puts $_trf ""
    puts $_trf [format "  %-40s: %d" "Total paths analyzed"            $_topn_total]
    puts $_trf [format "  %-40s: %d" "Paths crossing SLR boundary"     $_topn_cross]
    puts $_trf [format "  %-40s: %d" "Paths NOT crossing SLR boundary" [expr {$_topn_total - $_topn_cross}]]
    puts $_trf [format "  %-40s: %.1f%%" "SLR crossing percentage"     $_topn_pct]
    puts $_trf ""
    puts $_trf [format "  %-40s: %d" "Cross-SLR paths with timing violation" $_topn_viol_cross]
    puts $_trf [format "  %-40s: %d" "Cross-SLR paths with timing met"       $_topn_met_cross]
    puts $_trf ""

    puts $_trf "==============================================================================="
    puts $_trf " SLR CROSSING BREAKDOWN BY SLR PAIR"
    puts $_trf "==============================================================================="
    puts $_trf ""
    puts $_trf [format "  %-20s %-10s %-15s" "SLR Pair" "Count" "Worst Slack(ns)"]
    puts $_trf "  [string repeat - 48]"
    foreach _pair [lsort [dict keys $_topn_pair_counts]] {
        set _cnt [dict get $_topn_pair_counts $_pair]
        set _wp  [dict get $_topn_pair_wns    $_pair]
        puts $_trf [format "  %-20s %-10d %-15s" $_pair $_cnt [format %.3f $_wp]]
    }
    puts $_trf ""

    # -------------------- CATEGORY BREAKDOWN --------------------
    puts $_trf "==============================================================================="
    puts $_trf " CATEGORY BREAKDOWN (Cross-SLR paths, by source-cell -> destination-cell family)"
    puts $_trf "==============================================================================="
    puts $_trf ""
    if {[dict size $_topn_cat_stats] == 0} {
        puts $_trf "  (No cross-SLR paths)"
    } else {
        puts $_trf [format "  %-30s %-8s %-10s %-8s %-7s %-7s %-7s %-9s %-22s %-12s" \
                    "Source -> Destination" "Count" "WNS(ns)" "Viol" "MinLL" "MaxLL" "AvgLL" "Viol%" "Clock Name" "Requirement"]
        puts $_trf "  [string repeat - 118]"

        # Sort categories by count desc
        set _cat_keys [list]
        dict for {_k _v} $_topn_cat_stats {
            lappend _cat_keys [list $_k [dict get $_v count]]
        }
        set _cat_keys [lsort -decreasing -integer -index 1 $_cat_keys]
        foreach _row $_cat_keys {
            set _k [lindex $_row 0]
            set _v [dict get $_topn_cat_stats $_k]
            set _cnt    [dict get $_v count]
            set _wns    [dict get $_v wns]
            set _vc     [dict get $_v viol_cnt]
            set _minll  [dict get $_v min_ll]
            set _maxll  [dict get $_v max_ll]
            set _avgll  [expr {1.0 * [dict get $_v sum_ll] / $_cnt}]
            set _vpct   [expr {100.0 * $_vc / $_cnt}]
            set _exclk  [dict get $_v example_clock]
            set _nclk   [dict size [dict get $_v clocks]]
            set _clkdisp $_exclk
            if {$_nclk > 1} { set _clkdisp "$_exclk (+[expr {$_nclk - 1}])" }
            if {[string length $_clkdisp] > 22} { set _clkdisp "[string range $_clkdisp 0 18]..." }
            set _exreq  [dict get $_v example_req]
            set _reqdisp $_exreq
            if {$_exreq ne "-" && [string is double -strict $_exreq]} {
                set _reqdisp [format %.3f $_exreq]
            }
            puts $_trf [format "  %-30s %-8d %-10s %-8d %-7d %-7d %-7s %-9s %-22s %-12s" \
                        $_k $_cnt [format %.3f $_wns] $_vc $_minll $_maxll \
                        [format %.1f $_avgll] [format "%.0f%%" $_vpct] $_clkdisp $_reqdisp]
        }
        puts $_trf ""

        # Per-category example (worst path's full src/dst cell names)
        puts $_trf "  Example paths per category (worst slack of each):"
        puts $_trf ""
        foreach _row $_cat_keys {
            set _k [lindex $_row 0]
            set _v [dict get $_topn_cat_stats $_k]
            set _es ""
            set _ed ""
            if {[dict exists $_v example_sname]} { set _es [dict get $_v example_sname] }
            if {[dict exists $_v example_dname]} { set _ed [dict get $_v example_dname] }
            set _wns_fmt [format %.3f [dict get $_v wns]]
            set _maxll   [dict get $_v max_ll]
            puts $_trf "    \[$_k\] WNS=${_wns_fmt}ns MaxLL=${_maxll}"
            puts $_trf "      src: $_es"
            puts $_trf "      dst: $_ed"
        }
    }
    puts $_trf ""

    # -------------------- TOP CROSS-SLR PATHS --------------------
    puts $_trf "==============================================================================="
    puts $_trf " TOP CROSS-SLR PATHS (worst slack first)"
    puts $_trf "==============================================================================="
    puts $_trf ""
    set _show [expr {min(50, [llength $_topn_cross_paths])}]
    if {$_show == 0} {
        puts $_trf "  (none)"
    } else {
        puts $_trf [format "  %-10s %-6s %-6s %-7s %-14s %-14s %-22s" \
                    "Slack(ns)" "SrcSLR" "DstSLR" "Levels" "SrcRef" "DstRef" "Path Group"]
        puts $_trf "  [string repeat - 90]"
        for {set _i 0} {$_i < $_show} {incr _i} {
            set _cp [lindex $_topn_cross_paths $_i]
            puts $_trf [format "  %-10s %-6s %-6s %-7s %-14s %-14s %-22s" \
                        [format %.3f [dict get $_cp slack]] \
                        [dict get $_cp sslr] [dict get $_cp dslr] \
                        [dict get $_cp ll] \
                        [dict get $_cp sref] [dict get $_cp dref] \
                        [string range [dict get $_cp group] 0 21]]
            # legacy 6-tuple format for downstream STEP 8 HTML consumer
            lappend _topn_worst [list \
                [dict get $_cp idx] [dict get $_cp slack] \
                [dict get $_cp sslr] [dict get $_cp dslr] \
                [dict get $_cp sname] [dict get $_cp dname]]
        }
        puts $_trf ""

        # full cell names for the top-20 worst (so users can locate the cells)
        set _ncells [expr {min(20, [llength $_topn_cross_paths])}]
        puts $_trf "  Full cell names (top $_ncells):"
        puts $_trf ""
        for {set _i 0} {$_i < $_ncells} {incr _i} {
            set _cp [lindex $_topn_cross_paths $_i]
            puts $_trf "  [expr {$_i+1}]. slack=[format %.3f [dict get $_cp slack]]ns  [dict get $_cp scat] -> [dict get $_cp dcat]  (LL=[dict get $_cp ll], group=[dict get $_cp group])"
            puts $_trf "      src ([dict get $_cp sref]): [dict get $_cp sname]"
            puts $_trf "      dst ([dict get $_cp dref]): [dict get $_cp dname]"
        }
    }
    puts $_trf ""

    # -------------------- FULL PATH LIST --------------------
    puts $_trf "==============================================================================="
    puts $_trf " FULL PATH LIST (all $_topn_total paths analyzed)"
    puts $_trf "==============================================================================="
    puts $_trf ""
    puts $_trf [format "  %-5s %-10s %-9s %-5s %-6s %-6s %-7s %-14s %-14s %-18s %s" \
                "#" "Slack(ns)" "Status" "Cross" "SrcSLR" "DstSLR" "Levels" \
                "SrcRef" "DstRef" "PathGroup" "Source -> Dest"]
    puts $_trf "  [string repeat - 160]"
    foreach _r $_full_records {
        set _src_short [dict get $_r sname]
        set _dst_short [dict get $_r dname]
        if {[string length $_src_short] > 55} { set _src_short "...[string range $_src_short end-52 end]" }
        if {[string length $_dst_short] > 55} { set _dst_short "...[string range $_dst_short end-52 end]" }
        puts $_trf [format "  %-5d %-10s %-9s %-5s %-6s %-6s %-7s %-14s %-14s %-18s %s -> %s" \
                    [dict get $_r idx] \
                    [format %.3f [dict get $_r slack]] \
                    [dict get $_r status] \
                    [dict get $_r cross] \
                    [dict get $_r sslr] [dict get $_r dslr] \
                    [dict get $_r ll] \
                    [dict get $_r sref] [dict get $_r dref] \
                    [string range [dict get $_r group] 0 17] \
                    $_src_short $_dst_short]
    }
    puts $_trf ""
    puts $_trf "###############################################################################"
    puts $_trf "# END OF REPORT"
    puts $_trf "###############################################################################"
    close $_trf
    puts "  Report written: $TOP_PATHS_RPT"
    puts "  Top-$TOP_PATHS_N paths: $_topn_total | Cross-SLR: $_topn_cross ([format %.1f $_topn_pct]%)"
    puts "  Category breakdown : [dict size $_topn_cat_stats] distinct src->dst families"
}
puts ""

###############################################################################
# STEP 8: Generate Visual Dataflow Diagram (HTML)
#
# Self-contained HTML file showing:
#   - DONT_TOUCH/MARK_DEBUG pre-step status
#   - Modules grouped by SLR assignment (color-coded boxes)
#   - Skipped modules with reasons (grey/striped boxes)
#   - Neighbor/pipeline connectivity lines
#   - Threshold decision details per module
#   - Top-$TOP_PATHS_N SLR-crossing path summary
###############################################################################
set OUTPUT_DIAGRAM "slr_assignment_diagram.html"
puts "\n========================================================================="
puts " STEP 8: Generating Visual Dataflow Diagram: $OUTPUT_DIAGRAM"
puts "=========================================================================\n"

set _diag_fp [open $OUTPUT_DIAGRAM w]

# Helper: short module name (last 2 hierarchy levels)
proc _short_mod_name {full_name} {
    set parts [split $full_name "/"]
    set n [llength $parts]
    if {$n <= 2} { return $full_name }
    return "[lindex $parts end-1]/[lindex $parts end]"
}

# Determine SLR set from assigned modules
set _slr_set [dict create]
foreach mentry $_diag_modules {
    set mslr [lindex $mentry 2]
    if {$mslr ne ""} { dict set _slr_set $mslr 1 }
}
set _slr_names [lsort [dict keys $_slr_set]]
if {[llength $_slr_names] == 0} { set _slr_names {SLR0 SLR1} }

set _slr_colors [dict create \
    SLR0 "#e74c3c" SLR1 "#2980b9" SLR2 "#27ae60" SLR3 "#f39c12" \
    SLR4 "#8e44ad" SLR5 "#1abc9c"]
set _slr_bg [dict create \
    SLR0 "#fdeaea" SLR1 "#e8f4fd" SLR2 "#e8f8f0" SLR3 "#fef9e7" \
    SLR4 "#f4ecf7" SLR5 "#e8faf6"]

puts $_diag_fp {<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>SLR Assignment Dataflow Diagram</title>
<style>
body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background: #f5f5f5; }
h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
h2 { color: #34495e; margin-top: 30px; }
.diagram-container { background: white; border: 2px solid #333; border-radius: 8px; padding: 30px; margin: 20px 0; overflow-x: auto; }
.slr-lane { border: 2px dashed #999; border-radius: 6px; padding: 15px; margin: 10px 0; min-height: 80px; }
.slr-label { font-weight: bold; font-size: 16px; margin-bottom: 10px; }
.module-box { display: inline-block; border: 3px solid; border-radius: 5px; padding: 8px 12px; margin: 6px; vertical-align: top; max-width: 300px; font-size: 12px; }
.module-name { font-weight: bold; word-break: break-all; font-size: 13px; }
.module-info { color: #555; font-size: 11px; margin-top: 4px; }
.module-skip { background: repeating-linear-gradient(45deg, #f0f0f0, #f0f0f0 5px, #e0e0e0 5px, #e0e0e0 10px); border-color: #999; opacity: 0.85; }
.module-skip .module-name { color: #777; text-decoration: line-through; }
.badge { display: inline-block; padding: 2px 6px; border-radius: 3px; font-size: 10px; font-weight: bold; color: white; margin-left: 4px; }
.badge-step6 { background: #3498db; }
.badge-step6b { background: #e67e22; }
.badge-skip { background: #95a5a6; }
.conn-line { padding: 4px 0; font-size: 13px; }
.conn-arrow { color: #e74c3c; font-weight: bold; }
.threshold-table { border-collapse: collapse; width: 100%; margin: 15px 0; font-size: 12px; }
.threshold-table th { background: #2c3e50; color: white; padding: 8px 10px; text-align: left; }
.threshold-table td { padding: 6px 10px; border-bottom: 1px solid #ddd; }
.threshold-table tr:nth-child(even) { background: #f9f9f9; }
.threshold-table tr.row-assign { background: #e8f8f0; }
.threshold-table tr.row-skip { background: #fdeaea; }
.legend { display: flex; flex-wrap: wrap; gap: 15px; margin: 15px 0; padding: 10px; background: #fff; border: 1px solid #ddd; border-radius: 5px; }
.legend-item { display: flex; align-items: center; gap: 5px; font-size: 13px; }
.legend-color { width: 20px; height: 20px; border: 2px solid #333; border-radius: 3px; }
.param-box { background: #2c3e50; color: #ecf0f1; padding: 15px; border-radius: 6px; font-family: monospace; font-size: 13px; margin: 10px 0; }
.param-box .param-name { color: #3498db; }
.param-box .param-val { color: #2ecc71; }
.summary-cards { display: flex; flex-wrap: wrap; gap: 15px; margin: 15px 0; }
.card { background: white; border: 1px solid #ddd; border-radius: 8px; padding: 15px; min-width: 150px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
.card-number { font-size: 28px; font-weight: bold; }
.card-label { font-size: 12px; color: #7f8c8d; margin-top: 5px; }
</style>
</head>
<body>}

puts $_diag_fp "<h1>SLR Assignment Dataflow Diagram</h1>"
puts $_diag_fp "<p><strong>Generated by:</strong> auto_suggest_slr_pblock_aware.tcl &mdash; [_safe_timestamp]</p>"

# Active parameters
puts $_diag_fp "<h2>Active Threshold Parameters</h2>"
puts $_diag_fp "<div class='param-box'>"
puts $_diag_fp "<span class='param-name'>CROSSING_THRESHOLD</span>    = <span class='param-val'>$CROSSING_THRESHOLD</span><br>"
puts $_diag_fp "<span class='param-name'>DOMINANCE_PCT</span>         = <span class='param-val'>${DOMINANCE_PCT}%</span><br>"
puts $_diag_fp "<span class='param-name'>MIN_CHILD_CROSSINGS</span>   = <span class='param-val'>$MIN_CHILD_CROSSINGS</span><br>"
puts $_diag_fp "<span class='param-name'>MAX_DRILL_DEPTH</span>       = <span class='param-val'>$MAX_DRILL_DEPTH</span><br>"
puts $_diag_fp "<span class='param-name'>NEIGHBOR_CONN_THRESH</span>  = <span class='param-val'>$NEIGHBOR_CONN_THRESH</span><br>"
puts $_diag_fp "<span class='param-name'>NEIGHBOR_MAX_SPLIT</span>    = <span class='param-val'>${NEIGHBOR_MAX_SPLIT}%</span>"
puts $_diag_fp "</div>"

# Summary cards
set _n_assigned 0
set _n_skipped  0
foreach mentry $_diag_modules {
    if {[lindex $mentry 1] eq "assign"} { incr _n_assigned } else { incr _n_skipped }
}
puts $_diag_fp "<h2>Summary</h2>"
puts $_diag_fp "<div class='summary-cards'>"
puts $_diag_fp "  <div class='card'><div class='card-number' style='color:#27ae60'>$_n_assigned</div><div class='card-label'>Modules Assigned</div></div>"
puts $_diag_fp "  <div class='card'><div class='card-number' style='color:#e74c3c'>$_n_skipped</div><div class='card-label'>Modules Skipped</div></div>"
puts $_diag_fp "  <div class='card'><div class='card-number' style='color:#2980b9'>[llength $_diag_connections]</div><div class='card-label'>Neighbor Connections</div></div>"
puts $_diag_fp "  <div class='card'><div class='card-number' style='color:#f39c12'>$pipeline_reg_count</div><div class='card-label'>Pipeline Regs Assigned</div></div>"
puts $_diag_fp "  <div class='card'><div class='card-number' style='color:#8e44ad'>$step9_net_count</div><div class='card-label'>Anchor Nets Constrained</div></div>"
puts $_diag_fp "  <div class='card'><div class='card-number' style='color:#16a085'>$_topn_total</div><div class='card-label'>Top-$TOP_PATHS_N Paths</div></div>"
puts $_diag_fp "  <div class='card'><div class='card-number' style='color:#c0392b'>$_topn_cross</div><div class='card-label'>Cross-SLR Paths (top-$TOP_PATHS_N)</div></div>"
puts $_diag_fp "</div>"

# ===== DONT_TOUCH / MARK_DEBUG pre-step status block ==========================
set _dt_panel_color "#27ae60"
set _dt_panel_bg    "#eafaf1"
set _dt_panel_title "OK: No DONT_TOUCH / MARK_DEBUG found"
set _dt_panel_msg   "Design is free of DT/MD - script ran the full SLR partitioning flow."
if {$_dt_md_status eq "REMOVAL_ONLY"} {
    set _dt_panel_color "#d68910"
    set _dt_panel_bg    "#fef9e7"
    set _dt_panel_title "DT/MD present (NOT on SLR crossings) - no removal XDC needed"
    set _dt_panel_msg   "DONT_TOUCH / MARK_DEBUG properties were found but they do not sit on SLR-crossing nets. No removal XDC written. SLR partitioning continued normally."
} elseif {$_dt_md_status eq "REMOVAL_CONTINUE"} {
    set _dt_panel_color "#d68910"
    set _dt_panel_bg    "#fef9e7"
    set _dt_panel_title "DT/MD on SLR crossings - removal XDC emitted, SLR analysis CONTINUED"
    set _dt_panel_msg   "DONT_TOUCH / MARK_DEBUG found on SLR-crossing nets/drivers. Removal XDC written (<code>$_dt_md_output_xdc</code>). SLR partitioning continued (no early exit).<br>Source <code>$_dt_md_output_xdc</code> BEFORE place_design to unlock Physopt replication."
}
puts $_diag_fp "<h2>DONT_TOUCH / MARK_DEBUG pre-check</h2>"
puts $_diag_fp "<div style='border-left:6px solid $_dt_panel_color;background:$_dt_panel_bg;padding:12px 16px;border-radius:4px;'>"
puts $_diag_fp "  <div style='font-weight:bold;color:$_dt_panel_color;margin-bottom:6px;'>Status: $_dt_md_status &mdash; $_dt_panel_title</div>"
puts $_diag_fp "  <div style='color:#333;'>$_dt_panel_msg</div>"
puts $_diag_fp "</div>"
if {$_dt_md_status ne "NONE"} {
    puts $_diag_fp "<table class='threshold-table' style='margin-top:10px;'>"
    puts $_diag_fp "<tr><th>Inventory</th><th>Cross-SLR</th><th>Total in design</th></tr>"
    puts $_diag_fp "<tr><td>DONT_TOUCH nets</td><td>$_dt_net_count</td><td>$_all_dt_net_count</td></tr>"
    puts $_diag_fp "<tr><td>MARK_DEBUG nets</td><td>$_md_net_count</td><td>$_all_md_net_count</td></tr>"
    puts $_diag_fp "<tr><td>DONT_TOUCH cells</td><td>$_dt_cell_count</td><td>$_all_dt_cell_count</td></tr>"
    puts $_diag_fp "<tr><td>MARK_DEBUG cells</td><td>$_md_cell_count</td><td>$_all_md_cell_count</td></tr>"
    puts $_diag_fp "</table>"
}

# Legend
puts $_diag_fp "<div class='legend'>"
foreach sn $_slr_names {
    set sc "#999"
    if {[dict exists $_slr_colors $sn]} { set sc [dict get $_slr_colors $sn] }
    puts $_diag_fp "  <div class='legend-item'><div class='legend-color' style='background:$sc;'></div> $sn (assigned)</div>"
}
puts $_diag_fp "  <div class='legend-item'><div class='legend-color' style='background: repeating-linear-gradient(45deg, #f0f0f0, #f0f0f0 3px, #e0e0e0 3px, #e0e0e0 6px); border-color:#999;'></div> Skipped</div>"
puts $_diag_fp "  <div class='legend-item'><span class='badge badge-step6'>STEP6</span> Primary assignment</div>"
puts $_diag_fp "  <div class='legend-item'><span class='badge badge-step6b'>STEP6b</span> Neighbor co-assignment</div>"
puts $_diag_fp "</div>"

# Diagram: modules grouped by SLR
puts $_diag_fp "<h2>Dataflow Connectivity Diagram</h2>"
puts $_diag_fp "<div class='diagram-container'>"

set _slr_modules [dict create]
set _skip_modules [list]
foreach mentry $_diag_modules {
    set mname   [lindex $mentry 0]
    set maction [lindex $mentry 1]
    set mslr    [lindex $mentry 2]
    if {$maction eq "assign" && $mslr ne ""} {
        if {![dict exists $_slr_modules $mslr]} { dict set _slr_modules $mslr [list] }
        dict lappend _slr_modules $mslr $mentry
    } else {
        lappend _skip_modules $mentry
    }
}

foreach sn [lsort [dict keys $_slr_modules]] {
    set sc "#999"; set sb "#f9f9f9"
    if {[dict exists $_slr_colors $sn]} { set sc [dict get $_slr_colors $sn] }
    if {[dict exists $_slr_bg $sn]}     { set sb [dict get $_slr_bg $sn] }

    puts $_diag_fp "  <div class='slr-lane' style='border-color:$sc; background:$sb;'>"
    puts $_diag_fp "    <div class='slr-label' style='color:$sc;'>&#9632; $sn</div>"

    foreach mentry [dict get $_slr_modules $sn] {
        set mname     [lindex $mentry 0]
        set mcross    [lindex $mentry 3]
        set mcells    [lindex $mentry 4]
        set mminority [lindex $mentry 5]
        set mmajpct   [lindex $mentry 6]
        set msource   [lindex $mentry 9]
        set mparent   [lindex $mentry 10]

        set badge_class "badge-step6"
        set badge_text "STEP6"
        if {[string match "step6b*" $msource]} {
            set badge_class "badge-step6b"
            set badge_text "STEP6b"
        }

        set short_name [_short_mod_name $mname]

        puts $_diag_fp "    <div class='module-box' style='border-color:$sc;' title='$mname'>"
        puts $_diag_fp "      <div class='module-name' style='color:$sc;'>$short_name <span class='badge $badge_class'>$badge_text</span></div>"
        puts $_diag_fp "      <div class='module-info'>"
        puts $_diag_fp "        Cells: [format %d $mcells] | Minority: [format %d $mminority] | Majority: [format %.1f $mmajpct]%<br>"
        if {$mcross > 0} { puts $_diag_fp "        Crossings: $mcross" }
        if {$mparent ne ""} { puts $_diag_fp "        <br>Neighbor of: [_short_mod_name $mparent]" }
        puts $_diag_fp "      </div>"
        puts $_diag_fp "    </div>"
    }
    puts $_diag_fp "  </div>"
}

if {[llength $_skip_modules] > 0} {
    puts $_diag_fp "  <div class='slr-lane' style='border-color:#999; background:#fafafa;'>"
    puts $_diag_fp "    <div class='slr-label' style='color:#999;'>&#10006; SKIPPED MODULES</div>"
    foreach mentry $_skip_modules {
        set mname   [lindex $mentry 0]
        set mslr    [lindex $mentry 2]
        set mcells  [lindex $mentry 4]
        set mminor  [lindex $mentry 5]
        set mmajpct [lindex $mentry 6]
        set mreason [lindex $mentry 8]
        set short_name [_short_mod_name $mname]

        puts $_diag_fp "    <div class='module-box module-skip' title='$mname'>"
        puts $_diag_fp "      <div class='module-name'>$short_name <span class='badge badge-skip'>SKIP</span></div>"
        puts $_diag_fp "      <div class='module-info'>"
        if {$mcells > 0} { puts $_diag_fp "        Cells: [format %d $mcells] | Minority: [format %d $mminor]<br>" }
        if {$mslr ne ""} { puts $_diag_fp "        Would assign: $mslr ([format %.1f $mmajpct]%)<br>" }
        puts $_diag_fp "        <strong style='color:#c0392b;'>$mreason</strong>"
        puts $_diag_fp "      </div>"
        puts $_diag_fp "    </div>"
    }
    puts $_diag_fp "  </div>"
}
puts $_diag_fp "</div>"

# Neighbor connections
if {[llength $_diag_connections] > 0} {
    puts $_diag_fp "<h2>Neighbor Connectivity</h2>"
    puts $_diag_fp "<div>"
    foreach centry $_diag_connections {
        set cfrom     [lindex $centry 0]
        set cto       [lindex $centry 1]
        set cdirect   [lindex $centry 2]
        set cpipeline [lindex $centry 3]
        set ctype     [lindex $centry 4]

        set from_short [_short_mod_name $cfrom]
        set to_short   [_short_mod_name $cto]

        set from_slr "?"
        set to_slr   "?"
        if {[dict exists $assigned_slr_map $cfrom]} { set from_slr [dict get $assigned_slr_map $cfrom] }
        if {[dict exists $assigned_slr_map $cto]}   { set to_slr [dict get $assigned_slr_map $cto] }

        set arrow_color "#27ae60"
        if {$from_slr ne $to_slr} { set arrow_color "#e74c3c" }

        if {$ctype eq "pipeline"} {
            puts $_diag_fp "  <div class='conn-line'>"
            puts $_diag_fp "    <span style='color:$arrow_color;font-weight:bold;'>&#9654;</span>"
            puts $_diag_fp "    <strong>$from_short</strong> ($from_slr)"
            puts $_diag_fp "    <span class='conn-arrow'>&mdash;&mdash;\[ $cdirect direct + $cpipeline pipeline regs \]&mdash;&mdash;&rarr;</span>"
            puts $_diag_fp "    <strong>$to_short</strong> ($to_slr)"
            puts $_diag_fp "  </div>"
        } else {
            puts $_diag_fp "  <div class='conn-line'>"
            puts $_diag_fp "    <span style='color:$arrow_color;font-weight:bold;'>&#9654;</span>"
            puts $_diag_fp "    <strong>$from_short</strong> ($from_slr)"
            puts $_diag_fp "    <span class='conn-arrow'>&mdash;&mdash;\[ $cdirect direct connections \]&mdash;&mdash;&rarr;</span>"
            puts $_diag_fp "    <strong>$to_short</strong> ($to_slr)"
            puts $_diag_fp "  </div>"
        }
    }
    puts $_diag_fp "</div>"
}

# Threshold decision details
puts $_diag_fp "<h2>Module Decision Details</h2>"
puts $_diag_fp "<table class='threshold-table'>"
puts $_diag_fp "<tr><th>#</th><th>Module</th><th>Decision</th><th>SLR</th><th>Crossings</th><th>Cells</th><th>Minority</th><th>Majority%</th><th>Source</th><th>Reason</th></tr>"

set _row_idx 0
foreach mentry $_diag_modules {
    incr _row_idx
    set mname    [lindex $mentry 0]
    set maction  [lindex $mentry 1]
    set mslr     [lindex $mentry 2]
    set mcross   [lindex $mentry 3]
    set mcells   [lindex $mentry 4]
    set mminor   [lindex $mentry 5]
    set mmajpct  [lindex $mentry 6]
    set mreason  [lindex $mentry 8]
    set msource  [lindex $mentry 9]

    if {$maction eq "assign"} {
        set row_class "row-assign"
        set decision_html "<span style='color:#27ae60;font-weight:bold;'>&#10004; ASSIGN</span>"
    } else {
        set row_class "row-skip"
        set decision_html "<span style='color:#e74c3c;font-weight:bold;'>&#10008; SKIP</span>"
    }

    set slr_display $mslr
    if {$mslr eq ""} { set slr_display "-" }

    set source_badge "STEP6"
    set source_class "badge-step6"
    if {[string match "step6b*" $msource]} {
        set source_badge "STEP6b"
        set source_class "badge-step6b"
    }

    set short_name [_short_mod_name $mname]

    puts $_diag_fp "<tr class='$row_class' title='$mname'>"
    puts $_diag_fp "  <td>$_row_idx</td>"
    puts $_diag_fp "  <td><strong>$short_name</strong><br><small style='color:#999;'>$mname</small></td>"
    puts $_diag_fp "  <td>$decision_html</td>"
    puts $_diag_fp "  <td>$slr_display</td>"
    puts $_diag_fp "  <td>$mcross</td>"
    puts $_diag_fp "  <td>[format %d $mcells]</td>"
    puts $_diag_fp "  <td>[format %d $mminor]</td>"
    puts $_diag_fp "  <td>[format %.1f $mmajpct]%</td>"
    puts $_diag_fp "  <td><span class='badge $source_class'>$source_badge</span></td>"
    puts $_diag_fp "  <td>$mreason</td>"
    puts $_diag_fp "</tr>"
}
puts $_diag_fp "</table>"

# ===== Top-N SLR crossing path summary section ================================
puts $_diag_fp "<h2>Top-$TOP_PATHS_N Timing Path SLR-Crossing Summary</h2>"
if {[info exists _topn_skipped] && $_topn_skipped} {
    puts $_diag_fp "<div style='padding:10px;background:#eef;border-left:6px solid #2980b9;border-radius:4px;'>$_topn_skip_reason</div>"
} else {
    set _topn_pct_disp 0.0
    if {$_topn_total > 0} { set _topn_pct_disp [expr {100.0 * $_topn_cross / $_topn_total}] }
    puts $_diag_fp "<div class='summary-cards'>"
    puts $_diag_fp "  <div class='card'><div class='card-number' style='color:#16a085'>$_topn_total</div><div class='card-label'>Paths analyzed</div></div>"
    puts $_diag_fp "  <div class='card'><div class='card-number' style='color:#c0392b'>$_topn_cross</div><div class='card-label'>Cross-SLR paths</div></div>"
    puts $_diag_fp "  <div class='card'><div class='card-number' style='color:#7f8c8d'>[format %.1f $_topn_pct_disp]%</div><div class='card-label'>Cross-SLR %</div></div>"
    puts $_diag_fp "  <div class='card'><div class='card-number' style='color:#27ae60'>[expr {$_topn_total - $_topn_cross}]</div><div class='card-label'>Non-crossing</div></div>"
    puts $_diag_fp "</div>"

    if {[llength [dict keys $_topn_pair_counts]] > 0} {
        puts $_diag_fp "<h3>Crossings by SLR pair</h3>"
        puts $_diag_fp "<table class='threshold-table'><tr><th>From -> To</th><th>Count</th></tr>"
        dict for {_pair _cnt} $_topn_pair_counts {
            puts $_diag_fp "<tr><td>$_pair</td><td>$_cnt</td></tr>"
        }
        puts $_diag_fp "</table>"
    }

    if {[llength $_topn_worst] > 0} {
        puts $_diag_fp "<h3>Top [llength $_topn_worst] worst-slack cross-SLR paths</h3>"
        puts $_diag_fp "<table class='threshold-table'>"
        puts $_diag_fp "<tr><th>#</th><th>Path Idx</th><th>Slack (ns)</th><th>Src SLR</th><th>Dst SLR</th><th>Source</th><th>Destination</th></tr>"
        set _r 0
        foreach _cp $_topn_worst {
            incr _r
            puts $_diag_fp "<tr><td>$_r</td><td>[lindex $_cp 0]</td><td>[format %.3f [lindex $_cp 1]]</td><td>[lindex $_cp 2]</td><td>[lindex $_cp 3]</td><td><small>[lindex $_cp 4]</small></td><td><small>[lindex $_cp 5]</small></td></tr>"
        }
        puts $_diag_fp "</table>"
    }
    puts $_diag_fp "<p><em>Full path-by-path classification: see <code>$TOP_PATHS_RPT</code></em></p>"
}

puts $_diag_fp {</body>
</html>}

close $_diag_fp
puts "  Diagram written: $OUTPUT_DIAGRAM"
puts ""

###############################################################################
# SUMMARY
###############################################################################
puts "\n========================================================================="
puts " Summary"
puts "========================================================================="
puts "  Critical L1 modules analyzed    : [llength $critical_L1]"
puts "  Assignment targets (after drill): [llength $assignment_targets]"
puts "  Modules ASSIGNED (SLR)          : $suggestion_count"
puts "  Modules SKIPPED  (pblock)       : $skipped_count"
puts "  Neighbor co-assignments (6b)    : $neighbor_suggestion_count"
puts "  Pipeline regs assigned (6b)     : $pipeline_reg_count"
if {$design_has_pblocks} {
    puts "  Design has pblocks              : YES ([llength $all_pblocks])"
} else {
    puts "  Design has pblocks              : NO"
}
puts "  Anchor inter-SLR nets (STEP 7)  : $step9_net_count"
puts "  SLR assignment XDC (soft)       : $OUTPUT_XDC"
puts "  Full analysis report            : $OUTPUT_RPT"
puts "  Top-$TOP_PATHS_N path SLR-crossing rpt: $TOP_PATHS_RPT"
puts "  HTML dashboard                  : $OUTPUT_DIAGRAM"
puts ""
if {$suggestion_count > 0 || $step9_net_count > 0} {
    puts "  To apply these constraints in your implementation flow:"
    puts "    1. Open/read your opt_design checkpoint"
    puts "    2. source $OUTPUT_XDC"
    puts "    3. place_design"
    puts "    4. phys_opt_design"
    puts "    5. route_design"
    if {$step9_net_count > 0} {
        puts ""
        puts "  STEP 7 constrained $step9_net_count nets touching anchor primitives"
        puts "  (GT/XCVR, PCIE/CPM, MMCM, BRAM/URAM, DSP, DCMAC/MRMAC)."
        puts "  These anchors are fixed-location or placement-sensitive."
    }
} else {
    puts "  No SLR assignments generated."
    if {$skipped_count > 0} {
        puts "  All candidate modules had pblock conflicts in their cones."
    } else {
        puts "  No modules needed SLR re-assignment."
    }
}
puts "=========================================================================\n"

###############################################################################
# End of auto_suggest_slr_pblock_aware.tcl
#
# Previously this file ended by sourcing dataflow_neighbor_analysis.tcl
# (STEP 10).  That dependency has been removed: the top-$TOP_PATHS_N SLR
# crossing summary is now generated inline in STEP 7.5 and is also embedded
# in the HTML report (slr_assignment_diagram.html).
###############################################################################

    set stop [clock seconds]
    ::tclapp::xilinx::customqorflows::compile_time $start $stop
    if {[llength $command] == 0} {
        return
    } else {
        return [dict create COMMAND [join $command "\n"]]
    }
}

proc register_new_auto_suggest_slr_pblock_aware_checks {} {
    set id RQS_AMD_TIMING-5
    set description "Pblock-aware SLR assignment suggestions based on SLR crossing analysis (enhanced)."
    set auto 1
    set category timing
    set applicable_for place_design
    set needs_timing_data 0

    catch "delete_qor_check ${id} -quiet"
    create_qor_check -name ${id} -rule_body ::tclapp::xilinx::customqorflows::new_auto_suggest_slr_pblock_aware \
        -property_values [list DESCRIPTION $description \
                               AUTO $auto \
                               CATEGORY $category \
                               APPLICABLE_FOR $applicable_for \
                               NEEDS_TIMING_DATA $needs_timing_data \
                               ]
}

register_new_auto_suggest_slr_pblock_aware_checks
}
