#!vivado
lappend ::auto_path [ file normalize C:/Users/nikc/tcl/XilinxTclStore/tclapp/ ]

package require ::tclapp::xilinx::junit
namespace import ::tclapp::xilinx::junit::*

file delete [ glob ./* ]

# set optional report name (default: report.xml)
set_report ./report.xml

add_files [ glob ../../src/* ]

update_compile_order

# synth_design
run_step {synth_design -top ff_replicator -part xc7vx485tffg1157-1}
write_checkpoint synthesis.dcp
# validation
validate_timing "Post synth_design"
validate_logic "Post synth_design"

# opt_design
run_step {opt_design}
write_checkpoint opt_design.dcp
# validation
validate_timing "Post opt_design"
validate_logic "Post opt_design"

# place_design
run_step {place_design}
write_checkpoint place_design.dcp
# validation
validate_timing "Post place_design"
validate_logic "Post place_design"

# phys_opt_design
run_step {phys_opt_design}
write_checkpoint phys_opt_design.dcp
# validation
validate_timing "Post phys_opt_design"
validate_logic "Post phys_opt_design"

# route_design
run_step {route_design}
write_checkpoint route_design.dcp
# validation
validate_timing "Post route_design"
validate_routing "Post route_design"


# done after each step
validate_messages "Final"
validate_drcs "Final"


write_results 

# validate_logic
# validate_routing
# validate_timing
# validate_messages
# validate_drcs
# validate_run_properties
