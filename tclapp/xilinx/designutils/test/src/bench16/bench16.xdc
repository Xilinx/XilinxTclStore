set_property DONT_TOUCH true [get_cells mux2_inst]

create_clock -name clk -period 10 [get_port clk]

#create_clock -period 10.000 -name clk_MUX [get_pins mux2_inst/mux_out_INST_0/O]
 
#create_generated_clock -name clk_100 -source [get_ports clk] -divide_by 1 [get_pins mmcm_inst/mmcm_adv_inst/CLKOUT0]
#create_generated_clock -name clk_200 -source [get_ports clk] -multiply_by 2 [get_pins mmcm_inst/mmcm_adv_inst/CLKOUT1]


#create_clock -name clk_200i -period 5 [get_port clk2]

set_input_delay 0 -clock CLK_100i_mmcm0 { in1 in2 in3 in4 in5 }

set_input_delay 0 -clock CLK_200i_mmcm0 { in1 in2 in6 in7 in8 in9 }

set_input_delay 0 -clock CLK_166i_mmcm0 -add_delay { in1 in2 }

set_output_delay 0 -clock CLK_100i_mmcm0 { out1 out2 }

set_output_delay 0 -clock CLK_200i_mmcm0 { out3 out4 out5 out6 }
