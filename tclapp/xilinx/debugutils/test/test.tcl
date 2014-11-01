open_checkpoint ./test.dcp
xilinx::debugutils::add_probe -net inst_1/tmp_q[0] -loc H10 -port myprobe1 -iostandard LVCMOS18
xilinx::debugutils::add_probe -net inst_1/tmp_q[1] -loc H10 -port myprobe1
#xilinx::debugutils::add_probe -net inst_1/tmp_q[0] -loc E12 -port rst_n
#xilinx::debugutils::add_probe -net inst_1/tmp_q[1] -loc H10 -port myprobe
#xilinx::debugutils::add_probe -net inst_1/tmp_q[1] -loc H9 -port myprobe1

