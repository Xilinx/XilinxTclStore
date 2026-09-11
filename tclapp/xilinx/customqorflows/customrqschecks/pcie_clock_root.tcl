####################################################################################
#
# pcie_clock_root.tcl (customqorflows PCIE/QDMA clock root suggestion)
#
# Script created on 03/30/2026 by Madhur Chhabra, AMD
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::customqorflows {
	#namespace export pcie_clock_root
}

namespace eval ::tclapp::xilinx::customqorflows {

# DEBUG-gated tracer: prints only when the check's PARAMS DEBUG is 1.
variable _pcr_debug 0
proc _pcr_dbg {msg} {
    variable _pcr_debug
    if {$_pcr_debug} { puts $msg }
}

proc pcie_clock_root {args} {
    set _start [clock seconds]

    # PARAMS: DEBUG gates the [DETECT] trace. Toggle with
    #   set_property params {DEBUG 1} [get_qor_checks RQS_AMD_CLOCK-1]
    variable _pcr_debug
    set PARAMS(DEBUG) 0
    set _qor_dict ""
    if {$args ne ""} { set _qor_dict [lindex $args 0] }
    ::tclapp::xilinx::customqorflows::update_params PARAMS $_qor_dict
    set _pcr_debug $PARAMS(DEBUG)

    set _pcie_cr_moves 0
    set _cmd_lines [list]

    # Find all PCIE hard blocks
    set _pcie_cells [get_cells -quiet -hier -filter {REF_NAME =~ PCIE*}]

    if {[llength $_pcie_cells] == 0} {
        return
    }

_pcr_dbg "\[DETECT\] PCIE Clock Root: Found [llength $_pcie_cells] PCIE hard block(s)"

# Track processed IPs to avoid duplicates
catch {array unset _pcie_processed_ips}
array set _pcie_processed_ips {}

foreach _pcie $_pcie_cells {
    set _pcie_name [get_property NAME $_pcie]

    # Walk up hierarchy to find IP boundary (qdma_ or pcie_ in name)
    # Pick the FIRST (outermost) match — that's the IP root
    set _ip_root ""
    set _hier_parts [split $_pcie_name /]
    set _path ""
    foreach _part $_hier_parts {
        if {$_path eq ""} {
            set _path $_part
        } else {
            set _path "${_path}/${_part}"
        }
        if {$_ip_root eq "" && [regexp -nocase {qdma_|pcie_} $_part]} {
            set _ip_root $_path
            break
        }
    }

    if {$_ip_root eq ""} {
        # Try matching on the full path
        if {[regexp -nocase {qdma_|pcie_} $_pcie_name]} {
            # Use the cell two levels above PCIE as IP root
            set _nparts [llength $_hier_parts]
            if {$_nparts >= 3} {
                set _ip_root [join [lrange $_hier_parts 0 end-2] /]
            } else {
                set _ip_root [lindex $_hier_parts 0]
            }
        } else {
            continue
        }
    }

    # Skip if already processed this IP
    if {[info exists _pcie_processed_ips($_ip_root)]} { continue }
    set _pcie_processed_ips($_ip_root) 1

    _pcr_dbg "\[DETECT\]   IP: $_ip_root"
    _pcr_dbg "\[DETECT\]   PCIE: $_pcie_name"

    # Get PCIE clock region
    set _pcie_site [get_sites -quiet -of_objects [get_cells -quiet $_pcie]]
    if {[llength $_pcie_site] == 0} {
        _pcr_dbg "\[DETECT\]   WARNING: PCIE has no site (unplaced?), skipping"
        continue
    }
    set _pcie_cr [get_property -quiet CLOCK_REGION $_pcie_site]
    if {$_pcie_cr eq ""} {
        _pcr_dbg "\[DETECT\]   WARNING: Cannot get clock region for PCIE, skipping"
        continue
    }
    _pcr_dbg "\[DETECT\]   PCIE clock region: $_pcie_cr"

    # Parse clock region coordinates (X<n>Y<m> or S<s>X<n>Y<m>)
    set _cr_prefix ""
    if {[regexp {(S\d+)X(\d+)Y(\d+)} $_pcie_cr -> _cr_prefix _cr_x _cr_y]} {
        # P80 style with SLR prefix
    } elseif {[regexp {X(\d+)Y(\d+)} $_pcie_cr -> _cr_x _cr_y]} {
        # Standard style
    } else {
        _pcr_dbg "\[DETECT\]   WARNING: Cannot parse clock region $_pcie_cr, skipping"
        continue
    }

    # Compute optimal clock root: nearest odd X, same Y
    if {$_cr_x % 2 == 1} {
        # Already odd
        set _root_x $_cr_x
    } else {
        # Even → go to next odd (X+1)
        set _root_x [expr {$_cr_x + 1}]
    }

    if {$_cr_prefix ne ""} {
        set _optimal_cr "${_cr_prefix}X${_root_x}Y${_cr_y}"
    } else {
        set _optimal_cr "X${_root_x}Y${_cr_y}"
    }
    _pcr_dbg "\[DETECT\]   Optimal clock root: $_optimal_cr (from PCIE CR=$_pcie_cr, nearest odd X)"

    # Find BUFG_GT cells under this IP hierarchy
    set _ip_bufgts [get_cells -quiet -hier -filter "NAME =~ ${_ip_root}/* && REF_NAME == BUFG_GT"]
    if {[llength $_ip_bufgts] == 0} {
        # Try broader search — BUFG_GTs might be at a different hierarchy level
        # Look for BUFG_GTs whose I pin is driven by GTs under this IP
        set _ip_gts [get_cells -quiet -hier -filter "NAME =~ ${_ip_root}/* && REF_NAME =~ GT*"]
        if {[llength $_ip_gts] > 0} {
            # Get GT output pins → trace to BUFG_GT I pins
            set _gt_out_pins [get_pins -quiet -of_objects $_ip_gts -filter {DIRECTION == OUT && REF_PIN_NAME =~ *TXOUTCLK* || REF_PIN_NAME =~ *RXOUTCLK*}]
            if {[llength $_gt_out_pins] > 0} {
                set _gt_nets [get_nets -quiet -of_objects $_gt_out_pins]
                if {[llength $_gt_nets] > 0} {
                    set _driven_pins [get_pins -quiet -leaf -of_objects $_gt_nets -filter {DIRECTION == IN && REF_PIN_NAME == I}]
                    set _ip_bufgts [get_cells -quiet -of_objects $_driven_pins -filter {REF_NAME == BUFG_GT}]
                }
            }
        }
    }

    if {[llength $_ip_bufgts] == 0} {
        _pcr_dbg "\[DETECT\]   No BUFG_GT cells found for this IP, skipping"
        continue
    }
    _pcr_dbg "\[DETECT\]   Found [llength $_ip_bufgts] BUFG_GT(s) in IP"

    # Print driver info and group BUFG_GTs by shared driver
    catch {array unset _bufgt_drv_groups}
    array set _bufgt_drv_groups {}
    foreach _bufgt $_ip_bufgts {
        set _bg_name [get_property NAME $_bufgt]
        set _drv_pin [get_pins -quiet -of_objects [get_nets -quiet -of_objects [get_pins -quiet -of_objects $_bufgt -filter {REF_PIN_NAME == I}]] -leaf -filter {DIRECTION == OUT}]
        if {$_drv_pin ne ""} {
            set _dname [get_property NAME $_drv_pin]
            _pcr_dbg "\[DETECT\]     BUFG_GT: $_bg_name -> driver: $_dname"
            if {![info exists _bufgt_drv_groups($_dname)]} {
                set _bufgt_drv_groups($_dname) [list]
            }
            lappend _bufgt_drv_groups($_dname) $_bufgt
        } else {
            _pcr_dbg "\[DETECT\]     BUFG_GT: $_bg_name -> driver: (not found)"
        }
    }

    # Pick the largest group (shared driver = same GT clock output)
    set _target_bufgts [list]
    set _max_group_size 0
    set _target_driver ""
    foreach _drv [array names _bufgt_drv_groups] {
        set _grp $_bufgt_drv_groups($_drv)
        if {[llength $_grp] > $_max_group_size} {
            set _max_group_size [llength $_grp]
            set _target_bufgts $_grp
            set _target_driver $_drv
        }
    }

    if {[llength $_target_bufgts] < 2} {
        _pcr_dbg "\[DETECT\]   No shared-driver BUFG_GT group found (need >= 2), skipping"
        continue
    }
    _pcr_dbg "\[DETECT\]   Target group: [llength $_target_bufgts] BUFG_GTs sharing driver: $_target_driver"

    # Apply USER_CLOCK_ROOT to target BUFG_GT output nets only
    foreach _bufgt $_target_bufgts {
        set _o_pin [get_pins -quiet -of_objects $_bufgt -filter {REF_PIN_NAME == O}]
        if {$_o_pin eq ""} { continue }
        set _o_net [get_nets -quiet -of_objects $_o_pin]
        if {$_o_net eq ""} { continue }
        set _net_name [get_property NAME $_o_net]

        # Check if net already has USER_CLOCK_ROOT set
        set _existing_root [get_property -quiet USER_CLOCK_ROOT $_o_net]
        if {$_existing_root ne ""} {
            _pcr_dbg "\[DETECT\]     Net $_net_name already has USER_CLOCK_ROOT=$_existing_root, skipping"
            continue
        }

        lappend _cmd_lines "catch { set_property USER_CLOCK_ROOT $_optimal_cr \[get_nets {$_net_name}\] }"
        _pcr_dbg "\[DETECT\]     Suggest USER_CLOCK_ROOT=$_optimal_cr on net: $_net_name"
        incr _pcie_cr_moves
    }
}

    set _stop [clock seconds]
    ::tclapp::xilinx::customqorflows::compile_time $_start $_stop "" PCIE_CLOCK_ROOT

    if {[llength $_cmd_lines] == 0} { return }

    set _command [join $_cmd_lines "\n"]
    return [dict create COMMAND $_command]
}

# --- Registration ---
proc register_pcie_clock_root_checks {} {
    set id             RQS_AMD_CLOCK-1
    set description    "Suggest an optimal USER_CLOCK_ROOT (nearest odd-X clock region of the PCIE hard block) on the BUFG_GT output clock nets of PCIE/QDMA IPs to reduce clock insertion delay and skew"
    set auto           1
    set category       clocking
    set applicable_for place_design
    set needs_timing_data 0
    set params         [list DEBUG 0]

    catch "delete_qor_check ${id} -quiet"
    create_qor_check -name ${id} -rule_body ::tclapp::xilinx::customqorflows::pcie_clock_root \
        -property_values [list DESCRIPTION $description \
                               AUTO $auto \
                               CATEGORY $category \
                               APPLICABLE_FOR $applicable_for \
                               NEEDS_TIMING_DATA $needs_timing_data \
                               PARAMS $params \
                              ]
}

register_pcie_clock_root_checks
}
