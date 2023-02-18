# Set the File Directory to the current directory location of the script
set file_dir [file normalize [file dirname [info script]]]
set unit_test [file rootname [file tail [info script]]]

# Set the Xilinx Tcl App Store Repository to the current repository location
puts "== Unit Test directory: $file_dir"
puts "== Unit Test name: $unit_test"

# Set the Name to the name of the script
set name [file rootname [file tail [info script]]]

# Create in-memory project
create_project project_1 project_1 -part xcvc1902-vsva2197-2MP-e-S

create_bd_design "design_1"
update_compile_order -fileset sources_1
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:gt_bridge_ip:1.1 gt_bridge_ip_0
endgroup
apply_bd_automation -rule xilinx.com:bd_rule:gt_ips -config { DataPath_Interface_Connection {Auto}}  [get_bd_cells gt_bridge_ip_0]
tclapp::update_catalog xilinx::designutils
save_bd_design

# Run the report_gt_refclk_summary script and verify that no error was reported
if {[catch { ::tclapp::xilinx::designutils::report_gt_refclk_summary } catchErrorString]} {
    close_project
    error [format " -E- Unit test project_1 failed: %s" $catchErrorString]   
}

close_project
file delete -force -- project_1

return 0
