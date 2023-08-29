create_project project_2 ./project_2 -part xc7k70tfbg676-1 -force
set_property target_language VHDL [current_project]

instantiate_example_design -template xilinx.com:design:wave_gen:1.0  

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

launch_runs synth_1
wait_on_run synth_1
open_run synth_1

source $test_dir/../write_questa_cdc_script.tcl

set design_top [find_top]
puts "::tclapp::mentor::questa_cdc::write_questa_cdc_script $design_top -output_directory $test_dir/test2_out"
::tclapp::mentor::questa_cdc::write_questa_cdc_script $design_top -output_directory $test_dir/test2_out
