#!vivado
lappend ::auto_path [ file normalize C:/Users/nikc/tcl/XilinxTclStore/tclapp/ ]

package require ::tclapp::xilinx::junit
namespace import ::tclapp::xilinx::junit::*

set_report ./report.xml
process_synth_design [ current_design ]
write_results
