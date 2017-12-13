source $::env(SW_TESTS)/features/project/utils/common.tcl
create_project test /proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test -part xc7vx485tffg1157-1 -force
create_bd_design "shift_left"
update_compile_order -fileset sources_1
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:c_addsub:12.0 c_addsub_0
endgroup
startgroup
make_bd_pins_external  [get_bd_cells c_addsub_0]
make_bd_intf_pins_external  [get_bd_cells c_addsub_0]
endgroup
generate_target all [get_files  /proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.srcs/sources_1/bd/shift_left/shift_left.bd]
export_ip_user_files -of_objects [get_files /proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.srcs/sources_1/bd/shift_left/shift_left.bd] -no_script -sync -force -quiet
create_ip_run [get_files -of_objects [get_fileset sources_1] /proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.srcs/sources_1/bd/shift_left/shift_left.bd]
launch_runs -jobs 20 shift_left_c_addsub_0_0_synth_1
export_simulation -of_objects [get_files /proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.srcs/sources_1/bd/shift_left/shift_left.bd] -directory /proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.ip_user_files/sim_scripts -ip_user_files_dir /proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.ip_user_files -ipstatic_source_dir /proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.ip_user_files/ipstatic -lib_map_path [list {modelsim=/proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.cache/compile_simlib/modelsim} {questa=/proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.cache/compile_simlib/questa} {ies=/proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.cache/compile_simlib/ies} {vcs=/proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.cache/compile_simlib/vcs} {riviera=/proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.cache/compile_simlib/riviera}] -use_ip_compiled_libs -force -quiet
set_property PR_FLOW 1 [current_project] 
create_partition_def -name shift -module shift_left
create_reconfig_module -name shift_left -partition_def [get_partition_defs shift ]  -define_from shift_left
create_bd_design "top"
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:c_accum:12.0 c_accum_0
endgroup
startgroup
make_bd_pins_external  [get_bd_cells c_accum_0]
make_bd_intf_pins_external  [get_bd_cells c_accum_0]
endgroup
create_bd_cell -type module -reference shift shift_0
startgroup
make_bd_pins_external  [get_bd_cells shift_0]
make_bd_intf_pins_external  [get_bd_cells shift_0]
endgroup
make_wrapper -files [get_files /proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.srcs/sources_1/bd/top/top.bd] -top
add_files -norecurse /proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.srcs/sources_1/bd/top/hdl/top_wrapper.v
generate_target all [get_files  /proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.srcs/sources_1/bd/top/top.bd]
catch { config_ip_cache -export [get_ips -all top_c_accum_0_0] }
export_ip_user_files -of_objects [get_files /proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.srcs/sources_1/bd/top/top.bd] -no_script -sync -force -quiet
create_ip_run [get_files -of_objects [get_fileset sources_1] /proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.srcs/sources_1/bd/top/top.bd]
launch_runs -jobs 20 top_c_accum_0_0_synth_1
export_simulation -of_objects [get_files /proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.srcs/sources_1/bd/top/top.bd] -directory /proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.ip_user_files/sim_scripts -ip_user_files_dir /proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.ip_user_files -ipstatic_source_dir /proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.ip_user_files/ipstatic -lib_map_path [list {modelsim=/proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.cache/compile_simlib/modelsim} {questa=/proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.cache/compile_simlib/questa} {ies=/proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.cache/compile_simlib/ies} {vcs=/proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.cache/compile_simlib/vcs} {riviera=/proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.cache/compile_simlib/riviera}] -use_ip_compiled_libs -force -quiet
launch_runs shift_left_synth_1 -jobs 20
wait_on_run shift_left_synth_1
launch_runs synth_1 -jobs 20
wait_on_run synth_1
create_pr_configuration -name config_1 -partitions [list top_i/shift_0:shift_left ]
set_property PR_CONFIGURATION config_1 [get_runs impl_1]
open_run synth_1 -name synth_1 -pr_config [current_pr_configuration]
startgroup
create_pblock pblock_shift_0
resize_pblock pblock_shift_0 -add {SLICE_X52Y55:SLICE_X63Y96 DSP48_X4Y22:DSP48_X4Y37 RAMB18_X4Y22:RAMB18_X4Y37 RAMB36_X4Y11:RAMB36_X4Y18}
add_cells_to_pblock pblock_shift_0 [get_cells [list top_i/shift_0]] -clear_locs
endgroup
file mkdir /proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.srcs/constrs_1/new
close [ open /proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.srcs/constrs_1/new/constr.xdc w ]
add_files -fileset constrs_1 /proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.srcs/constrs_1/new/constr.xdc
set_property target_constrs_file /proj/xhdhdstaff2/vinaykum/Report_Qor_Test_Case_1/test/test.srcs/constrs_1/new/constr.xdc [current_fileset -constrset]
save_constraints -force
set_property needs_refresh false [get_runs synth_1]
launch_runs impl_1 -jobs 20
wait_on_run impl_1
create_rqs_run -help
set runName run1
create_rqs_run -dir ./report_qor -new_name $runName
set all_runs [get_runs *$runName]
foreach run $all_runs {
reset_run $run
}
delete_runs [get_runs *$runName]
delete_fileset [get_filesets *$runName]
close_project
puts "DONE"
