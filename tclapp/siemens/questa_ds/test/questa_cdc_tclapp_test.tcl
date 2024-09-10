create_project project_1 ./project_1 -part xc7k70tfbg676-1 -force
set_property target_language VHDL [current_project]

instantiate_example_design -template xilinx.com:design:wave_gen:1.0  

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

source $test_dir/../questa_ds_vivado_script.tcl

set design_top [find_top]
puts "::tclapp::siemens::questa_ds::write_questa_cdc_script $design_top -output_directory $test_dir/test1_out -use_existing_xdc"
::tclapp::siemens::questa_ds::write_questa_cdc_script $design_top -output_directory $test_dir/test1_out -use_existing_xdc
