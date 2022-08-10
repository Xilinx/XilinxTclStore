set_property IOSTANDARD LVCMOS18 [get_ports {led_pins[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_pins[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_pins[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_pins[3]}]
set_property DRIVE 12 [get_ports {led_pins[0]}]
set_property DRIVE 12 [get_ports {led_pins[1]}]
set_property DRIVE 12 [get_ports {led_pins[2]}]
set_property DRIVE 12 [get_ports {led_pins[3]}]
set_property SLEW SLOW [get_ports {led_pins[0]}]
set_property SLEW SLOW [get_ports {led_pins[1]}]
set_property SLEW SLOW [get_ports {led_pins[2]}]
set_property SLEW SLOW [get_ports {led_pins[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_pins[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_pins[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_pins[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_pins[7]}]
set_property DRIVE 12 [get_ports {led_pins[4]}]
set_property DRIVE 12 [get_ports {led_pins[5]}]
set_property DRIVE 12 [get_ports {led_pins[6]}]
set_property DRIVE 12 [get_ports {led_pins[7]}]
set_property SLEW SLOW [get_ports {led_pins[4]}]
set_property SLEW SLOW [get_ports {led_pins[5]}]
set_property SLEW SLOW [get_ports {led_pins[6]}]
set_property SLEW SLOW [get_ports {led_pins[7]}]
set_property IOSTANDARD LVDS [get_ports clk_pin_p]
set_property IOSTANDARD LVCMOS18 [get_ports dac_clr_n_pin]
set_property IOSTANDARD LVCMOS18 [get_ports dac_cs_n_pin]
set_property IOSTANDARD LVCMOS18 [get_ports lb_sel_pin]
set_property IOSTANDARD LVCMOS18 [get_ports rst_pin]
set_property IOSTANDARD LVCMOS18 [get_ports rxd_pin]
set_property IOSTANDARD LVCMOS18 [get_ports spi_clk_pin]
set_property IOSTANDARD LVCMOS18 [get_ports spi_mosi_pin]
set_property IOSTANDARD LVCMOS18 [get_ports txd_pin]

set_property PACKAGE_PIN C6 [get_ports {led_pins[0]}]
set_property PACKAGE_PIN B6 [get_ports {led_pins[1]}]
set_property PACKAGE_PIN B5 [get_ports {led_pins[2]}]
set_property PACKAGE_PIN A5 [get_ports {led_pins[3]}]
set_property PACKAGE_PIN G8 [get_ports {led_pins[4]}]
set_property PACKAGE_PIN F7 [get_ports {led_pins[5]}]
set_property PACKAGE_PIN G6 [get_ports {led_pins[6]}]
set_property PACKAGE_PIN F6 [get_ports {led_pins[7]}]
set_property PACKAGE_PIN D7 [get_ports clk_pin_p]
set_property PACKAGE_PIN D6 [get_ports clk_pin_n]
set_property PACKAGE_PIN C9 [get_ports dac_clr_n_pin]
set_property PACKAGE_PIN B9 [get_ports dac_cs_n_pin]
set_property PACKAGE_PIN B8 [get_ports lb_sel_pin]
set_property PACKAGE_PIN A7 [get_ports rst_pin]
set_property PACKAGE_PIN A6 [get_ports rxd_pin]
set_property PACKAGE_PIN A9 [get_ports spi_clk_pin]
set_property PACKAGE_PIN A8 [get_ports spi_mosi_pin]
set_property PACKAGE_PIN C8 [get_ports txd_pin]

set_property IOB TRUE [all_fanin -only_cells -startpoints_only -flat [all_outputs]]


