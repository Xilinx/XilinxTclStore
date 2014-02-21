cd C:/Users/nikc/Desktop/jenkins/project_hook_high/workspace/
lappend ::auto_path [ file normalize C:/Users/nikc/tcl/XilinxTclStore/tclapp/ ]
package require ::tclapp::xilinx::junit
namespace import ::tclapp::xilinx::junit::*
combine_junit {./tp/tp.runs/synth_1/report.xml ./tp/tp.runs/impl_1/report.xml} ./report.xml
