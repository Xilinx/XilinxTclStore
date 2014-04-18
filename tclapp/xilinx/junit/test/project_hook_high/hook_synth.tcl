#!vivado

# prep
set testDir   [ file normalize [ file dirname [ info script ] ] ]
set runDir    [ file join $testDir run ]
puts "= Current Test Dir:\n  $testDir"
puts "= Current Run Dir:\n  $runDir"

set outputReport [ file join $runDir synthReport.xml ]
set_report $outputReport
process_synth_design [ current_design ]
write_results
