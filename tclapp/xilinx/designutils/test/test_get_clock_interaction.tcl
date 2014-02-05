set_param tclapp.sharedRepoPath /proj/xcoswmktg/bgreine/git_Xilinx_appstore/XilinxTclStore
package require ::tclapp::xilinx::designutils
set_param tclapp.enableGitAccess 0
open_project -read_only /proj/xbuilds/2014.1_0204_1/installs/lin64/Vivado/2014.1/examples/Vivado_Tutorial/Projects/project_bft_core_hdl/project_bft_core_hdl.xpr
save_project_as project_1 /proj/xcoswmktg/bgreine/temp/project_test_get_clock_interaction -force
source /proj/xcoswmktg/bgreine/git_Xilinx_appstore/XilinxTclStore/tclapp/xilinx/designutils/get_clock_interaction.tcl
launch_runs impl_1 -jobs 4
wait_on_run impl_1
open_run impl_1
tclapp::xilinx::designutils::get_clock_interaction bftClk wbClk inter_clock
tclapp::xilinx::designutils::get_clock_interaction bftClk bftClk inter_clock
tclapp::xilinx::designutils::get_clock_interaction bftClk wbClk wns
tclapp::xilinx::designutils::get_clock_interaction bftClk bftClk wns
exit
