set_param tclapp.sharedRepoPath /proj/xcoswmktg/bgreine/git_Xilinx_appstore/XilinxTclStore
package require ::tclapp::xilinx::designutils
set_param tclapp.enableGitAccess 0
open_project -read_only /proj/xbuilds/2014.1_0204_1/installs/lin64/Vivado/2014.1/examples/Vivado_Tutorial/Projects/project_bft_core_hdl/project_bft_core_hdl.xpr
save_project_as project_1 /proj/xcoswmktg/bgreine/temp/project_test_is_fabric_connected -force
source /proj/xcoswmktg/bgreine/git_Xilinx_appstore/XilinxTclStore/tclapp/xilinx/designutils/is_fabric_connected.tcl
launch_runs impl_1 -jobs 4
wait_on_run impl_1
open_run impl_1
# Should Return False:
tclapp::xilinx::designutils::is_fabric_connected [get_pins wbInputData_IBUF[0]_inst/I]
# Should Return True
tclapp::xilinx::designutils::is_fabric_connected [get_pins fifoSelect_reg[2]/Q]
exit
