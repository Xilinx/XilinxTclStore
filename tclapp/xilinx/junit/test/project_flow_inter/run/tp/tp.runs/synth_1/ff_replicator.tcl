# 
# Synthesis run script generated by Vivado
# 

  set_param general.maxThreads 1
  set_param tclapp.enableDebugGit 1
  set_param tclapp.enableDebugRepo 1
  set_param webtalk.disableTransmit 819012
set_msg_config -id {HDL 9-1061} -limit 100000
set_msg_config -id {HDL 9-1654} -limit 100000
set_msg_config -id {Synth 8-256} -limit 10000
set_msg_config -id {Synth 8-638} -limit 10000
create_project -in_memory -part xc7vx485tffg1157-1
set_property target_language Verilog [current_project]
set_param project.compositeFile.enableAutoGeneration 0
set_property default_lib xil_defaultlib [current_project]
read_verilog -library xil_defaultlib {
  /wrk/hdstaff/bdai/hd2/TclApp/test_3_4/XilinxTclStore/tclapp/xilinx/junit/test/src/ff_ce_sync_rst.v
  /wrk/hdstaff/bdai/hd2/TclApp/test_3_4/XilinxTclStore/tclapp/xilinx/junit/test/src/ff_replicator.v
}
read_xdc /wrk/hdstaff/bdai/hd2/TclApp/test_3_4/XilinxTclStore/tclapp/xilinx/junit/test/src/ff_replicator.xdc
set_property used_in_implementation false [get_files /wrk/hdstaff/bdai/hd2/TclApp/test_3_4/XilinxTclStore/tclapp/xilinx/junit/test/src/ff_replicator.xdc]

set_param synth.vivado.isSynthRun true
set_property webtalk.parent_dir /wrk/hdstaff/bdai/hd2/TclApp/test_3_4/XilinxTclStore/tclapp/xilinx/junit/test/project_flow_inter/run/tp/tp.cache/wt [current_project]
set_property parent.project_dir /wrk/hdstaff/bdai/hd2/TclApp/test_3_4/XilinxTclStore/tclapp/xilinx/junit/test/project_flow_inter/run/tp [current_project]
synth_design -top ff_replicator -part xc7vx485tffg1157-1
write_checkpoint ff_replicator.dcp
report_utilization -file ff_replicator_utilization_synth.rpt -pb ff_replicator_utilization_synth.pb
