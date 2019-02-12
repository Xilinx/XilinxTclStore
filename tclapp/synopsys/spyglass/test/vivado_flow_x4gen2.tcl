# Vivado Launch Script

#### Change design settings here #######
set design vfifo_controller_base_x4_gen2
set top vfifo_controller
set device xc7k325t-2-ffg900
set proj_dir vivado_proj_1
########################################

# Project Settings
open_project "$test_dir/${proj_dir}/vfifo_controller_base_x4_gen2.xpr"
#set_property top ${top} [current_fileset]
#set_property verilog_define { {RDS=1} {PCIEx4=1} {GEN2_CAP=1} {USE_KC705=1} {USE_DDR3_FIFO=1} {USE_7SERIES=1} } [current_fileset]

# Project Design Files from IP Catalog
#import_ip -files "$test_dir/design/ip_catalog/axis_async_fifo.xci" -name axis_async_fifo 

# Other Custom logic source files
#read_verilog "$test_dir/design/source/virtual_packet_fifo/packetizer/control_word_insert.v"
#read_verilog "$test_dir/design/source/virtual_packet_fifo/packetizer/control_word_strip.v"
#read_verilog "$test_dir/design/source/virtual_packet_fifo/vfifo_controller/address_manager.v"
#read_verilog "$test_dir/design/source/virtual_packet_fifo/vfifo_controller/egress_fifo.v"
#read_verilog "$test_dir/design/source/virtual_packet_fifo/vfifo_controller/ingress_fifo.v"
#read_verilog "$test_dir/design/source/virtual_packet_fifo/vfifo_controller/vfifo_controller.v"

#Setting Synthesis options
#set_property flow {Vivado Synthesis 2015} [get_runs synth_1]

#Setting Implementation options
#set_property flow {Vivado Implementation 2015} [get_runs impl_1]

#generate_target all [get_ips]
