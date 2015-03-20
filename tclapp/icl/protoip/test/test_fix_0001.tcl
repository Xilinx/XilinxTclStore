# Set the File Directory to the current directory location of the script
set file_dir [file normalize [file dirname [info script]]]
set unit_test [file rootname [file tail [info script]]]

# Set the Xilinx Tcl App Store Repository to the current repository location
puts "== Unit Test directory: $file_dir"
puts "== Unit Test name: $unit_test"
set working_dir [pwd]
puts "== Unit Test working directory: $working_dir"

# ##############################
# Test: validate and build an IP prototype named "my_project1" (template project)

#Create temporary working directory
file mkdir $file_dir/Temp
cd $file_dir/Temp

set target_file ""
append target_file $file_dir "/report_test_fix_0001.txt"

set time_stamp [clock format [clock seconds] -format "%Y-%m-%d_T-%H-%M)"]
set tmp_line "Test test_fix_0001 report ("
append tmp_line $time_stamp
set file [open $target_file a+]
puts $file $tmp_line
puts $file ""
puts $file "------------------------------------------------"
puts $file ""
close $file

# create a new IP project  template named my_project0
tclapp::icl::protoip::make_template -type PL -project_name my_project0 -input x0:3:fix:10:6 -input x1:7:fix:10:6 -output y0:4:fix:10:6
set file [open $target_file a+]
puts $file "== make_template test -> SECCESSFULLY"
close $file
# copy  my_project0 into my_project1 
tclapp::icl::protoip::ip_design_duplicate -from my_project0 -to my_project1
set file [open $target_file a+]
puts $file "== ip_design_duplicate test -> SECCESSFULLY"
close $file
# delete my_project0
tclapp::icl::protoip::ip_design_delete -project_name my_project0
set file [open $target_file a+]
puts $file "== ip_design_delete test -> SECCESSFULLY"
close $file
# make stimuls vectors with random data
tclapp::icl::protoip::make_rand_stimuli -project_name my_project1
set file [open $target_file a+]
puts $file "== make_rand_stimuli test -> SECCESSFULLY"
close $file
# run a C simulation of the IP project  template named my_project1
tclapp::icl::protoip::ip_design_test -project_name my_project1 -type_test c 
set file [open $target_file a+]
puts $file "== ip_design_test C test -> SECCESSFULLY"
close $file
# run a RTL simulation of the IP project  template named my_project1
tclapp::icl::protoip::ip_design_test -project_name my_project1 -type_test xsim 
set file [open $target_file a+]
puts $file "== ip_design_test XSIM test -> SECCESSFULLY"
close $file
# build the Vivado HLS project of the IP project  template 
tclapp::icl::protoip::ip_design_build -project_name my_project1  -fclk 150 
set file [open $target_file a+]
puts $file "== ip_design_build test -> SECCESSFULLY"
close $file
# build the Vivado project of the IP prototype
tclapp::icl::protoip::ip_prototype_build -project_name my_project1 -board_name zedboard
set file [open $target_file a+]
puts $file "== ip_prototype_build test -> SECCESSFULLY"
close $file

file delete -force $file_dir/Temp

set f [open $target_file]
set file_data [read $f]
close $f

set data [split $file_data "\n"]

foreach line $data {
	puts $line
}

file delete -force $target_file





return 0
