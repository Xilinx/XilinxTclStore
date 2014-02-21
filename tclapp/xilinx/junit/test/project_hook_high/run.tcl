#!vivado
lappend ::auto_path [ file normalize C:/Users/nikc/tcl/XilinxTclStore/tclapp/ ]

package require ::tclapp::xilinx::junit
namespace import ::tclapp::xilinx::junit::*

file delete [ glob ./* ]

create_project -force tp tp -part xc7vx485tffg1157-1

add_files [ glob ../../src/* ]

update_compile_order

set_property STEPS.SYNTH_DESIGN.TCL.POST {C:/Users/nikc/Desktop/jenkins/project_hook_high/hook_synth.tcl} [get_runs synth_1]
set_property STEPS.ROUTE_DESIGN.TCL.POST {C:/Users/nikc/Desktop/jenkins/project_hook_high/hook_impl.tcl} [get_runs impl_1]

launch_runs synth_1
wait_on_run synth_1

launch_runs impl_1
wait_on_run impl_1

#combine_junit {./tp/tp.runs/synth_1/report.xml ./tp/tp.runs/impl_1/report.xml} ./report.xml
file copy ./tp/tp.runs/impl_1/report.xml ./report.xml

