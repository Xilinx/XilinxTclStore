#!vivado

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

set projectDir [ file join $runDir tp ]
create_project tp $projectDir -part xc7vx485tffg1157-1

set srcFiles [ file normalize [ file join $::test_dir src * ] ]
puts "Searching for source files with:\n  ${srcFiles}"
add_files [ glob $srcFiles ]

update_compile_order

set_property STEPS.SYNTH_DESIGN.TCL.POST [ file join $testDir hook_synth.tcl ] [get_runs synth_1]
# this script will output to
set synthReport [ file join $runDir synthReport.xml ] 

#set_property STEPS.ROUTE_DESIGN.TCL.POST [ file join $testDir hook_impl.tcl ] [get_runs impl_1]
# this script will output to
#set implReport [ file join $runDir implReport.xml ] 

launch_runs synth_1
wait_on_run synth_1

#launch_runs impl_1
#wait_on_run impl_1

# a potential enhancement would be to combine the synth and impl reports
#   1. could build a parser... lots of work
#   2. could write partial reports (<testsuite...> only) and later stitch partial reports together 
#      with <testsuites> and <?xml...?> nodes added during stitching process 
set outputReport [ file join $runDir report.xml ]
file copy $synthReport $outputReport
#file copy $implReport $outputReport

close_project

# smoke test to just make sure XML is generated
if { ! [ file exists $outputReport ] } {
  error "Couldn't find junit report: '$outputReport'"
}

# clean on success
file delete -force $runDir 
puts "done."

