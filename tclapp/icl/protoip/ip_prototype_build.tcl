
########################################################################################
## 20/11/2014 - First release 1.0
########################################################################################


namespace eval ::tclapp::icl::protoip {
    # Export procs that should be allowed to import into other namespaces
    namespace export ip_prototype_build
}


proc ::tclapp::icl::protoip::ip_prototype_build {args} {

	  # Summary: Build the IP prototype of the project according to the specification in <WORKING DIRECTORY>/doc/project_name/ip_configuration_parameters.txt using Vivado.

	  # Argument Usage:
	  # -project_name <arg>: Project name
	  # -board_name <arg>: Evaluation board name
	  # [-usage]: Usage information

	  # Return Value:
	  # return the built IP prototype with Vivado and the IP prototype report in <WORKING DIRECTORY>/doc/project_name/ip_prototype.txt. If any error occur TCL_ERROR is returned

	  # Categories: 
	  # xilinxtclstore, protoip
	  
uplevel [concat ::tclapp::icl::protoip::ip_prototype_build::ip_prototype_build $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::icl::protoip::ip_prototype_build::ip_prototype_build {
  variable version {20/11/2014}
} ]	  

#**********************************************************************************#
# #******************************************************************************# #
# #                                                                              # #
# #                         M A I N   P R O G R A M                              # #
# #                                                                              # #
# #******************************************************************************# #
#**********************************************************************************#

proc ::tclapp::icl::protoip::ip_prototype_build::ip_prototype_build { args } {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, ultrafast


	proc lshift {inputlist} {
      # Summary :
      # Argument Usage:
      # Return Value:
    
      upvar $inputlist argv
      set arg  [lindex $argv 0]
      set argv [lrange $argv 1 end]
      return $arg
    }  
	  
    #-------------------------------------------------------
    # read command line arguments
    #-------------------------------------------------------
    set error 0
    set help 0
	set project_name {}
    set filename {}
	set fclk {}
    set FPGA_name {}
    set board_name {}
    set type_eth {}
    set mem_base_address {}
    set returnString 0
    while {[llength $args]} {
      set name [lshift args]
      switch -regexp -- $name {
		  -board_name -
        {^-o(u(t(p(ut?)?)?)?)?$} {
             set board_name [lshift args]
             if {$board_name == {}} {
				puts " -E- NO board name specified."
				incr error
             } 
	     }
		 -project_name -
        {^-o(u(t(p(ut?)?)?)?)?$} {
             set project_name [lshift args]
             if {$project_name == {}} {
				puts " -E- NO project name specified."
				incr error
             } 
	     }
         -usage -
		  {^-u(s(a(ge?)?)?)?$} -
		  -help -
		  {^-h(e(lp?)?)?$} {
			   set help 1
		  }
		  ^--version$ {
			   variable version
			   return $version
		  }
        default {
              if {[string match "-*" $name]} {
                puts " -E- option '$name' is not a valid option. Use the -usage option for more details"
                incr error
              } else {
                puts " -E- option '$name' is not a valid option. Use the -usage option for more details"
                incr error
              }
        }
      }
    }
    
	
  if {$help} {
      puts [format {
 Usage: ip_prototype_build
  -project_name <arg>   - Project name
                          It's a mandatory field
  -board_name <arg>     - Evaluation board name
                          It's a mandatory field
  [-usage|-u]           - This help message


 Description: 
  Build the IP prototype of the project named 'project_name' 
  associated to the evaluation board name 'board_name'
  according to the project configuration parameters
  (doc/project_name/ip_configuration_parameters.txt).

  The specified inputs parameters overwrite the one specified into 
  configuration parameters (doc/project_name/ip_configuration_parameters.txt).
 
  The board name must match the FPGA model. Please refer to 
  doc/project_name/ip_configuration_parameters.txt
  for a detailed description.
  
  This command must be run only after 'ip_design_build' command.

 
 Example:
  ip_prototype_build -project_name my_project0 -board_name zedboard


} ]
      # HELP -->
      return {}
    }
	
	if {$error} {
    error " -E- some error(s) happened. Cannot continue. Use the -usage option for more details"
  }
   

if {$error==0} {  

	set  file_name ""
	append file_name ".metadata/" $project_name "_configuration_parameters.dat"
	
	if {$project_name == {}} {
	
			error " -E- NO project name specified. Use the -usage option for more details."
			
		} else {
	
		if {[file exists $file_name] == 0} { 

			set tmp_error ""
			append tmp_error "-E- " $project_name " does NOT exist. Use the -usage option for more details."
			error $tmp_error
			
		} else {
		
		if {$board_name == {}} {
	
			error " -E- NO board name specified. Use the -usage option for more details."
			
		} else {

		
			#load configuration parameters
			set  file_name ""
			append file_name ".metadata/" $project_name "_configuration_parameters.dat"
			set fp [open $file_name r]
			set file_data [read $fp]
			close $fp
			set data [split $file_data "\n"]

			set num_input_vectors [lindex $data 3]
			set num_output_vectors [lindex $data [expr ($num_input_vectors * 5) + 4 + 1]]
			set input_vectors {}
			set input_vectors_length {}
			set input_vectors_type {}
			set input_vectors_integer_length {}
			set input_vectors_fraction_length {}
			set output_vectors {}
			set output_vectors_length {}
			set output_vectors_type {}
			set output_vectors_integer_length {}
			set output_vectors_fraction_length {}

			for {set i 0} {$i < $num_input_vectors} {incr i} {
				lappend input_vectors [lindex $data [expr 4 + ($i * 5)]]
				lappend input_vectors_length [lindex $data [expr 5 + ($i * 5)]]
				lappend input_vectors_type [lindex $data [expr 6 + ($i * 5)]]
				lappend input_vectors_integer_length [lindex $data [expr 7 + ($i * 5)]]
				lappend input_vectors_fraction_length [lindex $data [expr 8 + ($i * 5)]]
			}
			for {set i 0} {$i < $num_output_vectors} {incr i} {
				lappend output_vectors [lindex $data [expr ($num_input_vectors * 5) + 4 + 2 + ($i * 5)]]
				lappend output_vectors_length [lindex $data [expr ($num_input_vectors * 5) + 4 + 3 + ($i * 5)]]
				lappend output_vectors_type [lindex $data [expr ($num_input_vectors * 5) + 4 + 4 + ($i * 5)]]
				lappend output_vectors_integer_length [lindex $data [expr ($num_input_vectors * 5) + 4 + 5 + ($i * 5)]]
				lappend output_vectors_fraction_length [lindex $data [expr ($num_input_vectors * 5) + 4 + 6 + ($i * 5)]]
			}

			set fclk [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 2]] 
			set FPGA_name [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 4]] 
			set old_board_name [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 6]] 
			set type_eth [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 8]] 
			set mem_base_address [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 10]] 
			set num_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 12]] 
			set type_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 14]] 

			
			# update configuration parameters
			
				
			if {$type_eth==0} {
				set type_eth "udp"
			} elseif {$type_eth==1} {
				set type_eth "tcp"
			} 

			# update configuration parameters
			set m 0
			foreach i $input_vectors_type {
				if {$i==1} {
					set input_vectors_type [lreplace $input_vectors_type $m $m "fix"]
				} else {
					set input_vectors_type [lreplace $input_vectors_type $m $m "float"]
				}
				incr m
			}
			set m 0
			foreach i $output_vectors_type {
				if {$i==1} {
					set output_vectors_type [lreplace $output_vectors_type $m $m "fix"]
				} else {
					set output_vectors_type [lreplace $output_vectors_type $m $m "float"]
				}
				incr m
			}
			

			set type_test "none"
			
			if {($FPGA_name=="xc7z020clg484-1" && $board_name=="zedboard") || ($FPGA_name=="xc7z020clg400-1" && $board_name=="microzedboard") || ($FPGA_name=="xc7z020clg484-1" && $board_name=="zc702") || ($FPGA_name=="xc7z045ffg900-2" && $board_name=="zc706")} {
				set flag_compile 1
			} else {
				set flag_compile 0

				error " -E- FPGA name not supported on the selected evaluation board. Use the -usage option for more details."
	
			}
			
			
			if {$flag_compile==1} {
			
			
			
			[::tclapp::icl::protoip::make_template::make_project_configuration_parameters_dat $project_name $input_vectors $input_vectors_length $input_vectors_type $input_vectors_integer_length $input_vectors_fraction_length $output_vectors $output_vectors_length $output_vectors_type $output_vectors_integer_length $output_vectors_fraction_length $fclk $FPGA_name $board_name $type_eth $mem_base_address $num_test $type_test]
			##make configuration parameters readme
			[::tclapp::icl::protoip::make_template::make_ip_configuration_parameters_readme_txt $project_name]


		puts ""
		puts "Calling Vivado to build the FPGA prototype ..."
		
		append source_dir "../../../../ip_design/build/prj/" $project_name "/solution1/impl/ip"
		append target_dir "ip_prototype/build/prj/" $project_name "." $board_name
		
		file delete -force $target_dir
		file mkdir $target_dir
		cd $target_dir

		set vivado_version [version -short]


		create_project prototype
		

		if {$board_name == "zedboard"} {

			# set FPGA
			set_property board_part em.avnet.com:zed:part0:1.0 [current_project]
			
			#create block diagram
			create_bd_design "design_1"

			#Add Zynq IP
			startgroup
			create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
			endgroup
			
			# configure Zynq
			startgroup
			set_property -dict [list CONFIG.PCW_SDIO_PERIPHERAL_FREQMHZ {50} CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} CONFIG.PCW_UIPARAM_DDR_PARTNO {MT41J128M16 HA-15E} CONFIG.PCW_QSPI_PERIPHERAL_ENABLE {1} CONFIG.PCW_QSPI_GRP_FBCLK_ENABLE {1} CONFIG.PCW_ENET0_PERIPHERAL_ENABLE {1} CONFIG.PCW_ENET0_ENET0_IO {MIO 16 .. 27} CONFIG.PCW_SD0_PERIPHERAL_ENABLE {1} CONFIG.PCW_UART1_PERIPHERAL_ENABLE {1} CONFIG.PCW_TTC0_PERIPHERAL_ENABLE {1} CONFIG.PCW_USB0_PERIPHERAL_ENABLE {1} CONFIG.PCW_GPIO_MIO_GPIO_ENABLE {1}] [get_bd_cells processing_system7_0]
			endgroup

			# configure Zynq
			startgroup
			set_property -dict [list CONFIG.PCW_PRESET_BANK1_VOLTAGE {LVCMOS 1.8V} CONFIG.PCW_ENET0_GRP_MDIO_ENABLE {1} CONFIG.PCW_SD0_GRP_CD_ENABLE {1} CONFIG.PCW_SD0_GRP_CD_IO {MIO 47} CONFIG.PCW_SD0_GRP_WP_ENABLE {1} CONFIG.PCW_SD0_GRP_WP_IO {MIO 46} CONFIG.PCW_MIO_16_SLEW {fast} CONFIG.PCW_MIO_17_SLEW {fast} CONFIG.PCW_MIO_18_SLEW {fast} CONFIG.PCW_MIO_19_SLEW {fast} CONFIG.PCW_MIO_20_SLEW {fast} CONFIG.PCW_MIO_21_SLEW {fast} CONFIG.PCW_MIO_22_SLEW {fast} CONFIG.PCW_MIO_23_SLEW {fast} CONFIG.PCW_MIO_24_SLEW {fast} CONFIG.PCW_MIO_25_SLEW {fast} CONFIG.PCW_MIO_26_SLEW {fast} CONFIG.PCW_MIO_27_SLEW {fast} CONFIG.PCW_MIO_28_SLEW {fast} CONFIG.PCW_MIO_29_SLEW {fast} CONFIG.PCW_MIO_30_SLEW {fast} CONFIG.PCW_MIO_31_SLEW {fast} CONFIG.PCW_MIO_32_SLEW {fast} CONFIG.PCW_MIO_33_SLEW {fast} CONFIG.PCW_MIO_34_SLEW {fast} CONFIG.PCW_MIO_35_SLEW {fast} CONFIG.PCW_MIO_36_SLEW {fast} CONFIG.PCW_MIO_37_SLEW {fast} CONFIG.PCW_MIO_38_SLEW {fast} CONFIG.PCW_MIO_39_SLEW {fast} CONFIG.PCW_MIO_40_SLEW {fast} CONFIG.PCW_MIO_41_SLEW {fast} CONFIG.PCW_MIO_42_SLEW {fast} CONFIG.PCW_MIO_43_SLEW {fast} CONFIG.PCW_MIO_44_SLEW {fast} CONFIG.PCW_MIO_45_SLEW {fast} CONFIG.PCW_MIO_52_SLEW {slow} CONFIG.PCW_MIO_53_SLEW {slow}] [get_bd_cells processing_system7_0]
			endgroup

			# save design
			save_bd_design

			#set  IP repository
			set_property ip_repo_paths  $source_dir [current_fileset]
			update_ip_catalog

			#open block diagram
			open_bd_design {prototype.srcs/sources_1/bd/design_1/design_1.bd}

			#connect FPGA pins
			apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]
			
			#add designed IP
			startgroup
			create_bd_cell -type ip -vlnv icl.ac.uk:hls:foo:1.0 foo_0
			endgroup

			#connect IP to ARM processor (AXI slave interface)
			apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/processing_system7_0/M_AXI_GP0" Clk "Auto" }  [get_bd_intf_pins foo_0/S_AXI_BUS_A]
			

			#expose ARM core S_AXI_HP0 port
			startgroup
			set_property -dict [list CONFIG.PCW_USE_S_AXI_HP0 {1} CONFIG.PCW_S_AXI_HP0_DATA_WIDTH {32}] [get_bd_cells processing_system7_0]
			endgroup

			#connect IP to ARM processor (AXI master interface to ARM S_AXI_HP0 )
			apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/foo_0/m_axi_memory_inout" Clk "Auto" }  [get_bd_intf_pins processing_system7_0/S_AXI_HP0]
			
			#set PL clock at fclk
			startgroup
			set_property -dict [list CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ $fclk CONFIG.PCW_EN_CLK0_PORT {1} ] [get_bd_cells processing_system7_0]
			endgroup

			#reset project
			reset_target all [get_files  prototype.srcs/sources_1/bd/design_1/design_1.bd]

			#update IP
			report_ip_status -name ip_status_1 
			open_bd_design {prototype.srcs/sources_1/bd/design_1/design_1.bd}
			current_bd_design design_1
			upgrade_bd_cells [get_bd_cells [list /foo_0 ] ]
			report_ip_status -name ip_status_1 
			validate_bd_design
			save_bd_design

			#make Verilog top layer wrapp
			make_wrapper -files [get_files prototype.srcs/sources_1/bd/design_1/design_1.bd] -top
			add_files -norecurse -force prototype.srcs/sources_1/bd/design_1/hdl/design_1_wrapper.v
			update_compile_order -fileset sources_1
			update_compile_order -fileset sim_1
			save_bd_design
			


		} elseif {$board_name == "microzedboard"} {

			# set FPGA
			set_property board_part em.avnet.com:microzed:part0:1.0 [current_project]
			set_property part xc7z020clg400-1 [current_project]
			
			#create block diagram
			create_bd_design "design_1"

			#Add Zynq IP
			startgroup
			create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
			endgroup
			
			# configure Zynq
			source "../../../../.metadata/MicroZed_PS_properties_v02.tcl"
			
			# save design
			save_bd_design

			#set  IP repository
			set_property ip_repo_paths  $source_dir [current_fileset]
			update_ip_catalog

			#open block diagram
			open_bd_design {prototype.srcs/sources_1/bd/design_1/design_1.bd}
			#connect FPGA pins
			apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]

			#add designed IP
			startgroup
			create_bd_cell -type ip -vlnv icl.ac.uk:hls:foo:1.0 foo_0
			endgroup

			#expose ARM core M_AXI_GP0 port
			startgroup
			set_property -dict [list CONFIG.PCW_USE_M_AXI_GP0 {1}] [get_bd_cells processing_system7_0]
			endgroup

			#connect IP to ARM processor (AXI slave interface)
			apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/processing_system7_0/M_AXI_GP0" Clk "Auto" }  [get_bd_intf_pins foo_0/S_AXI_BUS_A]

			#expose ARM core S_AXI_HP0 port
			startgroup
			set_property -dict [list CONFIG.PCW_USE_S_AXI_HP0 {1} CONFIG.PCW_S_AXI_HP0_DATA_WIDTH {32}] [get_bd_cells processing_system7_0]
			endgroup

			#connect IP to ARM processor (AXI master interface to ARM S_AXI_HP0 )
			apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/foo_0/m_axi_memory_inout" Clk "Auto" }  [get_bd_intf_pins processing_system7_0/S_AXI_HP0]
			
			#set PL clock at fclk
			startgroup
			set_property -dict [list CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ $fclk CONFIG.PCW_EN_CLK0_PORT {1} ] [get_bd_cells processing_system7_0]
			endgroup

			#reset project
			reset_target all [get_files  prototype.srcs/sources_1/bd/design_1/design_1.bd]

			#update IP
			report_ip_status -name ip_status_1 
			open_bd_design {prototype.srcs/sources_1/bd/design_1/design_1.bd}
			current_bd_design design_1
			upgrade_bd_cells [get_bd_cells [list /foo_0 ] ]
			report_ip_status -name ip_status_1 
			validate_bd_design
			save_bd_design

			#make Verilog top layer wrapp
			make_wrapper -files [get_files prototype.srcs/sources_1/bd/design_1/design_1.bd] -top
			add_files -norecurse -force prototype.srcs/sources_1/bd/design_1/hdl/design_1_wrapper.v
			update_compile_order -fileset sources_1
			update_compile_order -fileset sim_1
			save_bd_design
			
		} elseif {$board_name == "zc706"} {

			# set FPGA
			set_property board_part xilinx.com:zc706:part0:1.0 [current_project]
			set_property part xc7z045ffg900-2 [current_project]
			
			#create block diagram
			create_bd_design "design_1"

			# Create interface ports
			set DDR [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 DDR ]
			set FIXED_IO [ create_bd_intf_port -mode Master -vlnv xilinx.com:display_processing_system7:fixedio_rtl:1.0 FIXED_IO ]
			  
			# Create instance: proc_sys_reset, and set properties
			set proc_sys_reset [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset ]

			# Create instance: processing_system7_0, and set properties
			set processing_system7_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0 ]
			set_property -dict [ list CONFIG.PCW_TTC1_PERIPHERAL_ENABLE {1} CONFIG.PCW_WDT_PERIPHERAL_ENABLE {1} CONFIG.preset {ZC706*}  ] $processing_system7_0
			
			connect_bd_intf_net -intf_net processing_system7_0_ddr [get_bd_intf_ports DDR] [get_bd_intf_pins processing_system7_0/DDR]
			connect_bd_intf_net -intf_net processing_system7_0_fixed_io [get_bd_intf_ports FIXED_IO] [get_bd_intf_pins processing_system7_0/FIXED_IO]
			
			# save design
			save_bd_design

			#set  IP repository
			set_property ip_repo_paths  $source_dir [current_fileset]
			update_ip_catalog

			#add designed IP
			startgroup
			create_bd_cell -type ip -vlnv icl.ac.uk:hls:foo:1.0 foo_0
			endgroup
			#connect IP to ARM processor (AXI slave interface)
			apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/processing_system7_0/M_AXI_GP0" Clk "Auto" }  [get_bd_intf_pins foo_0/S_AXI_BUS_A]

			#expose ARM core S_AXI_HP0 port
			startgroup
			set_property -dict [list CONFIG.PCW_USE_S_AXI_HP0 {1} CONFIG.PCW_S_AXI_HP0_DATA_WIDTH {32}] [get_bd_cells processing_system7_0]
			endgroup

			#connect IP to ARM processor (AXI master interface to ARM S_AXI_HP0 )
			apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/foo_0/m_axi_memory_inout" Clk "Auto" }  [get_bd_intf_pins processing_system7_0/S_AXI_HP0]
				
			#set PL clock at fclk
			startgroup
			set_property -dict [list CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ $fclk CONFIG.PCW_EN_CLK0_PORT {1} ] [get_bd_cells processing_system7_0]
			endgroup

			#reset project
			reset_target all [get_files  prototype.srcs/sources_1/bd/design_1/design_1.bd]

			#update IP
			report_ip_status -name ip_status_1 
			open_bd_design {prototype.srcs/sources_1/bd/design_1/design_1.bd}
			current_bd_design design_1
			upgrade_bd_cells [get_bd_cells [list /foo_0 ] ]
			report_ip_status -name ip_status_1 
			validate_bd_design
			save_bd_design

			#make Verilog top layer wrapp
			make_wrapper -files [get_files prototype.srcs/sources_1/bd/design_1/design_1.bd] -top
			add_files -norecurse -force prototype.srcs/sources_1/bd/design_1/hdl/design_1_wrapper.v
			update_compile_order -fileset sources_1
			update_compile_order -fileset sim_1
			save_bd_design
			
		} elseif {$board_name == "zc702"} {

			# set FPGA
			set_property BOARD_PART xilinx.com:zc702:part0:1.0 [current_project]
			set_property part xc7z020clg484-1 [current_project]

			#create block diagram
			create_bd_design "design_1"
			
			#set  IP repository
			set_property ip_repo_paths  $source_dir [current_fileset]
			update_ip_catalog

			#open block diagram
			open_bd_design {prototype.srcs/sources_1/bd/design_1/design_1.bd}

			#Add Zynq IP
			startgroup
				create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
			endgroup
			
			startgroup
			set_property -dict [list CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_0 {0.217} CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_1 {0.133} CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_2 {0.089} CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_3 {0.248} CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY0 {0.537} CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY1 {0.442} CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY2 {0.464} CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY3 {0.521} CONFIG.PCW_SDIO_PERIPHERAL_FREQMHZ {50} CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} CONFIG.PCW_USE_S_AXI_HP0 {0} CONFIG.PCW_S_AXI_HP0_DATA_WIDTH {64} CONFIG.PCW_PRESET_BANK0_VOLTAGE {LVCMOS 1.8V} CONFIG.PCW_PRESET_BANK1_VOLTAGE {LVCMOS 1.8V} CONFIG.PCW_UIPARAM_DDR_PARTNO {MT41J256M8 HX-15E} CONFIG.PCW_UIPARAM_DDR_TRAIN_WRITE_LEVEL {1} CONFIG.PCW_UIPARAM_DDR_TRAIN_READ_GATE {1} CONFIG.PCW_UIPARAM_DDR_TRAIN_DATA_EYE {1} CONFIG.PCW_QSPI_PERIPHERAL_ENABLE {1} CONFIG.PCW_QSPI_GRP_FBCLK_ENABLE {1} CONFIG.PCW_ENET0_PERIPHERAL_ENABLE {1} CONFIG.PCW_ENET0_ENET0_IO {MIO 16 .. 27} CONFIG.PCW_ENET0_RESET_ENABLE {1} CONFIG.PCW_ENET0_RESET_IO {MIO 11} CONFIG.PCW_SD0_PERIPHERAL_ENABLE {1} CONFIG.PCW_UART1_PERIPHERAL_ENABLE {1} CONFIG.PCW_CAN0_PERIPHERAL_ENABLE {1} CONFIG.PCW_CAN0_CAN0_IO {MIO 46 .. 47} CONFIG.PCW_WDT_PERIPHERAL_ENABLE {1} CONFIG.PCW_TTC0_PERIPHERAL_ENABLE {1} CONFIG.PCW_USB0_PERIPHERAL_ENABLE {1} CONFIG.PCW_USB0_RESET_ENABLE {1} CONFIG.PCW_USB0_RESET_IO {MIO 7} CONFIG.PCW_I2C0_PERIPHERAL_ENABLE {1} CONFIG.PCW_I2C0_I2C0_IO {MIO 50 .. 51} CONFIG.PCW_I2C0_RESET_ENABLE {1} CONFIG.PCW_I2C0_RESET_IO {MIO 13} CONFIG.PCW_GPIO_MIO_GPIO_ENABLE {1} CONFIG.PCW_ENET0_PERIPHERAL_FREQMHZ {100 Mbps}] [get_bd_cells processing_system7_0]
			endgroup

			

			#connect FPGA pins
			apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]

			#add designed IP
			startgroup
			create_bd_cell -type ip -vlnv icl.ac.uk:hls:foo:1.0 foo_0
			endgroup

			#connect IP to ARM processor (AXI slave interface)
			apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/processing_system7_0/M_AXI_GP0" Clk "Auto" }  [get_bd_intf_pins foo_0/S_AXI_BUS_A]
			

			#expose ARM core S_AXI_HP0 port
			startgroup
			set_property -dict [list CONFIG.PCW_USE_S_AXI_HP0 {1} CONFIG.PCW_S_AXI_HP0_DATA_WIDTH {32}] [get_bd_cells processing_system7_0]
			endgroup

			#connect IP to ARM processor (AXI master interface to ARM S_AXI_HP0 )
			apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Master "/foo_0/m_axi_memory_inout" Clk "Auto" }  [get_bd_intf_pins processing_system7_0/S_AXI_HP0]
			
			#set PL clock at fclk
			startgroup
			set_property -dict [list CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ $fclk CONFIG.PCW_EN_CLK0_PORT {1} ] [get_bd_cells processing_system7_0]
			endgroup

			#reset project
			reset_target all [get_files  prototype.srcs/sources_1/bd/design_1/design_1.bd]

			#update IP
			report_ip_status -name ip_status_1 
			open_bd_design {prototype.srcs/sources_1/bd/design_1/design_1.bd}
			current_bd_design design_1
			upgrade_bd_cells [get_bd_cells [list /foo_0 ] ]
			report_ip_status -name ip_status_1 
			validate_bd_design
			save_bd_design

			#make Verilog top layer wrapp
			make_wrapper -files [get_files prototype.srcs/sources_1/bd/design_1/design_1.bd] -top
			add_files -norecurse -force prototype.srcs/sources_1/bd/design_1/hdl/design_1_wrapper.v
			update_compile_order -fileset sources_1
			update_compile_order -fileset sim_1
			save_bd_design
			
		}

		#synthesis
		launch_runs synth_1
		wait_on_run synth_1

		#implementation
		launch_runs impl_1
		wait_on_run impl_1

		#bitstream
		launch_runs impl_1 -to_step write_bitstream
		wait_on_run impl_1


		close_project


		cd ../../../../

	
		

		# Make Report
		[::tclapp::icl::protoip::ip_prototype_build::make_ip_prototype_readme_txt $project_name]

		
		
	}
	}
	}
	}

}




	puts ""
    if {$error} {
		puts "Vivado: FPGA prototype built ERROR. Please check Vivado log file at <WORKING_DIRECTORY>/vivado.log  for error(s) info."
		puts ""
		return -code error
    } else {
		puts "Vivado: FPGA prototype built successfully"
		puts ""
		return -code ok
	}

}

#**********************************************************************************#
# #******************************************************************************# #
# #                                                                              # #
# #                      IP PROTOTYPE BUILD PROCEDURES                           # #
# #                                                                              # #
# #******************************************************************************# #
#**********************************************************************************#
  
# ########################################################################################
# make doc/project_name/ip_prototype.txt file

proc ::tclapp::icl::protoip::ip_prototype_build::make_ip_prototype_readme_txt {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:
  

	set project_name [lindex $args 0]
	
	#load configuration parameters
			set  file_name ""
			append file_name ".metadata/" $project_name "_configuration_parameters.dat"
			set fp [open $file_name r]
			set file_data [read $fp]
			close $fp
			set data [split $file_data "\n"]

			set num_input_vectors [lindex $data 3]
			set num_output_vectors [lindex $data [expr ($num_input_vectors * 5) + 4 + 1]]
			set input_vectors {}
			set input_vectors_length {}
			set input_vectors_type {}
			set input_vectors_integer_length {}
			set input_vectors_fraction_length {}
			set output_vectors {}
			set output_vectors_length {}
			set output_vectors_type {}
			set output_vectors_integer_length {}
			set output_vectors_fraction_length {}

			for {set i 0} {$i < $num_input_vectors} {incr i} {
				lappend input_vectors [lindex $data [expr 4 + ($i * 5)]]
				lappend input_vectors_length [lindex $data [expr 5 + ($i * 5)]]
				lappend input_vectors_type [lindex $data [expr 6 + ($i * 5)]]
				lappend input_vectors_integer_length [lindex $data [expr 7 + ($i * 5)]]
				lappend input_vectors_fraction_length [lindex $data [expr 8 + ($i * 5)]]
			}
			for {set i 0} {$i < $num_output_vectors} {incr i} {
				lappend output_vectors [lindex $data [expr ($num_input_vectors * 5) + 4 + 2 + ($i * 5)]]
				lappend output_vectors_length [lindex $data [expr ($num_input_vectors * 5) + 4 + 3 + ($i * 5)]]
				lappend output_vectors_type [lindex $data [expr ($num_input_vectors * 5) + 4 + 4 + ($i * 5)]]
				lappend output_vectors_integer_length [lindex $data [expr ($num_input_vectors * 5) + 4 + 5 + ($i * 5)]]
				lappend output_vectors_fraction_length [lindex $data [expr ($num_input_vectors * 5) + 4 + 6 + ($i * 5)]]
			}

			set fclk [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 2]] 
			set FPGA_name [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 4]] 
			set board_name [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 6]] 
			set type_eth [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 8]] 
			set mem_base_address [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 10]] 
			set num_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 12]] 
			set type_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 14]] 



			
			# #######################################  
			# #######################################  
			# Extract post implementation information (resources and power consumption)
			
			
			# #######################################  
			# Extract the resource utilization
			
			set target_file ""
			append target_file "ip_prototype/build/prj/" $project_name "." $board_name "/prototype.runs/impl_1/design_1_wrapper_utilization_placed.rpt"
			
			# #######################################  
			# Extract the LUT_impl utilization
			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {Slice LUTs} $line all value]} {
				break
			    }
			}
			close $f
			
			set line_size [expr [ string length $line]-1]
			set line [string range $line 1 $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" LUT_impl
			#if the LUT_impl is not available, set it to 0
			if {$LUT_impl == ""} {
				set LUT_impl 0
			}
			
			set line_size [expr [ string length $line]-1]
			set line [string range $line 1 $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" LUT_available
			#if the LUT_available is not available, set it to 0
			if {$LUT_available == ""} {
				set LUT_available 0
			}
			
				# #######################################  
			# Extract the FF_impl utilization
			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {Slice Registers} $line all value]} {
				break
			    }
			}
			close $f
			
			set line_size [expr [ string length $line]-1]
			set line [string range $line 1 $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" FF_impl
			#if the FF_impl is not available, set it to 0
			if {$FF_impl == ""} {
				set FF_impl 0
			}
			
			
			
			set line_size [expr [ string length $line]-1]
			set line [string range $line 1 $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			
			
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" FF_available
			#if the FF_available is not available, set it to 0
			if {$FF_available == ""} {
				set FF_available 0
			}
			
			
			
			
			# #######################################  
			# Extract the BRAM_impl utilization
			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {Block RAM Tile} $line all value]} {
				break
			    }
			}
			close $f
			
			set line_size [expr [ string length $line]-1]
			set line [string range $line 1 $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" BRAM_impl
			#if the BRAM_imp is not available, set it to 0
			if {$BRAM_impl == ""} {
				set BRAM_impl 0
			}
			#convert to BRAM18k
			set BRAM_impl [ expr $BRAM_impl * 2]

			
			set line_size [expr [ string length $line]-1]
			set line [string range $line 1 $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" BRAM_available
			#if the BRAM_available is not available, set it to 0
			if {$BRAM_available == ""} {
				set BRAM_available 0
			}
			
			#convert to BRAM18k
			set BRAM_available [ expr $BRAM_available * 2]
			
			
			
			# #######################################  
			# Extract the DSP48E_impl utilization
			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {DSPs} $line all value]} {
				break
			    }
			}
			close $f
			
			set line_size [expr [ string length $line]-1]
			set line [string range $line 1 $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" DSP48E_impl
			#if the DSP48E_impl is not available, set it to 0
			if {$DSP48E_impl == ""} {
				set DSP48E_impl 0
			}

			set line_size [expr [ string length $line]-1]
			set line [string range $line 1 $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" DSP48E_available
			#if the DSP48E_available is not available, set it to 0
			if {$DSP48E_available == ""} {
				set DSP48E_available 0
			}
			
			
			# #######################################  
			# Extract timing information
			
			set target_file ""
			append target_file "ip_prototype/build/prj/" $project_name "." $board_name "/prototype.runs/impl_1/design_1_wrapper_timing_summary_routed.rpt"
			
			
			# #######################################  
			# Extract the clock target
			set f [open $target_file]
			set file_data [read $f]
			close $f
			
			set data [split $file_data "\n"]
			set count_line 0;
			foreach line $data {
				incr count_line
				if {[regexp {Clock Summary} $line all value]} {
					set target_line [expr [incr count_line 6]]
					break
				}
			}
			
			set count_line 0;
			foreach line $data {
				incr count_line
				if {$count_line == $target_line} {
					break
				}
			}

			
			set line_size [expr [ string length $line]-1]
			set index_pipe [expr [string first "\}" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set line [string range $line 1 11]

			regsub -all -- {[^0-9.-]} $line "" clock_target
			#if the clock_target is not available, set it to 0
			if {$clock_target == ""} {
				set clock_target 0;
			}
			
			# #######################################  
			# Extract the clock achieved
			set f [open $target_file]
			set file_data [read $f]
			close $f
			
			set data [split $file_data "\n"]
			set count_line 0;
			foreach line $data {
				incr count_line
				if {[regexp {Intra Clock Table} $line all value]} {
					set target_line [expr [incr count_line 6]]
					break
				}
			}
			
			set count_line 0;
			foreach line $data {
				incr count_line
				if {$count_line == $target_line} {
					break
				}
			}
			
			
			set line [string range $line 15 28]
			puts $line
			regsub -all -- {[^0-9.-]} $line "" clk_achieved
			puts $clk_achieved
			#if the clk_achieved is not available, set it to 0
			if {$clk_achieved == ""} {
				set clk_achieved 0
			}
			
				
			# #######################################  
			# Extract the power utilization
			
			set target_file ""
			append target_file "ip_prototype/build/prj/" $project_name "." $board_name "/prototype.runs/impl_1/design_1_wrapper_power_routed.rpt"
			
			# #######################################  
			# Extract the PW_total
			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {Total On-Chip Power} $line all value]} {
				break
			    }
			}
			close $f
			
			set line_size [expr [ string length $line]-1]
			set line [string range $line 1 $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" PW_total
			#if the PW_total is not available, set it to 0
			if {$PW_total == ""} {
				set PW_total 0
			}

			
			
			# #######################################  
			# Extract the PW_dyn
			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {Dynamic} $line all value]} {
				break
			    }
			}
			close $f
			
			set line_size [expr [ string length $line]-1]
			set line [string range $line 1 $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" PW_dyn
			#if the PW_dyn is not available, set it to 0
			if {$PW_dyn == ""} {
				set PW_dyn 0
			}

			
			# #######################################  
			# Extract the PW_sta
			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {Device Static} $line all value]} {
				break
			    }
			}
			close $f
			
			set line_size [expr [ string length $line]-1]
			set line [string range $line 1 $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" PW_sta
			#if the PW_sta is not available, set it to 0
			if {$PW_sta == ""} {
				set PW_sta 0
			}

			
			# #######################################  
			# Extract the PW_PS7
			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {PS7} $line all value]} {
				break
			    }
			}
			close $f
			
			set line_size [expr [ string length $line]-1]
			set line [string range $line 1 $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" PW_PS7
			#if the PW_PS7 is not available, set it to 0
			if {$PW_PS7 == ""} {
				set PW_PS7 0
			}

			set PW_logic [expr $PW_total - $PW_PS7]
			
					
			

			# ####################################### 
			# Write report file
			# Make IP synthesis report
			

			set dir_name ""
			append dir_name "doc/" $project_name
			file mkdir $dir_name

			set  file_name ""
			append file_name "doc/" $project_name "/ip_prototype.txt"

			set file [open $file_name w]


			puts $file "---------------------------------------------------------"
			puts $file "Input and output vectors:"
			puts $file "---------------------------------------------------------"
			puts $file ""
			puts $file "Name			| Direction		| Number of data 			| Data representation"
			puts $file ""
			set m 0
			foreach i $input_vectors { 
				set tmp_line ""
				append tmp_line $i "			 	| Input         | [string toupper [lindex $input_vectors $m]]_IN_LENGTH=[lindex $input_vectors_length $m] 			|data type \"data_t_" $i "_in\" is "
				if {[lindex $input_vectors_type $m]==0} { #floating point
					append tmp_line "floating-point single precision (32 bits)"
				} else {
					append tmp_line "fixed-point: " [string toupper [lindex $input_vectors $m]] "_IN_INTEGERLENGTH=" [lindex $input_vectors_integer_length $m] "  bits integer length, " [string toupper [lindex $input_vectors $m]] "_IN_FRACTIONLENGTH=" [lindex $input_vectors_fraction_length $m] "  bits fraction length"
				}
				puts $file $tmp_line
				incr m
			}
			set m 0
			foreach i $output_vectors {
				set tmp_line ""
				append tmp_line $i "			 	| Output         | [string toupper [lindex $output_vectors $m]]_OUT_LENGTH=[lindex $output_vectors_length $m] 			|data type \"data_t_" $i "_in\" is "
				if {[lindex $output_vectors_type $m]==0} { #floating point
					append tmp_line "floating-point single precision (32 bits)"
				} else {
					append tmp_line "fixed-point: " [string toupper [lindex $output_vectors $m]] "_OUT_INTEGERLENGTH=" [lindex $output_vectors_integer_length $m] "  bits integer length, " [string toupper [lindex $output_vectors $m]] "_OUT_FRACTIONLENGTH=" [lindex $output_vectors_fraction_length $m] "  bits fraction length"
				}
				puts $file $tmp_line
				incr m

			}

			puts $file ""
			puts $file ""
			puts $file "---------------------------------------------------------"
			puts $file "IP prototype test(s):"
			puts $file "Input and output vectors has been mapped into external DDR3 memory at the following addresses:"
			puts $file "---------------------------------------------------------"
			puts $file ""
			puts $file "Name			| Base address in Byte"
			puts $file ""
			set vectors_list [concat $input_vectors $output_vectors]
			set vectors_list_length [concat $input_vectors_length $output_vectors_length]
			set address_store_name "0"
			set address_store $mem_base_address
			set m 0
			foreach i $input_vectors { 
					set tmp_line ""
					append tmp_line $i "			 	| 0x[format %08X $address_store] <- $address_store_name"
					puts $file $tmp_line
					unset tmp_line
					set address_store [expr $address_store+([lindex $vectors_list_length $m])*4]
					set address_store_name {(}
					for {set j 0} {$j <= $m} {incr j} {
						append address_store_name "[string toupper [lindex $input_vectors $j]]_IN_LENGTH"
						if {$j==$m} {
							append address_store_name ")*4"
						} else {
							append address_store_name "+"
						}
					}
					incr m
			}

			foreach i $output_vectors {
					set tmp_line ""
					append tmp_line $i "			 	| 0x[format %08X $address_store] <- $address_store_name"
					puts $file $tmp_line
					unset tmp_line
					set address_store [expr $address_store+([lindex $vectors_list_length $m])*4]
					set address_store_name {(}
					set count_j 0
					foreach j $input_vectors { 
						append address_store_name "[string toupper $j]_IN_LENGTH+"
						incr count_j
					}
					for {set j $count_j} {$j <= $m} {incr j} {
						append address_store_name "[string toupper [lindex $output_vectors [expr $j-$count_j]]]_OUT_LENGTH"
						if {$j==$m} {
							append address_store_name ")*4"
						} else {
							append address_store_name "+"
						}
					}
					incr m
			}



			puts $file ""
			puts $file "NOTE: the external DDR memory is shared memory between the CPU embedded into the FPGA and the Algorithm implemented into the FPGA programmable logic (PL)."
			puts $file ""
			puts $file ""
			puts $file "To send input vectors from the host (Matlab) to the FPGA call Matlab function \"FPGAclientMATLAB\" in \"test_HIL.m\" using the following parameters:"
			puts $file ""
			puts $file "Input vector name		| Packet type 	|	Packet internal ID 	| Data to send	| Packet output size"
			set m 0
			foreach i $input_vectors { 
					append tmp_line $i "			 			| 3				| " $m "						| data vector	| 0"
					puts $file $tmp_line
					unset tmp_line
					incr m
			}
			puts $file ""
			puts $file ""
			puts $file ""
			puts $file "To read output vectors from the FPGA to the host PC call Matlab function \"FPGAclientMATLAB\" in \"test_HIL.m\" using the following parameters:"
			puts $file ""
			puts $file "Output vector name		| Packet type 	|	Packet internal ID 	| Data to send	| Packet output size"
			set m 0
			foreach i $output_vectors { 
					append tmp_line $i "			 			| 4				| " $m "						| 0				| [lindex $output_vectors_length $m]"
					puts $file $tmp_line
					unset tmp_line
					incr m
			}

			
			
			
			puts $file ""
			puts $file ""
			
			puts $file "---------------------------------------------------------"
			set tmp_line ""
			append tmp_line "FPGA prototype report: " $project_name "." $board_name
			puts $file $tmp_line
			puts $file "---------------------------------------------------------"
			puts $file ""
			puts $file ""
			set tmp_line ""
			append tmp_line "clock target (ns): " $clock_target
			puts $file $tmp_line
			if [expr $clk_achieved < 0] {
				set tmp_line ""
				append tmp_line "clock slack (ns): " [expr $clk_achieved * -1]
				puts $file $tmp_line

				puts $file "Time constraints NOT met during IP prototyping. You have to increase clock target period to met time constraints."	

				
			} else {
				set tmp_line ""
				append tmp_line "clock achieved (ns): " $clk_achieved
				puts $file $tmp_line
				
				puts $file "Time constraints met during IP prototyping. You might reduce clock target period to build a faster design."
			}
			
			


			puts $file ""
			if [expr $BRAM_impl <= $BRAM_available] { 
				set tmp_line ""
				append tmp_line "BRAM_18K: " $BRAM_impl " (" [expr $BRAM_impl * 100 / $BRAM_available] "%) used out off " $BRAM_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "BRAM_18K: " $BRAM_impl " (" [expr $BRAM_impl * 100 / $BRAM_available] "%) used out off " $BRAM_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $DSP48E_impl <= $DSP48E_available] { 
				set tmp_line ""
				append tmp_line "DSP48E: " $DSP48E_impl  " (" [expr $DSP48E_impl * 100 / $DSP48E_available] "%) used out off " $DSP48E_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "DSP48E: " $DSP48E_impl  " (" [expr $DSP48E_impl * 100 / $DSP48E_available] "%) used out off " $DSP48E_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $FF_impl <= $FF_available] { 
				set tmp_line ""
				append tmp_line "FF: " $FF_impl " (" [expr $FF_impl * 100 / $FF_available] "%) used out off " $FF_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "FF: " $FF_impl " (" [expr $FF_impl * 100 / $FF_available] "%) used out off " $FF_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $LUT_impl <= $LUT_available] { 
				set tmp_line ""
				append tmp_line "LUT: " $LUT_impl " (" [expr $LUT_impl * 100 / $LUT_available] "%)  used out off " $LUT_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "LUT: " $LUT_impl " (" [expr $LUT_impl * 100 / $LUT_available] "%)  used out off " $LUT_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			set tmp_line ""
			
						
			puts $file ""
			set tmp_line ""
			append tmp_line "Power total on-chip (W): " $PW_total
			puts $file $tmp_line
			set tmp_line ""
			append tmp_line "Power dynamic (W): " $PW_dyn
			puts $file $tmp_line
			set tmp_line ""
			append tmp_line "Power device static (W) " $PW_sta
			puts $file $tmp_line
			set tmp_line ""
			append tmp_line "Power ARM Cortex-A9 (W): " $PW_PS7
			puts $file $tmp_line
			set tmp_line ""
			append tmp_line "Power programmable logic (W): " $PW_logic
			puts $file $tmp_line
			
			
			close $file  
  

			set f [open $file_name]
			set file_data [read $f]
			close $f
			
			set data [split $file_data "\n"]


			foreach i $data {

				puts $i
			}
			
			
			
			
			
		
	return -code ok
}
