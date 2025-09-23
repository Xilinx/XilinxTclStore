package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
  namespace export enable_equiv_vivado_directives
  namespace export disable_equiv_vivado_directives
}

proc ::tclapp::xilinx::designutils::enable_equiv_vivado_directives {} {
    # Summary : Procedure to enable Vivado equivalent placer directive for Advanced Flow

    # Argument Usage:

    # Return Value:
    # 0 if succeeded or TCL_ERROR if an error happened

    # Categories: xilinxtclstore, designutils

    #uplevel [concat [list ::tclapp::xilinx::designutils::enable_equiv_vivado_directives]]
    # Check if advanced flow is running
    if {[catch {set flow [get_param flow.isRubikFeatureSet]}] || !$flow} {
        puts "Error: Placer directives mapping is only available for Vivado Advanced Flow."
        return
    }
    # Check if the procedure has been already called
    if {[lsearch -exact [info commands place_design_[pid]] place_design_[pid]] != -1} {
        puts "Warning: the placer directives mapping for Vivado Advanced Flow is already enabled."
        return 1
    } else {
        puts "Info: the placer directives mapping for Vivado Advanced Flow is enabled."
    }
    rename ::place_design ::place_design_[pid]
    uplevel #0 [format {
    proc ::place_design {args} {
        ::tclapp::xilinx::designutils::enable_equiv_vivado_directives::place_design {*}$args
    }
    }]
    return -code ok
    }

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils::enable_equiv_vivado_directives {
    variable version [version -short]
    variable found 0
    variable classic_dir "Default"
} ]

proc ::tclapp::xilinx::designutils::enable_equiv_vivado_directives::place_design {args} {
    # Summary : Overloads place_design to run equivalent directives

    # Argument Usage:

    # Return Value:
    # 0 if succeeded or TCL_ERROR if an error happened

    variable version
    variable found
    variable classic_dir
    puts "Info: Overloading place_design to convert Classic Flow directives to Advanced Flow"
    ## Find the value of -directive option specified in Classic flow
    foreach arg $args {
        if {$found} {
            set classic_dir $arg
            puts "Info: Mapping placer directive: $classic_dir"
            set found 0
        }
         if [regexp {^-d(i(r(e(c(t(i(v(e?)?)?)?)?)?)?)?)?$} $arg] {
            set found 1
        }
    }
   ## Map classic flow directives to advanced flow
   set advanced_sub_dir ""
   set net_delay_weight ""
   switch $classic_dir {
    "WLDrivenBlockPlacement" {
        set advanced_dir "Default"
        set advanced_sub_dir "{Floorplan.WLDrivenBlockPlacement GPlace.WLDrivenBlockPlacement}"
    }
    "AltSpreadLogic_high" {
        set advanced_dir "Default"
        set advanced_sub_dir "{Floorplan.ForceSpreading.high GPlace.ForceSpreading.high GPlace.ReduceCongestion.high DPlace.ReducePinDensity.high}"
    }
    "AltSpreadLogic_medium" {
        set advanced_dir "Default"
        set advanced_sub_dir "{Floorplan.ForceSpreading.med GPlace.ForceSpreading.med GPlace.ReduceCongestion.med DPlace.ReducePinDensity.med}"
    }
    "AltSpreadLogic_low" {
        set advanced_dir "Default"
        set advanced_sub_dir "{Floorplan.ForceSpreading.low GPlace.ForceSpreading.low GPlace.ReduceCongestion.low DPlace.ReducePinDensity.low}"
    }
    "EarlyBlockPlacement" {
        set advanced_dir "Default"
        set advanced_sub_dir "{GPlace.EarlyBlockPlacement}"
    }
    "ExtraTimingOpt" {
        set advanced_dir "Explore"
        set advanced_sub_dir "{Floorplan.ExtraTimingUpdate Gplace.ExtraTimingUpdate Dplace.ExtraTimingUpdate Floorplan.ExtraTimingOpt.high Gplace.ExtraTimingOpt.high Dplace.ExtraTimingOpt.high}"
    }
    "ExtraPostPlacementOpt" {
        puts "Info: ExtraPostPlacementOpt is not supported in advanced flow"
        set advanced_dir "Default"
    }
    "SSI_SpreadLogic_high" {
        set advanced_dir "Default"
        set advanced_sub_dir "{Floorplan.BalancedSLR.high}"
    }
    "SSI_SpreadLogic_low" {
        set advanced_dir "Default"
        set advanced_sub_dir "{Floorplan.BalancedSLR.low}"
    }
    "SSI_SpreadLogic_medium" {
        set advanced_dir "Default"
        set advanced_sub_dir "{Floorplan.BalancedSLR.med}"
    }
    "SSI_SpreadSLL" {
        puts "Info: SSI_SpreadSLL is not supported in advanced flow"
        set advanced_dir "Default"
    }
    "SSI_BalanceSLLs" {
        puts "Info: SSI_BalanceSLLs is not supported in advanced flow"
        set advanced_dir "Default"
    }
    "SSI_BalanceSLRs" {
        set advanced_dir "Explore"
        set advanced_sub_dir "{Floorplan.BalancedSLR.high}"
    }
    "SSI_HighUtilSLRs" {
        set advanced_dir "Explore"
        set advanced_sub_dir "{Floorplan.BalancedSLR.low}"
    }
    "ExtraNetDelay_high" {
        set advanced_dir "Explore"
        set advanced_sub_dir ""
        set net_delay_weight "high"
    }
    "ExtraNetDelay_low" {
        set advanced_dir "Explore"
        set advanced_sub_dir ""
        set net_delay_weight "low"
    }
    "ExtraNetDelay_medium" {
        set advanced_dir "Explore"
        set advanced_sub_dir ""
        set net_delay_weight "medium"
    }
    default {
        set advanced_dir $classic_dir
    }
}
    ## Run place_design based on mapping
    puts "Info: Equivalent command line options: ${advanced_dir}; Subdirective: ${advanced_sub_dir}; NetDelayWeight: ${net_delay_weight}"
    if {$advanced_sub_dir != ""} {
    set advanced_pattern "-directive $advanced_dir -subdirective $advanced_sub_dir"
    } elseif {$net_delay_weight != ""} {
    set advanced_pattern "-directive $advanced_dir -net_delay_weight $net_delay_weight"
    } else {
    set advanced_pattern "-directive $advanced_dir"
    }

    regsub -all {(-d(i(r(e(c(t(i(v(e?)?)?)?)?)?)?)?)?)\s+(\S+)} $args $advanced_pattern advanced_command
#    eval "place_design_[pid] $advanced_command"
    ::place_design_[pid] {*}$advanced_command
    return 0
}

proc ::tclapp::xilinx::designutils::disable_equiv_vivado_directives {} {
    # Summary : Procedure to disable Vivado equivalent placer directive for Advanced Flow

    # Argument Usage:

    # Return Value:
    # 0 if succeeded or TCL_ERROR if an error happened

    # Categories: xilinxtclstore, designutils
    if {[lsearch -exact [info commands place_design_[pid]] place_design_[pid]] == -1} {
        puts "Warning: Placer directives mapping for Vivado Advanced Flow is not enabled."
        return 1
    } else {
        puts "Info: Placer directives mapping for Vivado Advanced Flow is disabled."
    }

    namespace eval :: {
    rename place_design {}
    rename place_design_[pid] place_design
}
    return 0
}
