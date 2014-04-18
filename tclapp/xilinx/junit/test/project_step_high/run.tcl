#!vivado
# 
# Validation checks
#
# checked here:
#   validate_logic
#   validate_routing
#   validate_timing
#   validate_messages
#   validate_drcs
# not here:
#   validate_run_properties

# prep
set testDir   [ file normalize [ file dirname [ info script ] ] ]
set runDir    [ file join $testDir run ]
puts "= Current Test Dir:\n  $testDir"
puts "= Current Run Dir:\n  $runDir"

# clean
if { [ file exists $runDir ] } { file delete -force $runDir }
file mkdir $runDir

package require ::tclapp::xilinx::junit
namespace import ::tclapp::xilinx::junit::*

# set optional report name (default: report.xml)
set outputReport [ file join $runDir report.xml ]
set_report $outputReport

set srcFiles [ file normalize [ file join $runDir .. .. src * ] ]
puts "Searching for source files with:\n  ${srcFiles}"
add_files [ glob $srcFiles ]

update_compile_order

# synth_design
#   run_step will: track runtime, catch and log errors, validate_messages, and validate_drcs
run_step {synth_design -top ff_replicator -part xc7vx485tffg1157-1}
write_checkpoint [ file join $runDir synthesis.dcp ]
# validation
validate_timing "Post synth_design"
validate_logic "Post synth_design"
validate_routing "Post synth_design"; # this is not a rational check, just for testing - see post-route_design

## opt_design
#run_step {opt_design}
#write_checkpoint [ file join $runDir opt_design.dcp ]
## validation
#validate_timing "Post opt_design"
#validate_logic "Post opt_design"
#
## place_design
#run_step {place_design}
#write_checkpoint [ file join $runDir place_design.dcp ]
## validation
#validate_timing "Post place_design"
#validate_logic "Post place_design"
#
## phys_opt_design
#run_step {phys_opt_design}
#write_checkpoint [ file join $runDir phys_opt_design.dcp ]
## validation
#validate_timing "Post phys_opt_design"
#validate_logic "Post phys_opt_design"
#
## route_design
#run_step {route_design}
#write_checkpoint [ file join $runDir route_design.dcp ]
## validation
#validate_timing "Post route_design"
#validate_routing "Post route_design"


# done after each step
validate_messages "Final"
validate_drcs "Final"


write_results 


# smoke test to just make sure XML is generated
if { ! [ file exists $outputReport ] } {
  error "Couldn't find junit report: '$outputReport'"
}

# clean on success
file delete -force $runDir 
puts "done."


