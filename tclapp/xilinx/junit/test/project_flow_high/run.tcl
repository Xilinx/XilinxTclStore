#!vivado

# prep
set testDir   [ file normalize [ file dirname [ info script ] ] ]
set appDir    [ file normalize [ file join $testDir .. .. .. .. ] ]
set runDir    [ file join $testDir run ]
lappend ::auto_path $appDir
puts "Using App Dir:\n  $appDir"
puts "Using Test Dir:\n  $testDir"
puts "Using Run Dir:\n  $runDir"

# clean
if { [ file exists $runDir ] } { file delete -force $runDir }
file mkdir $runDir

package require ::tclapp::xilinx::junit
namespace import ::tclapp::xilinx::junit::*

set outputReport [ file join $runDir report.xml ]
set_report $outputReport

set projectDir [ file join $runDir tp ]
create_project -force tp $projectDir -part xc7vx485tffg1157-1

set srcFiles [ file normalize [ file join $runDir .. .. src * ] ]
puts "Searching for source files with:\n  ${srcFiles}"
add_files [ glob $srcFiles ]

update_compile_order

launch_runs synth_1
wait_on_run synth_1

#launch_runs impl_1
#wait_on_run impl_1

process_runs [ list [ get_runs synth_1 ] ] 
#process_runs [ list [ get_runs synth_1 ] [ get_runs impl_1 ] ] 
write_results

close_project

# smoke test to just make sure XML is generated
if { ! [ file exists $outputReport ] } {
  error "Couldn't find junit report: '$outputReport'"
}

# clean on success
file delete -force $runDir 
puts "done."

