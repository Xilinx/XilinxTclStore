# Set the File Directory to the current directory location of the script
set file_dir [file normalize [file dirname [info script]]]
set unit_test [file rootname [file tail [info script]]]

# Set the Xilinx Tcl App Store Repository to the current repository location
puts "== Unit Test directory: $file_dir"
puts "== Unit Test name: $unit_test"

#copy  my_project1 into my_project0
tclapp::icl::protoip::ip_design_duplicate -from my_project1 -to my_project0
#run a C simulation of the IP project  template named my_project1
tclapp::icl::protoip::ip_design_test -project_name my_project0 -num_test 2 -type_test c  -input x0:1:float -input x1:2:float -output y0:4:float
#run a RTL simulation of the IP project  template named my_project1
tclapp::icl::protoip::ip_design_test -project_name my_project0 -num_test 1 -type_test xsim 
#build the Vivado HLS project of the IP project  template 
tclapp::icl::protoip::ip_design_build -project_name my_project0 -FPGA_name xc7z020clg484-1
#nuild the Vivado project of the IP prototype
tclapp::icl::protoip::ip_prototype_build -project_name my_project0 -board_name zedboard


# ##############################
# copy test results

# copy C/RTL simulation resultas
set target_dir ""
append target_dir $file_dir "/src/test_float_0001/test_CRTL"
file mkdir $target_dir

set source_dir ""
append source_dir [pwd] "/ip_design/test/results/my_project0"
set file_list [glob -directory $source_dir *.dat]

foreach i $file_list {
	file copy -force $i $target_dir
}

# copy reports
set target_dir ""
append target_dir $file_dir "/src/test_float_0001"
file mkdir $target_dir

set source_dir ""
append source_dir [pwd] "/doc/my_project0"
set file_list [glob -directory $source_dir *.txt]

foreach i $file_list {
	file copy -force $i $target_dir
}




## # ##########################################
 # # uncomment the TCL scripts here below ONLY if a Zedboard is connected
 # 
 # #build the FPGA server project with SDK and program the FPGA (zedboard)
 # tclapp::icl::protoip::ip_prototype_load -project_name my_project0
 # #test the prototype IP with the built HIL setup
 # tclapp::icl::protoip::ip_prototype_test -project_name my_project0 -num_test 5
 # 
 ##

return 0
