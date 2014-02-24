# Part: xc7vx485tffg1157-1

# clock
create_clock -period 20.000 -name clock -waveform {0.000 10.000} [get_ports clk]

# input
set_input_delay -clock [get_clocks clock] -min -rise 0.0 [get_ports {ce din[*] rst}]
set_input_delay -clock [get_clocks clock] -max -rise 1.0 [get_ports {ce din[*] rst}]
set_input_delay -clock [get_clocks clock] -min -fall 5.0 [get_ports {ce din[*] rst}]
set_input_delay -clock [get_clocks clock] -max -fall 6.0 [get_ports {ce din[*] rst}]

# outputs
set_output_delay -clock [get_clocks clock] -min -rise 0.0 [get_ports {dout[*]}]
set_output_delay -clock [get_clocks clock] -max -rise 1.0 [get_ports {dout[*]}]
set_output_delay -clock [get_clocks clock] -min -fall 5.0 [get_ports {dout[*]}]
set_output_delay -clock [get_clocks clock] -max -fall 6.0 [get_ports {dout[*]}]

# io
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

set_property PACKAGE_PIN AN29 [get_ports ce]
set_property PACKAGE_PIN AL31 [get_ports clk]
set_property PACKAGE_PIN AF24 [get_ports {din[0]}]
set_property PACKAGE_PIN AP27 [get_ports {din[1]}]
set_property PACKAGE_PIN AN27 [get_ports {din[2]}]
set_property PACKAGE_PIN AP26 [get_ports {din[3]}]
set_property PACKAGE_PIN AP25 [get_ports {din[4]}]
set_property PACKAGE_PIN AN28 [get_ports {din[5]}]
set_property PACKAGE_PIN AM28 [get_ports {din[6]}]
set_property PACKAGE_PIN AN25 [get_ports {din[7]}]
set_property PACKAGE_PIN AM25 [get_ports {din[8]}]
set_property PACKAGE_PIN AP29 [get_ports {din[9]}]
set_property PACKAGE_PIN AM26 [get_ports {dout[0]}]
set_property PACKAGE_PIN AL26 [get_ports {dout[1]}]
set_property PACKAGE_PIN AL25 [get_ports {dout[2]}]
set_property PACKAGE_PIN AJ25 [get_ports {dout[3]}]
set_property PACKAGE_PIN AH24 [get_ports {dout[4]}]
set_property PACKAGE_PIN AH25 [get_ports {dout[5]}]
set_property PACKAGE_PIN AG25 [get_ports {dout[6]}]
set_property PACKAGE_PIN AJ27 [get_ports {dout[7]}]
set_property PACKAGE_PIN AJ26 [get_ports {dout[8]}]
set_property PACKAGE_PIN AK27 [get_ports {dout[9]}]
set_property PACKAGE_PIN AM27 [get_ports rst]

set_property IOSTANDARD LVCMOS18 [get_ports]
