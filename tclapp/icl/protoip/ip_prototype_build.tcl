
########################################################################################
## 20/11/2014 - First release 1.0
########################################################################################


namespace eval ::tclapp::icl::protoip {
    # Export procs that should be allowed to import into other namespaces
    namespace export ip_prototype_build
}


proc ::tclapp::icl::protoip::ip_prototype_build {args} {

	  # Summary: Build the IP prototype of the project according to the specification in [WORKING DIRECTORY]/doc/project_name/ip_configuration_parameters.txt using Vivado.

	  # Argument Usage:
	  # -project_name <arg>: Project name
	  # -board_name <arg>: Evaluation board name
	  # [-usage]: Usage information

	  # Return Value:
	  # return the built IP prototype with Vivado and the IP prototype report in [WORKING DIRECTORY]/doc/project_name/ip_prototype.txt. If any error occur TCL_ERROR is returned

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
        {^-b(o(a(r(d(_(n(a(me?)?)?)?)?)?)?)?)?$} {
             set board_name [lshift args]
             if {$board_name == {}} {
				puts " -E- NO board name specified."
				incr error
             } 
	     }
		 -project_name -
        {^-p(r(o(j(e(c(t(_(n(a(me?)?)?)?)?)?)?)?)?)?)?$} {
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
  [WORKING DIRECTORY]/doc/project_name/ip_configuration_parameters.txt

  The specified inputs parameters overwrite the one specified into 
  configuration parameters 
  [WORKING DIRECTORY]/doc/project_name/ip_configuration_parameters.txt
 
  The board name must match the FPGA model. Please refer to 
  [WORKING DIRECTORY]/doc/project_name/ip_configuration_parameters.txt
  for a detailed description.
  
  IP prototype implementation report with resources utilization and power consumption 
  is available in [WORKING DIRECTORY]/doc/project_name/ip_prototype.txt
  
  This command should be run after 'ip_design_build' command only.

 
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
			set type_template [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 16]]
			set type_design_flow [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 18]] 
			
			
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
			
			
			
			[::tclapp::icl::protoip::make_template::make_project_configuration_parameters_dat $project_name $input_vectors $input_vectors_length $input_vectors_type $input_vectors_integer_length $input_vectors_fraction_length $output_vectors $output_vectors_length $output_vectors_type $output_vectors_integer_length $output_vectors_fraction_length $fclk $FPGA_name $board_name $type_eth $mem_base_address $num_test $type_test $type_template $type_design_flow]
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
		set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]
		launch_runs synth_1
		wait_on_run synth_1
		open_run synth_1 -name synth_1
		report_utilization -hierarchical -file synth_resources.txt
		report_power -file synth_power.txt -hier all
		close_design

		#implementation
		launch_runs impl_1
		wait_on_run impl_1
		open_run impl_1 -name impl_1
		report_utilization -hierarchical -file pr_resources.txt
		report_power -file pr_power.txt -hier all
		

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
			# Extract post synthesis information (resources estimation and power estimation)
			

			set target_file ""
			append target_file "ip_prototype/build/prj/" $project_name "." $board_name "/synth_resources.txt"
			
			# #######################################  
			# Extract the FPGA resources utilization
			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {(top)} $line all value]} {
				break
			    }
			}
			close $f
			
			set line_size [expr [ string length $line]-1]
			set line [string range $line 1 $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" FPGA_LUT_synth
			#if the FPGA_LUT_synth is not available, set it to 0
			if {$FPGA_LUT_synth == ""} {
				set FPGA_LUT_synth 0
			}
			
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" FPGA_FF_synth
			#if the FPGA_FF_synth is not available, set it to 0
			if {$FPGA_FF_synth == ""} {
				set FPGA_FF_synth 0
			}
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" FPGA_RAMB36_synth
			#if the FPGA_RAMB36_synth is not available, set it to 0
			if {$FPGA_RAMB36_synth == ""} {
				set FPGA_RAMB36_synth 0
			}
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" FPGA_RAMB18_synth
			#if the FPGA_RAMB18_synth is not available, set it to 0
			if {$FPGA_RAMB18_synth == ""} {
				set FPGA_RAMB18_synth 0
			}
			
			set FPGA_RAMB_synth [ expr ($FPGA_RAMB36_synth * 2) + $FPGA_RAMB18_synth]
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" FPGA_DSP48_synth
			#if the FPGA_DSP48_synth is not available, set it to 0
			if {$FPGA_DSP48_synth == ""} {
				set FPGA_DSP48_synth 0
			}
			
			
			# #######################################  
			# Extract the IP resources utilization
			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {foo_0} $line all value]} {
				break
			    }
			}
			close $f
			
			set line_size [expr [ string length $line]-1]
			set line [string range $line 1 $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" IP_LUT_synth
			#if the IP_LUT_synth is not available, set it to 0
			if {$IP_LUT_synth == ""} {
				set IP_LUT_synth 0
			}
			
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" IP_FF_synth
			#if the IP_FF_synth is not available, set it to 0
			if {$IP_FF_synth == ""} {
				set IP_FF_synth 0
			}
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" IP_RAMB36_synth
			#if the IP_RAMB36_synth is not available, set it to 0
			if {$IP_RAMB36_synth == ""} {
				set IP_RAMB36_synth 0
			}
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" IP_RAMB18_synth
			#if the IP_RAMB18_synth is not available, set it to 0
			if {$IP_RAMB18_synth == ""} {
				set IP_RAMB18_synth 0
			}
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" IP_DSP48_synth
			#if the IP_DSP48_synth is not available, set it to 0
			if {$IP_DSP48_synth == ""} {
				set IP_DSP48_synth 0
			}
			
			set IP_RAMB_synth [ expr ($IP_RAMB36_synth * 2) + $IP_RAMB18_synth]
	
			# #######################################  
			# Extract the user function resources utilization
			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {foo_foo_user} $line all value]} {
				break
			    }
			}
			close $f
			
			set line_size [expr [ string length $line]-1]
			set line [string range $line 1 $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" USER_FUNCTION_LUT_synth
			#if the USER_FUNCTION_LUT_synth is not available, set it to 0
			if {$USER_FUNCTION_LUT_synth == ""} {
				set USER_FUNCTION_LUT_synth 0
			}
			
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" USER_FUNCTION_FF_synth
			#if the USER_FUNCTION_FF_synth is not available, set it to 0
			if {$USER_FUNCTION_FF_synth == ""} {
				set USER_FUNCTION_FF_synth 0
			}
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" USER_FUNCTION_RAMB36_synth
			#if the USER_FUNCTION_RAMB36_synth is not available, set it to 0
			if {$USER_FUNCTION_RAMB36_synth == ""} {
				set USER_FUNCTION_RAMB36_synth 0
			}
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" USER_FUNCTION_RAMB18_synth
			#if the USER_FUNCTION_RAMB18_synth is not available, set it to 0
			if {$USER_FUNCTION_RAMB18_synth == ""} {
				set USER_FUNCTION_RAMB18_synth 0
			}
			
			set USER_FUNCTION_RAMB_synth [ expr ($USER_FUNCTION_RAMB36_synth * 2) + $USER_FUNCTION_RAMB18_synth]
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" USER_FUNCTION_DSP48_synth
			#if the USER_FUNCTION_DSP48_synth is not available, set it to 0
			if {$USER_FUNCTION_DSP48_synth == ""} {
				set USER_FUNCTION_DSP48_synth 0
			}
			
			
			# #######################################  
			# #######################################  
			# Extract post place & route information (resources measurement and power estimation)
			

			set target_file ""
			append target_file "ip_prototype/build/prj/" $project_name "." $board_name "/pr_resources.txt"
			
			# #######################################  
			# Extract the FPGA resources utilization
			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {(top)} $line all value]} {
				break
			    }
			}
			close $f
			
			set line_size [expr [ string length $line]-1]
			set line [string range $line 1 $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" FPGA_LUT_pr
			#if the FPGA_LUT_pr is not available, set it to 0
			if {$FPGA_LUT_pr == ""} {
				set FPGA_LUT_pr 0
			}
			
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" FPGA_FF_pr
			#if the FPGA_FF_pr is not available, set it to 0
			if {$FPGA_FF_pr == ""} {
				set FPGA_FF_pr 0
			}
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" FPGA_RAMB36_pr
			#if the FPGA_RAMB36_pr is not available, set it to 0
			if {$FPGA_RAMB36_pr == ""} {
				set FPGA_RAMB36_pr 0
			}
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" FPGA_RAMB18_pr
			#if the FPGA_RAMB18_pr is not available, set it to 0
			if {$FPGA_RAMB18_pr == ""} {
				set FPGA_RAMB18_pr 0
			}
			
			set FPGA_RAMB_pr [ expr ($FPGA_RAMB36_pr * 2) + $FPGA_RAMB18_pr]
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" FPGA_DSP48_pr
			#if the FPGA_DSP48_pr is not available, set it to 0
			if {$FPGA_DSP48_pr == ""} {
				set FPGA_DSP48_pr 0
			}
			
			
			# #######################################  
			# Extract the IP resources utilization
			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {foo_0} $line all value]} {
				break
			    }
			}
			close $f
			
			set line_size [expr [ string length $line]-1]
			set line [string range $line 1 $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" IP_LUT_pr
			#if the IP_LUT_pr is not available, set it to 0
			if {$IP_LUT_pr == ""} {
				set IP_LUT_pr 0
			}
			
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" IP_FF_pr
			#if the IP_FF_pr is not available, set it to 0
			if {$IP_FF_pr == ""} {
				set IP_FF_pr 0
			}
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" IP_RAMB36_pr
			#if the IP_RAMB36_pr is not available, set it to 0
			if {$IP_RAMB36_pr == ""} {
				set IP_RAMB36_pr 0
			}
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" IP_RAMB18_pr
			#if the IP_RAMB18_pr is not available, set it to 0
			if {$IP_RAMB18_pr == ""} {
				set IP_RAMB18_pr 0
			}
			
			set IP_RAMB_pr [ expr ($IP_RAMB36_pr * 2) + $IP_RAMB18_pr]

			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" IP_DSP48_pr
			#if the IP_DSP48_pr is not available, set it to 0
			if {$IP_DSP48_pr == ""} {
				set IP_DSP48_pr 0
			}
	
			# #######################################  
			# Extract the user function resources utilization
			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {foo_foo_user} $line all value]} {
				break
			    }
			}
			close $f
			
			set line_size [expr [ string length $line]-1]
			set line [string range $line 1 $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" USER_FUNCTION_LUT_pr
			#if the USER_FUNCTION_LUT_pr is not available, set it to 0
			if {$USER_FUNCTION_LUT_pr == ""} {
				set USER_FUNCTION_LUT_pr 0
			}
			
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" USER_FUNCTION_FF_pr
			#if the USER_FUNCTION_FF_pr is not available, set it to 0
			if {$USER_FUNCTION_FF_pr == ""} {
				set USER_FUNCTION_FF_pr 0
			}
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" USER_FUNCTION_RAMB36_pr
			#if the USER_FUNCTION_RAMB36_pr is not available, set it to 0
			if {$USER_FUNCTION_RAMB36_pr == ""} {
				set USER_FUNCTION_RAMB36_pr 0
			}
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" USER_FUNCTION_RAMB18_pr
			#if the USER_FUNCTION_RAMB18_pr is not available, set it to 0
			if {$USER_FUNCTION_RAMB18_pr == ""} {
				set USER_FUNCTION_RAMB18_pr 0
			}
			
			set USER_FUNCTION_RAMB_pr [ expr ($USER_FUNCTION_RAMB36_pr * 2) + $USER_FUNCTION_RAMB18_pr]
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" USER_FUNCTION_DSP48_pr
			#if the USER_FUNCTION_DSP48_pr is not available, set it to 0
			if {$USER_FUNCTION_DSP48_pr == ""} {
				set USER_FUNCTION_DSP48_pr 0
			}
			


			# #######################################  
			# #######################################  
			# Extract available resource 
			
			set target_file ""
			append target_file "ip_prototype/build/prj/" $project_name "." $board_name "/prototype.runs/impl_1/design_1_wrapper_utilization_placed.rpt"
			
			# #######################################  
			# Extract available LUT
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
			set line [string range $line $index_pipe $line_size]

			
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
			# Extract available FF
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
			set line [string range $line $index_pipe $line_size]
		
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
			# Extract available BRAM18
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
			set line [string range $line $index_pipe $line_size]

			
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
			# Extract available DSP48E
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
			set line [string range $line $index_pipe $line_size]


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
			# puts $line
			regsub -all -- {[^0-9.-]} $line "" clk_achieved
			# puts $clk_achieved
			#if the clk_achieved is not available, set it to 0
			if {$clk_achieved == ""} {
				set clk_achieved 0
			}
			
			
			
			
			# #######################################  
			# #######################################  
			# Extract post synthesis power estimation 
			

			set target_file ""
			append target_file "ip_prototype/build/prj/" $project_name "." $board_name "/synth_power.txt"
			
			set line ""
			
			# #######################################  
			# Extract the FPGA power estimation
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
			regsub -all -- {[^0-9.-]} $tmp_str "" FPGA_pw_total_synth
			#if the FPGA_pw_total_synth is not available, set it to 0
			if {$FPGA_pw_total_synth == ""} {
				set FPGA_pw_total_synth 0
			}
			
			# #######################################  
			# Extract the FPGA_pw_dyn_synth
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
			regsub -all -- {[^0-9.-]} $tmp_str "" FPGA_pw_dyn_synth
			#if the FPGA_pw_dyn_synth is not available, set it to 0
			if {$FPGA_pw_dyn_synth == ""} {
				set FPGA_pw_dyn_synth 0
			}

			
			# #######################################  
			# Extract the FPGA_pw_sta_synth
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
			regsub -all -- {[^0-9.-]} $tmp_str "" FPGA_pw_sta_synth
			#if the FPGA_pw_sta_synth is not available, set it to 0
			if {$FPGA_pw_sta_synth == ""} {
				set FPGA_pw_sta_synth 0
			}
			
			
			
			# #######################################  
			# Extract the IP power estimation
			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {foo_0} $line all value]} {
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
			regsub -all -- {[^0-9.-]} $tmp_str "" IP_pw_total_synth
			#if the IP_pw_total_synth is not available, set it to 0
			if {$IP_pw_total_synth == ""} {
				set IP_pw_total_synth 0
			}
			
			
	
			# #######################################  
			# Extract the user function power estimation
			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {grp_foo_foo_user_fu_402} $line all value]} {
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
			regsub -all -- {[^0-9.-]} $tmp_str "" USER_FUNCTION_pw_total_synth
			#if the USER_FUNCTION_pw_total_synth is not available, set it to 0
			if {$USER_FUNCTION_pw_total_synth == ""} {
				set USER_FUNCTION_pw_total_synth 0
			}
			
			# #######################################  
			# Extract the PS7 power estimation
			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {processing_system7_0  } $line all value]} {
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
			regsub -all -- {[^0-9.-]} $tmp_str "" PS7_pw_total_synth
			#if the PS7_pw_total_synth is not available, set it to 0
			if {$PS7_pw_total_synth == ""} {
				set PS7_pw_total_synth 0
			}
			
			
			
			
			
			
			# #######################################  
			# #######################################  
			# Extract post place & route power estimation 
			

			set target_file ""
			append target_file "ip_prototype/build/prj/" $project_name "." $board_name "/pr_power.txt"
			
			set line ""
			
			# #######################################  
			# Extract the FPGA power estimation
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
			regsub -all -- {[^0-9.-]} $tmp_str "" FPGA_pw_total_pr
			#if the FPGA_pw_total_pr is not available, set it to 0
			if {$FPGA_pw_total_pr == ""} {
				set FPGA_pw_total_pr 0
			}
			
			
			# #######################################  
			# Extract the FPGA_pw_dyn_pr
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
			regsub -all -- {[^0-9.-]} $tmp_str "" FPGA_pw_dyn_pr
			#if the FPGA_pw_dyn_pr is not available, set it to 0
			if {$FPGA_pw_dyn_pr == ""} {
				set FPGA_pw_dyn_pr 0
			}

			
			# #######################################  
			# Extract the FPGA_pw_sta_pr
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
			regsub -all -- {[^0-9.-]} $tmp_str "" FPGA_pw_sta_pr
			#if the FPGA_pw_sta_pr is not available, set it to 0
			if {$FPGA_pw_sta_pr == ""} {
				set FPGA_pw_sta_pr 0
			}
			
			
			
			# #######################################  
			# Extract the IP power estimation
			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {foo_0} $line all value]} {
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
			regsub -all -- {[^0-9.-]} $tmp_str "" IP_pw_total_pr
			#if the IP_pw_total_pr is not available, set it to 0
			if {$IP_pw_total_pr == ""} {
				set IP_pw_total_pr 0
			}
			
			
	
			# #######################################  
			# Extract the user function power estimation
			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {grp_foo_foo_user_fu_402} $line all value]} {
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
			regsub -all -- {[^0-9.-]} $tmp_str "" USER_FUNCTION_pw_total_pr
			#if the USER_FUNCTION_pw_total_pr is not available, set it to 0
			if {$USER_FUNCTION_pw_total_pr == ""} {
				set USER_FUNCTION_pw_total_pr 0
			}
			
			# #######################################  
			# Extract the PS7 power estimation
			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {processing_system7_0  } $line all value]} {
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
			regsub -all -- {[^0-9.-]} $tmp_str "" PS7_pw_total_pr
			#if the PS7_pw_total_pr is not available, set it to 0
			if {$PS7_pw_total_pr == ""} {
				set PS7_pw_total_pr 0
			}
			
			
			
			# make ip_prototype.dat
			set  file_name ""
			append file_name "doc/" $project_name "/ip_prototype.dat"

			set file [open $file_name w]


			puts $file $clock_target
			puts $file $clk_achieved
	
			puts $file $FPGA_pw_total_pr
			puts $file $FPGA_pw_dyn_pr
			puts $file $FPGA_pw_sta_pr
			puts $file $IP_pw_total_pr
			puts $file $USER_FUNCTION_pw_total_pr
			puts $file $PS7_pw_total_pr
			
			puts $file $FPGA_LUT_pr
			puts $file $FPGA_FF_pr
			puts $file $FPGA_RAMB_pr
			puts $file $FPGA_DSP48_pr
			puts $file $IP_LUT_pr
			puts $file $IP_FF_pr
			puts $file $IP_RAMB_pr
			puts $file $IP_DSP48_pr
			puts $file $USER_FUNCTION_LUT_pr
			puts $file $USER_FUNCTION_FF_pr
			puts $file $USER_FUNCTION_RAMB_pr
			puts $file $USER_FUNCTION_DSP48_pr
			
			puts $file $FPGA_LUT_synth
			puts $file $FPGA_FF_synth
			puts $file $FPGA_RAMB_synth
			puts $file $FPGA_DSP48_synth
			puts $file $IP_LUT_synth
			puts $file $IP_FF_synth
			puts $file $IP_RAMB_synth
			puts $file $IP_DSP48_synth
			puts $file $USER_FUNCTION_LUT_synth
			puts $file $USER_FUNCTION_FF_synth
			puts $file $USER_FUNCTION_RAMB_synth
			puts $file $USER_FUNCTION_DSP48_synth
			
			puts $file $FPGA_pw_total_synth
			puts $file $FPGA_pw_dyn_synth
			puts $file $FPGA_pw_sta_synth
			puts $file $IP_pw_total_synth
			puts $file $USER_FUNCTION_pw_total_synth
			puts $file $PS7_pw_total_synth
			
			
			close $file
			
			
			
			
					
			

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
			
			puts $file ""
			puts $file ""
				
			puts $file "Timing (post Place & Route):"
			puts $file "--------------------------"
			puts $file ""
			puts $file "* FPGA"
			set tmp_line ""
			append tmp_line "target clock period (ns): " $clock_target
			puts $file $tmp_line
			if [expr $clk_achieved < 0] {
				set tmp_line ""
				append tmp_line "clock slack (ns): " [expr $clk_achieved * -1]
				puts $file $tmp_line

				puts $file "Time constraints NOT met during IP prototyping. You have to increase clock target period to met time constraints."	

				
			} else {
				set tmp_line ""
				append tmp_line "achieved clock period (ns): " $clk_achieved
				puts $file $tmp_line
				
				puts $file "Time constraints met during IP prototyping. You might reduce clock target period to build a faster design."
			}
			
			
			puts $file ""
			puts $file ""
			
			puts $file "Resource measurement (post Place & Route):"
			puts $file "------------------------------------------"
			puts $file ""
			puts $file "* FPGA"
			if [expr $FPGA_RAMB_pr <= $BRAM_available] { 
				set tmp_line ""
				append tmp_line "   BRAM_18K: " $FPGA_RAMB_pr " (" [expr $FPGA_RAMB_pr * 100 / $BRAM_available] "%) used out off " $BRAM_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   BRAM_18K: " $FPGA_RAMB_pr " (" [expr $FPGA_RAMB_pr * 100 / $BRAM_available] "%) used out off " $BRAM_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $FPGA_DSP48_pr <= $DSP48E_available] { 
				set tmp_line ""
				append tmp_line "   DSP48E: " $FPGA_DSP48_pr  " (" [expr $FPGA_DSP48_pr * 100 / $DSP48E_available] "%) used out off " $DSP48E_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   DSP48E: " $FPGA_DSP48_pr  " (" [expr $FPGA_DSP48_pr * 100 / $DSP48E_available] "%) used out off " $DSP48E_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $FPGA_FF_pr <= $FF_available] { 
				set tmp_line ""
				append tmp_line "   FF: " $FPGA_FF_pr " (" [expr $FPGA_FF_pr * 100 / $FF_available] "%) used out off " $FF_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   FF: " $FPGA_FF_pr " (" [expr $FPGA_FF_pr * 100 / $FF_available] "%) used out off " $FF_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $FPGA_LUT_pr <= $LUT_available] { 
				set tmp_line ""
				append tmp_line "   LUT: " $FPGA_LUT_pr " (" [expr $FPGA_LUT_pr * 100 / $LUT_available] "%)  used out off " $LUT_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   LUT: " $FPGA_LUT_pr " (" [expr $FPGA_LUT_pr * 100 / $LUT_available] "%)  used out off " $LUT_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			puts $file ""
			puts $file "	* IP"
			if [expr $IP_RAMB_pr <= $BRAM_available] { 
				set tmp_line ""
				append tmp_line "   	BRAM_18K: " $IP_RAMB_pr " (" [expr $IP_RAMB_pr * 100 / $BRAM_available] "%) used out off " $BRAM_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   	BRAM_18K: " $IP_RAMB_pr " (" [expr $IP_RAMB_pr * 100 / $BRAM_available] "%) used out off " $BRAM_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $IP_DSP48_pr <= $DSP48E_available] { 
				set tmp_line ""
				append tmp_line "   	DSP48E: " $IP_DSP48_pr  " (" [expr $IP_DSP48_pr * 100 / $DSP48E_available] "%) used out off " $DSP48E_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   	DSP48E: " $IP_DSP48_pr  " (" [expr $IP_DSP48_pr * 100 / $DSP48E_available] "%) used out off " $DSP48E_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $IP_FF_pr <= $FF_available] { 
				set tmp_line ""
				append tmp_line "   	FF: " $IP_FF_pr " (" [expr $IP_FF_pr * 100 / $FF_available] "%) used out off " $FF_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   	FF: " $IP_FF_pr " (" [expr $IP_FF_pr * 100 / $FF_available] "%) used out off " $FF_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $IP_LUT_pr <= $LUT_available] { 
				set tmp_line ""
				append tmp_line "   	LUT: " $IP_LUT_pr " (" [expr $IP_LUT_pr * 100 / $LUT_available] "%)  used out off " $LUT_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   	LUT: " $IP_LUT_pr " (" [expr $IP_LUT_pr * 100 / $LUT_available] "%)  used out off " $LUT_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			set tmp_line ""
			puts $file ""
			puts $file "		* user function"
			if [expr $USER_FUNCTION_RAMB_pr <= $BRAM_available] { 
				set tmp_line ""
				append tmp_line "   		BRAM_18K: " $USER_FUNCTION_RAMB_pr " (" [expr $USER_FUNCTION_RAMB_pr * 100 / $BRAM_available] "%) used out off " $BRAM_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   		BRAM_18K: " $USER_FUNCTION_RAMB_pr " (" [expr $USER_FUNCTION_RAMB_pr * 100 / $BRAM_available] "%) used out off " $BRAM_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $USER_FUNCTION_DSP48_pr <= $DSP48E_available] { 
				set tmp_line ""
				append tmp_line "   		DSP48E: " $USER_FUNCTION_DSP48_pr  " (" [expr $USER_FUNCTION_DSP48_pr * 100 / $DSP48E_available] "%) used out off " $DSP48E_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   		DSP48E: " $USER_FUNCTION_DSP48_pr  " (" [expr $USER_FUNCTION_DSP48_pr * 100 / $DSP48E_available] "%) used out off " $DSP48E_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $USER_FUNCTION_FF_pr <= $FF_available] { 
				set tmp_line ""
				append tmp_line "   		FF: " $USER_FUNCTION_FF_pr " (" [expr $USER_FUNCTION_FF_pr * 100 / $FF_available] "%) used out off " $FF_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   		FF: " $USER_FUNCTION_FF_pr " (" [expr $USER_FUNCTION_FF_pr * 100 / $FF_available] "%) used out off " $FF_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $USER_FUNCTION_LUT_pr <= $LUT_available] { 
				set tmp_line ""
				append tmp_line "   		LUT: " $USER_FUNCTION_LUT_pr " (" [expr $USER_FUNCTION_LUT_pr * 100 / $LUT_available] "%)  used out off " $LUT_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   		LUT: " $USER_FUNCTION_LUT_pr " (" [expr $USER_FUNCTION_LUT_pr * 100 / $LUT_available] "%)  used out off " $LUT_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			
			puts $file ""
			puts $file ""
			
			puts $file "Power estimation with average toggle rate of 12.5/% (post Place & Route):"
			puts $file "-------------------------------------------------------------------------"
			puts $file ""
			puts $file "* FPGA"
			set tmp_line ""
			append tmp_line "   Total power on-chip (W): " $FPGA_pw_total_pr
			puts $file $tmp_line
			set tmp_line ""
			append tmp_line "   Dynamic power on-chip (W): " $FPGA_pw_dyn_pr
			puts $file $tmp_line
			set tmp_line ""
			append tmp_line "   Static power on-chip (W): " $FPGA_pw_sta_pr
			puts $file $tmp_line
			puts $file ""
			puts $file "	* ARM Cortex-A9"
			set tmp_line ""
			append tmp_line "   	   Total ARM Cortex-A9 power (W): " $PS7_pw_total_pr
			puts $file $tmp_line
			puts $file ""
			puts $file "	* IP"
			set tmp_line ""
			append tmp_line "   	   Total IP power (W): " $IP_pw_total_pr
			puts $file $tmp_line
			puts $file ""
			puts $file "		* user function"
			set tmp_line ""
			append tmp_line "   		   Total IP power (W): " $USER_FUNCTION_pw_total_pr
			puts $file $tmp_line
				

			
			
			puts $file ""
			puts $file ""
			puts $file ""
			puts $file ""
			puts $file "Post Synthesis resource estimation:"
			puts $file "-----------------------------------"
			puts $file ""
			puts $file "* FPGA"
			if [expr $FPGA_RAMB_synth <= $BRAM_available] { 
				set tmp_line ""
				append tmp_line "   BRAM_18K: " $FPGA_RAMB_synth " (" [expr $FPGA_RAMB_synth * 100 / $BRAM_available] "%) used out off " $BRAM_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   BRAM_18K: " $FPGA_RAMB_synth " (" [expr $FPGA_RAMB_synth * 100 / $BRAM_available] "%) used out off " $BRAM_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $FPGA_DSP48_synth <= $DSP48E_available] { 
				set tmp_line ""
				append tmp_line "   DSP48E: " $FPGA_DSP48_synth  " (" [expr $FPGA_DSP48_synth * 100 / $DSP48E_available] "%) used out off " $DSP48E_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   DSP48E: " $FPGA_DSP48_synth  " (" [expr $FPGA_DSP48_synth * 100 / $DSP48E_available] "%) used out off " $DSP48E_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $FPGA_FF_synth <= $FF_available] { 
				set tmp_line ""
				append tmp_line "   FF: " $FPGA_FF_synth " (" [expr $FPGA_FF_synth * 100 / $FF_available] "%) used out off " $FF_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   FF: " $FPGA_FF_synth " (" [expr $FPGA_FF_synth * 100 / $FF_available] "%) used out off " $FF_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $FPGA_LUT_synth <= $LUT_available] { 
				set tmp_line ""
				append tmp_line "   LUT: " $FPGA_LUT_synth " (" [expr $FPGA_LUT_synth * 100 / $LUT_available] "%)  used out off " $LUT_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   LUT: " $FPGA_LUT_synth " (" [expr $FPGA_LUT_synth * 100 / $LUT_available] "%)  used out off " $LUT_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			puts $file ""
			puts $file "	* IP"
			if [expr $IP_RAMB_synth <= $BRAM_available] { 
				set tmp_line ""
				append tmp_line "   	BRAM_18K: " $IP_RAMB_synth " (" [expr $IP_RAMB_synth * 100 / $BRAM_available] "%) used out off " $BRAM_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   	BRAM_18K: " $IP_RAMB_synth " (" [expr $IP_RAMB_synth * 100 / $BRAM_available] "%) used out off " $BRAM_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $IP_DSP48_synth <= $DSP48E_available] { 
				set tmp_line ""
				append tmp_line "   	DSP48E: " $IP_DSP48_synth  " (" [expr $IP_DSP48_synth * 100 / $DSP48E_available] "%) used out off " $DSP48E_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   	DSP48E: " $IP_DSP48_synth  " (" [expr $IP_DSP48_synth * 100 / $DSP48E_available] "%) used out off " $DSP48E_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $IP_FF_synth <= $FF_available] { 
				set tmp_line ""
				append tmp_line "   	FF: " $IP_FF_synth " (" [expr $IP_FF_synth * 100 / $FF_available] "%) used out off " $FF_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   	FF: " $IP_FF_synth " (" [expr $IP_FF_synth * 100 / $FF_available] "%) used out off " $FF_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $IP_LUT_synth <= $LUT_available] { 
				set tmp_line ""
				append tmp_line "   	LUT: " $IP_LUT_synth " (" [expr $IP_LUT_synth * 100 / $LUT_available] "%)  used out off " $LUT_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   	LUT: " $IP_LUT_synth " (" [expr $IP_LUT_synth * 100 / $LUT_available] "%)  used out off " $LUT_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			set tmp_line ""
			puts $file ""
			puts $file "		* user function"
			if [expr $USER_FUNCTION_RAMB_synth <= $BRAM_available] { 
				set tmp_line ""
				append tmp_line "   		BRAM_18K: " $USER_FUNCTION_RAMB_synth " (" [expr $USER_FUNCTION_RAMB_synth * 100 / $BRAM_available] "%) used out off " $BRAM_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   		BRAM_18K: " $USER_FUNCTION_RAMB_synth " (" [expr $USER_FUNCTION_RAMB_synth * 100 / $BRAM_available] "%) used out off " $BRAM_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $USER_FUNCTION_DSP48_synth <= $DSP48E_available] { 
				set tmp_line ""
				append tmp_line "   		DSP48E: " $USER_FUNCTION_DSP48_synth  " (" [expr $USER_FUNCTION_DSP48_synth * 100 / $DSP48E_available] "%) used out off " $DSP48E_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   		DSP48E: " $USER_FUNCTION_DSP48_synth  " (" [expr $USER_FUNCTION_DSP48_synth * 100 / $DSP48E_available] "%) used out off " $DSP48E_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $USER_FUNCTION_FF_synth <= $FF_available] { 
				set tmp_line ""
				append tmp_line "   		FF: " $USER_FUNCTION_FF_synth " (" [expr $USER_FUNCTION_FF_synth * 100 / $FF_available] "%) used out off " $FF_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   		FF: " $USER_FUNCTION_FF_synth " (" [expr $USER_FUNCTION_FF_synth * 100 / $FF_available] "%) used out off " $FF_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $USER_FUNCTION_LUT_synth <= $LUT_available] { 
				set tmp_line ""
				append tmp_line "   		LUT: " $USER_FUNCTION_LUT_synth " (" [expr $USER_FUNCTION_LUT_synth * 100 / $LUT_available] "%)  used out off " $LUT_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   		LUT: " $USER_FUNCTION_LUT_synth " (" [expr $USER_FUNCTION_LUT_synth * 100 / $LUT_available] "%)  used out off " $LUT_available " available. The design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			
			puts $file ""
			puts $file ""
			
			puts $file "Post Synthesis power estimation (average toggle rate 12.5/%):"
			puts $file "-------------------------------------------------------------"
			puts $file ""
			puts $file "* FPGA"
			set tmp_line ""
			append tmp_line "   Total power on-chip (W): " $FPGA_pw_total_synth
			puts $file $tmp_line
			set tmp_line ""
			append tmp_line "   Dynamic power on-chip (W): " $FPGA_pw_dyn_synth
			puts $file $tmp_line
			set tmp_line ""
			append tmp_line "   Static power on-chip (W): " $FPGA_pw_sta_synth
			puts $file $tmp_line
			puts $file ""
			puts $file "	* ARM Cortex-A9"
			set tmp_line ""
			append tmp_line "   	   Total ARM Cortex-A9 power (W): " $PS7_pw_total_synth
			puts $file $tmp_line
			puts $file ""
			puts $file "	* IP"
			set tmp_line ""
			append tmp_line "   	   Total IP power (W): " $IP_pw_total_synth
			puts $file $tmp_line
			puts $file ""
			puts $file "		* user function"
			set tmp_line ""
			append tmp_line "   		   Total IP power (W): " $USER_FUNCTION_pw_total_synth
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
