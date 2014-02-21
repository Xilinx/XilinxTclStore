#!vivado
lappend ::auto_path [ file normalize C:/Users/nikc/tcl/XilinxTclStore/tclapp/ ]

package require ::tclapp::xilinx::junit
namespace import ::tclapp::xilinx::junit::*

set_report ./report.xml

file delete [ glob ./* ]

create_project -force tp tp -part xc7vx485tffg1157-1
add_files [ glob ../../src/* ]

update_compile_order

launch_runs synth_1
wait_on_run synth_1

launch_runs impl_1
wait_on_run impl_1

process_runs [ list [ get_runs synth_1 ] [ get_runs impl_1 ] ] 
write_results

