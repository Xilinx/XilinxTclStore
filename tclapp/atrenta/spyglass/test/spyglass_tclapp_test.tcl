create_project project_1 ./project_1 -part xc7k70tfbg676-1 -force
set_property target_language VHDL [current_project]

instantiate_example_design -template xilinx.com:design:wave_gen:1.0  

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

source $test_dir/../write_spyglass_script.tcl

set design_top [find_top]

::tclapp::atrenta::spyglass::write_spyglass_script $design_top $test_dir/spy_run.prj
