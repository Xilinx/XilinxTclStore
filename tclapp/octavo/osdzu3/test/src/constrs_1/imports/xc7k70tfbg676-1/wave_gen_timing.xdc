#
# Global timing constraints
#
# Main clock defined in Clocking Wizard IP XDC

# Create a virual clock for IO constraints
create_clock -period 6.000 -name virtual_clock

set_input_delay -clock [get_clocks -of_objects [get_ports clk_pin_p]] 0.000 [get_ports rxd_pin]
set_input_delay -clock [get_clocks -of_objects [get_ports clk_pin_p]] -min -0.500 [get_ports rxd_pin]

set_input_delay -clock virtual_clock -max 0.000 [get_ports lb_sel_pin]
set_input_delay -clock virtual_clock -min -0.250 [get_ports lb_sel_pin]
set_output_delay -clock virtual_clock -max 0.000 [get_ports {txd_pin {led_pins[*]}}]
set_output_delay -clock virtual_clock -min -0.250 [get_ports {txd_pin {led_pins[*]}}]

# Path specific timing constraints
#create_generated_clock -name spi_clk -source [get_pins dac_spi_i0/out_ddr_flop_spi_clk_i0/ODDR_inst/C] -divide_by 1 -invert [get_ports spi_clk_pin]
create_generated_clock -name spi_clk -source [get_pins dac_spi_i0/out_ddr_flop_spi_clk_i0/ODDRE1_inst/C] -divide_by 1 -invert [get_ports spi_clk_pin]
set_output_delay -clock spi_clk -max 1.000 [get_ports {spi_mosi_pin dac_cs_n_pin dac_clr_n_pin}]
set_output_delay -clock spi_clk -min -1.000 [get_ports {spi_mosi_pin dac_cs_n_pin dac_clr_n_pin}]

set_multicycle_path -from [get_cells {cmd_parse_i0/send_resp_data_reg[*]} -include_replicated_objects] -to [get_cells {resp_gen_i0/to_bcd_i0/bcd_out_reg[*]}] 2
set_multicycle_path -hold -from [get_cells {cmd_parse_i0/send_resp_data_reg[*]} -include_replicated_objects] -to [get_cells {resp_gen_i0/to_bcd_i0/bcd_out_reg[*]}] 1

set_multicycle_path -from [get_cells uart_rx_i0/uart_rx_ctl_i0/* -filter IS_SEQUENTIAL] -to [get_cells uart_rx_i0/uart_rx_ctl_i0/* -filter IS_SEQUENTIAL] 108
set_multicycle_path -hold -from [get_cells uart_rx_i0/uart_rx_ctl_i0/* -filter IS_SEQUENTIAL] -to [get_cells uart_rx_i0/uart_rx_ctl_i0/* -filter IS_SEQUENTIAL] 107

# For 193.75 MHz CLOCK_RATE_TX
#set_multicycle_path -from [get_cells "uart_tx_i0/uart_tx_ctl_i0/*" -filter {IS_SEQUENTIAL}] -to [get_cells "uart_tx_i0/uart_tx_ctl_i0/*" -filter {IS_SEQUENTIAL}] 105
#set_multicycle_path -from [get_cells "uart_tx_i0/uart_tx_ctl_i0/*" -filter {IS_SEQUENTIAL}] -to [get_cells "uart_tx_i0/uart_tx_ctl_i0/*" -filter {IS_SEQUENTIAL}] -hold 104

# For 166.667 MHz CLOCK_RATE_TX
set_multicycle_path -from [get_cells uart_tx_i0/uart_tx_ctl_i0/* -filter IS_SEQUENTIAL] -to [get_cells uart_tx_i0/uart_tx_ctl_i0/* -filter IS_SEQUENTIAL] 90
set_multicycle_path -hold -from [get_cells uart_tx_i0/uart_tx_ctl_i0/* -filter IS_SEQUENTIAL] -to [get_cells uart_tx_i0/uart_tx_ctl_i0/* -filter IS_SEQUENTIAL] 89

create_generated_clock -name clk_samp -source [get_pins clk_gen_i0/clk_core_i0/clk_tx] -divide_by 32 [get_pins clk_gen_i0/BUFGCE_clk_samp_i0/O]
#create_generated_clock -name clk_samp -source [get_pins clk_gen_i0/clk_core_i0/clk_tx] -divide_by 32 [get_pins clk_gen_i0/BUFHCE_clk_samp_i0/O]
#create_generated_clock -name test -source [get_pins clk_gen_i0/clk_core_i0/inst/mmcme4_adv_inst/CLKOUT1] -multiply_by 1

# To keep the synchronizer registers near each other
set_max_delay -from [get_cells clkx_nsamp_i0/meta_harden_bus_new_i0/signal_meta_reg] -to [get_cells clkx_nsamp_i0/meta_harden_bus_new_i0/signal_dst_reg] 2.000
set_max_delay -from [get_cells clkx_pre_i0/meta_harden_bus_new_i0/signal_meta_reg] -to [get_cells clkx_pre_i0/meta_harden_bus_new_i0/signal_dst_reg] 2.000
set_max_delay -from [get_cells clkx_spd_i0/meta_harden_bus_new_i0/signal_meta_reg] -to [get_cells clkx_spd_i0/meta_harden_bus_new_i0/signal_dst_reg] 2.000
set_max_delay -from [get_cells lb_ctl_i0/debouncer_i0/meta_harden_signal_in_i0/signal_meta_reg] -to [get_cells lb_ctl_i0/debouncer_i0/meta_harden_signal_in_i0/signal_dst_reg] 2.000
set_max_delay -from [get_cells samp_gen_i0/meta_harden_samp_gen_go_i0/signal_meta_reg] -to [get_cells samp_gen_i0/meta_harden_samp_gen_go_i0/signal_dst_reg] 2.000
set_max_delay -from [get_cells uart_rx_i0/meta_harden_rxd_i0/signal_meta_reg] -to [get_cells uart_rx_i0/meta_harden_rxd_i0/signal_dst_reg] 2.000
set_max_delay -from [get_cells rst_gen_i0/reset_bridge_clk_rx_i0/rst_meta_reg] -to [get_cells rst_gen_i0/reset_bridge_clk_rx_i0/rst_dst_reg] 2.000
set_max_delay -from [get_cells rst_gen_i0/reset_bridge_clk_tx_i0/rst_meta_reg] -to [get_cells rst_gen_i0/reset_bridge_clk_tx_i0/rst_dst_reg] 2.000
set_max_delay -from [get_cells rst_gen_i0/reset_bridge_clk_samp_i0/rst_meta_reg] -to [get_cells rst_gen_i0/reset_bridge_clk_samp_i0/rst_dst_reg] 2.000

set_false_path -from [get_ports rst_pin]

# To keep the clock crossing registers near each other
set_max_delay -from [get_clocks -of_objects [get_pins clk_gen_i0/clk_core_i0/clk_rx]] -to [get_clocks -of_objects [get_pins clk_gen_i0/clk_core_i0/clk_tx]] 5.000





