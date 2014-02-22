#!vivado

# prep
set testDir   [ file normalize [ file dirname [ info script ] ] ]
set appDir    [ file normalize [ file join $testDir .. .. .. .. ] ]
set runDir    [ file join $testDir run ]
lappend ::auto_path $appDir
puts "Using App Dir:\n  $appDir"
puts "Using Test Dir:\n  $testDir"
puts "Using Run Dir:\n  $runDir"

package require ::tclapp::xilinx::junit
namespace import ::tclapp::xilinx::junit::*

set outputReport [ file join $runDir synthReport.xml ]
set_report $outputReport
process_synth_design [ current_design ]
write_results
