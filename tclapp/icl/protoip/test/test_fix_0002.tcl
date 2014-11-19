# Set the File Directory to the current directory location of the script
set file_dir [file normalize [file dirname [info script]]]
set unit_test [file rootname [file tail [info script]]]

# Set the Xilinx Tcl App Store Repository to the current repository location
puts "== Unit Test directory: $file_dir"
puts "== Unit Test name: $unit_test"
set working_dir [pwd]
puts "== Unit Test working directory: $working_dir"

# ##############################
# Test: validate and build an IP prototype named "my_project1" starting form the template project

#copy  my_project1 into my_project2 
tclapp::icl::protoip::ip_design_duplicate -from my_project1 -to my_project2
#run a C simulation of the IP project  template named my_project1
tclapp::icl::protoip::ip_design_test -project_name my_project2 -num_test 1 -type_test c  -input x0:2:fix:5:5 -input x1:1:fix:5:5 -output y0:2:fix:4:6
#run a RTL simulation of the IP project  template named my_project1
tclapp::icl::protoip::ip_design_test -project_name my_project2 -num_test 1 -type_test xsim 
#build the Vivado HLS project of the IP project  template 
tclapp::icl::protoip::ip_design_build -project_name my_project2  -fclk 100 -FPGA_name xc7z020clg400-1
#build the Vivado project of the IP prototype
tclapp::icl::protoip::ip_prototype_build -project_name my_project2 -board_name microzedboard

# ##############################
# copy test results

# copy C/RTL simulation resultas
set target_dir ""
append target_dir $file_dir "/src/test_fix_0002/test_CRTL"
file mkdir $target_dir

set source_dir ""
append source_dir [pwd] "/ip_design/test/results/my_project2"
set file_list [glob -directory $source_dir *.dat]

foreach i $file_list {
	file copy -force $i $target_dir
}

# copy reports
set target_dir ""
append target_dir $file_dir "/src/test_fix_0002"
file mkdir $target_dir

set source_dir ""
append source_dir [pwd] "/doc/my_project2"
set file_list [glob -directory $source_dir *.txt]

foreach i $file_list {
	file copy -force $i $target_dir
}




## # ##########################################
 # # uncomment the TCL scripts here below ONLY if a microzedboard is connected
 # 
 # #build the FPGA server project with SDK and program the FPGA (microzedboard)
 # tclapp::icl::protoip::ip_prototype_load -project_name my_project2
 # #test the prototype IP with the built HIL setup
 # tclapp::icl::protoip::ip_prototype_test -project_name my_project2 -num_test 10
 ##

return 0
