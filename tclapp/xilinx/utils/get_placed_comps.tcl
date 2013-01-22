package require Vivado 2012.2

namespace eval ::tclapp::xilinx::utils {
    namespace export get_placed_comps
}

proc ::tclapp::xilinx::utils::get_placed_comps { {comp_type "ALL"} } {
    # Summary : Get placed comps of a given type
    
    # Argument Usage:
    # [comp_type="ALL"] : type of component
    
    # Return Value:
    # none
    
    # Description:
    # By default this will print all the placed
    # components if the comp is not specified
    # It will also print unplaced components if any
    
    set cells [get_cells];
    foreach cell $cells {
        if {[string match $comp_type [get_property lib_cell [get_cells $cell] ] ]} {
            if {[string match ""  [get_property LOC [get_cells $cell] ]]} {
                puts "INST: $cell\tTYPE: [get_property lib_cell [get_cells $cell] ]\tLOC: UNPLACED"
            } else {
                puts "INST: $cell\tTYPE: [get_property lib_cell [get_cells $cell] ]\tLOC: [get_property LOC [get_cells $cell]]"
            }
        } elseif {[string match "ALL" $comp_type ]} {
            if {[string match ""  [get_property LOC [get_cells $cell] ]]} {
                puts "INST: $cell\tTYPE: [get_property lib_cell [get_cells $cell] ]\tLOC: UNPLACED"
            } else {
                puts "INST: $cell\tTYPE: [get_property lib_cell [get_cells $cell] ]\tLOC: [get_property LOC [get_cells $cell]]"
            }
        }
    }
}
