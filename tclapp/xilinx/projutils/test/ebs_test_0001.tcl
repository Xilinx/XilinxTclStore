set file_dir [file normalize [file dirname [info script]]]

puts "== Unit Test directory: $file_dir"
#set ::env(XILINX_TCLAPP_REPO) [file normalize [file join $file_dir .. .. ..]]

#puts "== Application directory: $::env(XILINX_TCLAPP_REPO)"
#lappend auto_path $::env(XILINX_TCLAPP_REPO)

set name "ebs_test_0001"

create_project $name ./$name -force -part xc7k325tffg900-2
set_property board_part xilinx.com:kc705:part0:1.2 [current_project]
set bd_name "base_microblaze_design"
create_bd_design $bd_name -mode batch
instantiate_template_bd_design -template base_microblaze -design base_microblaze_design
set_property target_language VHDL [current_project]
close_bd_design [get_bd_designs base_microblaze_design]

set bd_file [get_files base_microblaze_design.bd]
set bd_dir [file dirname $bd_file]

# This test does not set the BD for OOC synthesis.

generate_target all $bd_file

# This will generate all of the runs for the IP in the BD and launch them.
# It is more straightforward than trying to launch all the IP runs
# and waiting on them.
launch_runs synth_1
wait_on_run synth_1

export_bd_synth $bd_file

set check_file [file join $bd_dir "${bd_name}_stub.v"]
::tclapp::xilinx::projutils::validate { file exists $check_file } "1" "ERROR: Failed to generate file $check_file."
append check_file "hd"
::tclapp::xilinx::projutils::validate { file exists $check_file } "1" "ERROR: Failed to generate file $check_file."
set check_file [file join $bd_dir "${bd_name}.dcp"]
::tclapp::xilinx::projutils::validate { file exists $check_file } "1" "ERROR: Failed to generate file $check_file."

close_project
