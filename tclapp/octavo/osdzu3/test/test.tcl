set appName {octavo::osdzu3}
set listInstalledApps [::tclapp::list_apps]

# Set the File Directory to the current directory location of the script
set file_dir [file normalize [file dirname [info script]]]
set unit_test [file rootname [file tail [info script]]]

# Set the Xilinx Tcl App Store Repository to the current repository location
puts "== Unit Test directory: $file_dir"
puts "== Unit Test name: $unit_test"

# Set the Name to the name of the script
set name wave_gen

# Load the Design Checkpoint for the specific test
set src_dir "$file_dir/src"
set_part "xczu3eg-sfvc784-1-e"

read_verilog   $src_dir/sources_1/imports/Sources/kintex7/clogb2.vh
read_verilog   $src_dir/sources_1/imports/Sources/kintex7/clk_div.v
read_verilog   $src_dir/sources_1/imports/Sources/kintex7/clk_gen.v
read_verilog   $src_dir/sources_1/imports/Sources/kintex7/clkx_bus.v
read_verilog   $src_dir/sources_1/imports/Sources/kintex7/cmd_parse.v
read_verilog   $src_dir/sources_1/imports/Sources/kintex7/dac_spi.v
read_verilog   $src_dir/sources_1/imports/Sources/kintex7/debouncer.v
read_verilog   $src_dir/sources_1/imports/Sources/kintex7/lb_ctl.v
read_verilog   $src_dir/sources_1/imports/Sources/kintex7/meta_harden.v
read_verilog   $src_dir/sources_1/imports/Sources/kintex7/out_ddr_flop.v
read_verilog   $src_dir/sources_1/imports/Sources/kintex7/reset_bridge.v
read_verilog   $src_dir/sources_1/imports/Sources/kintex7/resp_gen.v
read_verilog   $src_dir/sources_1/imports/Sources/kintex7/rst_gen.v
read_verilog   $src_dir/sources_1/imports/Sources/kintex7/samp_gen.v
read_verilog   $src_dir/sources_1/imports/Sources/kintex7/samp_ram.v
read_verilog   $src_dir/sources_1/imports/Sources/kintex7/to_bcd.v
read_verilog   $src_dir/sources_1/imports/Sources/kintex7/uart_baud_gen.v
read_verilog   $src_dir/sources_1/imports/Sources/kintex7/uart_rx.v
read_verilog   $src_dir/sources_1/imports/Sources/kintex7/uart_rx_ctl.v
read_verilog   $src_dir/sources_1/imports/Sources/kintex7/uart_tx.v
read_verilog   $src_dir/sources_1/imports/Sources/kintex7/uart_tx_ctl.v
read_verilog   $src_dir/sources_1/imports/Sources/kintex7/wave_gen.v
import_ip      $src_dir/sources_1/ip/char_fifo/char_fifo.xci
import_ip      $src_dir/sources_1/ip/clk_core/clk_core.xci
read_xdc       $src_dir/constrs_1/imports/xc7k70tfbg676-1/wave_gen_timing.xdc
read_xdc       $src_dir/constrs_1/imports/xc7k70tfbg676-1/wave_gen_pins.xdc

upgrade_ip [get_ips char_fifo]
upgrade_ip [get_ips clk_core]
generate_target all [get_ips char_fifo] -force
generate_target all [get_ips clk_core] -force
synth_ip [get_ips char_fifo] -force
synth_ip [get_ips clk_core] -force
synth_design -top wave_gen -part xczu3eg-sfvc784-1-e -include_dirs $src_dir/sources_1/imports/Sources
opt_design
place_design
route_design
write_checkpoint -force ${file_dir}/${name}_routed.dcp

open_checkpoint $file_dir/${name}_routed.dcp

#tclapp::refresh_catalog

if {[lsearch -exact $listInstalledApps $appName] != -1} {
  # Uninstall the app if it is already installed
  ::tclapp::unload_app $appName
  ::tclapp::install $appName
}

# Install the app and require the package
catch "package forget ::tclapp::${appName}"
::tclapp::load_app $appName
package require ::tclapp::${appName}

# Run the write_slr_pblock_xdc script and verify that no error was reported
if {[catch { ::tclapp::octavo::osdzu3::osdzu3_export_xdc } catchErrorString]} {
    close_design
    error [format " -E- Unit test ${file_dir}/${name}_routed failed: %s" $catchErrorString]   
}

close_design

# Clean up the generated files from the script run
# Wait 10 seconds then delete files on disk
puts "Wait 10 seconds then delete files on disk"
set seconds "10"
set expiry [expr {$seconds + [clock seconds]}]
while {[clock seconds] < $expiry} {}

puts "Delete generated files"
file delete -force "./.gen"
file delete -force "./.srcs"
file delete -force "./.Xil"
file delete -force "./src/sources_1/ip/char_fifo/.Xil"
file delete -force "./src/sources_1/ip/clk_core/.Xil"
file delete -force "./impl_xdc.xdc"
file delete -force "./osdzu3_io_delay.tcl"
file delete -force "./osdzu3_package_osdzu3_timing.xdcpins.tcl"
file delete -force "./osdzu3_timing.xdc"
file delete -force "./osdzu3_package_pins.tcl"
file delete -force "${file_dir}/${name}_routed.dcp"

return 0
