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

#create a new IP project  template named my_project0
tclapp::icl::protoip::make_template -project_name my_project0 -input x0:3:fix:10:6 -input x1:7:fix:10:6 -output y0:4:fix:10:6
#copy  my_project0 into my_project1 
tclapp::icl::protoip::ip_design_duplicate -from my_project0 -to my_project1
#delete my_project0
tclapp::icl::protoip::ip_design_delete -project_name my_project0
#run a C simulation of the IP project  template named my_project1
tclapp::icl::protoip::ip_design_test -project_name my_project1 -num_test 1 -type_test c 
#run a RTL simulation of the IP project  template named my_project1
tclapp::icl::protoip::ip_design_test -project_name my_project1 -num_test 1 -type_test xsim 
#build the Vivado HLS project of the IP project  template 
tclapp::icl::protoip::ip_design_build -project_name my_project1  -fclk 150 
#build the Vivado project of the IP prototype
tclapp::icl::protoip::ip_prototype_build -project_name my_project1 -board_name zedboard

# ##############################
# copy test results

# copy C/RTL simulation resultas
set target_dir ""
append target_dir $file_dir "/results/test_fix_0001/test_CRTL"
file mkdir $target_dir

set source_dir ""
append source_dir [pwd] "/ip_design/test/results/my_project1"
set file_list [glob -directory $source_dir *.dat]

foreach i $file_list {
	file copy -force $i $target_dir
}

# copy reports
set target_dir ""
append target_dir $file_dir "/results/test_fix_0001"
file mkdir $target_dir

set source_dir ""
append source_dir [pwd] "/doc/my_project1"
set file_list [glob -directory $source_dir *.txt]

foreach i $file_list {
	file copy -force $i $target_dir
}




## # ##########################################
 # # uncomment the TCL scripts here below ONLY if a Zedboard is connected
 # 
 # #build the FPGA server project with SDK and program the FPGA (zedboard)
 # tclapp::icl::protoip::ip_prototype_load -project_name my_project1  -board_name zedboard
 # #test the prototype IP with the built HIL setup
 # tclapp::icl::protoip::ip_prototype_test -project_name my_project1  -board_name zedboard -num_test 10
 ##

return 0
