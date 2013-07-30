# -------------------------------------------------------------------------
# Target device : Any family
#
# Description : 
#   Replace SRLs with flip flops in post-synth netlist 
# 
# Assumptions :
#   - Vivado 2013.2
#
# -------------------------------------------------------------------------
#
# Calling syntax:
#   source <your_Tcl_script_location>/replace_fixed_length_srls.tcl
#
# -------------------------------------------------------------------------
# Author  : John Bieker, Xilinx 
# Revison : 0.0 - initial release for test on multiple designs
################################################################################

#**********************************************************************************#
# #******************************************************************************# #
# #                                                                              # #
# #                         M A I N   P R O G A M                                # #
# #                                                                              # #
# #******************************************************************************# #
#**********************************************************************************#
proc print_help {} {
    puts "replace_fixed_length_srls"
    puts "\n"
    puts "Usage:"
    puts "Name		Description "
    puts "--------------------------"
    puts {-replace_srls	Replace SRLs with FFs: Values 0,1}
    puts {-depth        Replace SRLs that are <= depth}
}

proc replace_fixed_length_srls {args} {
  set options(-replace_srls) ""
  set options(-depth) ""
  if {[lsearch $args "-help"] != -1} {
    print_help
  } else {
    foreach {parameter value} $args {
      set options($parameter) $value
      if {$parameter != "-replace_srls" || $parameter != "-depth"} {
        puts "Invalid parameter $parameter.\n"
        print_help
	return
      }
    }
  if {$options(-replace_srls) == ""} {
    set options(-replace_srls) "0"
  }
  if {$options(-depth) == ""} {
    set options(-replace_srls) "5"
  }
  set replace_srl_with_ffs $options(-replace_srls)
  set replacement_depth $options(-depth)
  set srl_cells  [get_cells -quiet -hier * -filter {REF_NAME =~SRL* && PRIMITIVE_LEVEL==LEAF}]
  set name_index 0
  set replacement_count 0

  set total_num_fixed_length_srl 0
  for {set i 1} {$i < 33} {incr i} {
    set srl_depth($i) 0
  }

  foreach srl $srl_cells {
    set fixed_length_srl 1
    set addr0_pin [get_pins -quiet -of $srl -filter {NAME =~ *A0 || NAME =~ *A[0]}];
    set addr1_pin [get_pins -quiet -of $srl -filter {NAME =~ *A1 || NAME =~ *A[1]}];
    set addr2_pin [get_pins -quiet -of $srl -filter {NAME =~ *A2 || NAME =~ *A[2]}];
    set addr3_pin [get_pins -quiet -of $srl -filter {NAME =~ *A3 || NAME =~ *A[3]}];
    set addr4_pin [get_pins -quiet -of $srl -filter {NAME =~ *A4 || NAME =~ *A[4]}];

    foreach pin "$addr0_pin $addr1_pin $addr2_pin $addr3_pin $addr4_pin" {
      set net($pin) [get_nets -quiet -of [get_pins -quiet $pin]]
      set net_type($pin) [get_property TYPE [get_nets -quiet -of [get_pins -quiet $pin]]]

      if "[regexp "POWER" $net_type($pin)]" {
        set net_value($pin) 1
      } elseif "[regexp "GROUND" $net_type($pin)]" {
        set net_value($pin) 0
      } else {
        set fixed_length_srl 0
	set net_value($pin) ""
      }
    }
 
    if {$fixed_length_srl == 1} {
      set srl_depth_index [expr 1 + 1*$net_value($addr0_pin) + 2*$net_value($addr1_pin) + 4*$net_value($addr2_pin) + 8*$net_value($addr3_pin)]
      incr srl_depth($srl_depth_index)
      incr total_num_fixed_length_srl
      if {$replace_srl_with_ffs==1 && $srl_depth_index <= $replacement_depth} {
        replace_proc $srl $srl_depth_index $name_index
	incr replacement_count
    }
    incr name_index
  }

  puts "Total Number of SRL Before Replacement:  [llength $srl_cells]"
  for {set i 1} {$i < 33} {incr i} {
    puts "Total Number of SRL with depth $i:  $srl_depth($i)"
  }
  puts "Total Number of SRL Before Replacement:  [llength $srl_cells]"
  puts "Total Number of SRL After Replacement:  [expr [llength $srl_cells] - $replacement_count]"
  puts "Total Number of Fixed Length SRL Replaced by FFs:  $replacement_count"
 }
}

proc replace_proc {srl depth name_index} {

  if {[get_property PARENT $srl] == ""} {
    set parent ""
  } else {
    set parent "[get_property PARENT $srl]/"
  }

  set vcc_cell "[join ${parent}srl_optimization_vcc${name_index}]"
  set gnd_cell "[join ${parent}srl_optimization_gnd${name_index}]"
  set vcc_net  "[join ${parent}srl_optimization_vcc_net${name_index}]"
  set gnd_net  "[join ${parent}srl_optimization_gnd_net${name_index}]"

  create_cell -reference VCC $vcc_cell;
  create_net $vcc_net;
  connect_net -net $vcc_net -objects [get_pins -quiet $vcc_cell/P]
  create_cell -reference GND $gnd_cell;
  create_net $gnd_net;
  connect_net -net $gnd_net -objects [get_pins -quiet $gnd_cell/G]

  set input_net  [get_nets -quiet -of [get_pins -quiet $srl/D]];
  set enable_net [get_nets -quiet -of [get_pins -quiet $srl/CE]];
  set clock_net  [get_nets -quiet -of [get_pins -quiet $srl/CLK]];
  set output_net [get_nets -quiet -of [get_pins -quiet $srl/Q]];

  set i 0

  while {$i < $depth} {
    set ff_cell($i) "[join ${parent}srl_optimization_ff${i}_${name_index}]"
    set ff_net($i)  "[join ${parent}srl_optimization_ff${i}_net${name_index}]"
    create_cell -reference FDRE $ff_cell($i);
    lappend cell_list [get_cells -quiet $ff_cell($i)]
    create_net $ff_net($i);
    if {$i==0} {
      disconnect_net -net $input_net -objects [get_pins -quiet $srl/D];
      connect_net -net $input_net -objects [get_pins -quiet $ff_cell($i)/D];
    } else {
      connect_net -net $ff_net([expr $i-1]) -objects [get_pins -quiet $ff_cell($i)/D];
    }
    if {$i==[expr $depth - 1]} {
      disconnect_net -net $output_net -objects [get_pins -quiet $srl/Q];
      connect_net -net $output_net -objects [get_pins -quiet $ff_cell($i)/Q];
    } else {
      connect_net -net $ff_net($i) -objects [get_pins -quiet $ff_cell($i)/Q];
    }
  incr i
  }
 
  connect_net -net $enable_net -objects [get_pins -quiet -filter {IS_ENABLE==1} -of [get_cells -quiet $cell_list]]
  disconnect_net -net $enable_net -objects [get_pins -quiet $srl/CE];
  connect_net -net $clock_net -objects [get_pins -quiet -filter {IS_CLOCK==1} -of [get_cells -quiet $cell_list]]
  disconnect_net -net $clock_net -objects [get_pins -quiet $srl/CLK];
  connect_net -net $gnd_net -objects [get_pins -quiet -filter {IS_RESET==1} -of [get_cells -quiet $cell_list]]
  remove_cell [get_cells -quiet $srl];

}

