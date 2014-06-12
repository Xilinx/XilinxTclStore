#!vivado
#
# same test as project_step_high except this verifies behavior without import

# prep
set testDir   [ file normalize [ file dirname [ info script ] ] ]
set runDir    [ file join $testDir run ]
puts "= Current Test Dir:\n  $testDir"
puts "= Current Run Dir:\n  $runDir"

# clean
if { [ file exists $runDir ] } { file delete -force $runDir }
file mkdir $runDir

package require ::tclapp::xilinx::junit

# set optional report name (default: report.xml)
set outputReport [ file join $runDir report.xml ]
::tclapp::xilinx::junit::set_report $outputReport

set srcFiles [ file normalize [ file join $runDir .. .. src * ] ]
puts "Searching for source files with:\n  ${srcFiles}"
add_files [ glob $srcFiles ]

update_compile_order

# synth_design
#   run_step will: track runtime, catch and log errors, validate_messages, and validate_drcs
::tclapp::xilinx::junit::run_step {synth_design -top ff_replicator -part xc7vx485tffg1157-1}
write_checkpoint [ file join $runDir synthesis.dcp ]
# validation
::tclapp::xilinx::junit::validate_timing "Post synth_design"
::tclapp::xilinx::junit::validate_logic "Post synth_design"
::tclapp::xilinx::junit::validate_routing "Post synth_design"; # this is not a rational check, just for testing - see post-route_design

# done after each step
::tclapp::xilinx::junit::validate_messages "Final"
::tclapp::xilinx::junit::validate_drcs "Final"


::tclapp::xilinx::junit::write_results 


# smoke test to just make sure XML is generated
if { ! [ file exists $outputReport ] } {
  error "Couldn't find junit report: '$outputReport'"
}

# clean on success
file delete -force $runDir 
puts "done."


