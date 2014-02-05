set_param tclapp.sharedRepoPath /proj/xcoswmktg/bgreine/git_Xilinx_appstore/XilinxTclStore
package require ::tclapp::xilinx::designutils
set_param tclapp.enableGitAccess 0
open_project -read_only /proj/xbuilds/2014.1_0204_1/installs/lin64/Vivado/2014.1/examples/Vivado_Tutorial/Projects/project_bft_core_hdl/project_bft_core_hdl.xpr
save_project_as project_1 /proj/xcoswmktg/bgreine/temp/project_test_generate_runs -force
source /proj/xcoswmktg/bgreine/git_Xilinx_appstore/XilinxTclStore/tclapp/xilinx/designutils/generate_runs.tcl
tclapp::xilinx::designutils::generate_runs 0
delete_runs [get_runs]
tclapp::xilinx::designutils::generate_runs 1
exit

