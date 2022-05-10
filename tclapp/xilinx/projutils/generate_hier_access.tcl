#####################################################################################
#
# generate_hier_access.tcl
# Script created on 11/07/2019 by Raj Klair (Xilinx, Inc.)
#
#####################################################################################
namespace eval ::tclapp::xilinx::projutils {
  namespace export generate_hier_access
}

namespace eval ::tclapp::xilinx::projutils {

proc hbs_init_vars {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_hbs_vars

  set a_hbs_vars(bypass_module)           {xil_dut_bypass}  
  set a_hbs_vars(bypass_file)             {}  
  set a_hbs_vars(driver_module)           {xil_bypass_driver}  
  set a_hbs_vars(pseudo_top_testbench)    {}  
  set a_hbs_vars(user_design_testbench)   {}
  set a_hbs_vars(hbs_dir)                 [pwd]
  set a_hbs_vars(log)                     {}  
  set a_hbs_vars(port_attribute)          "hier_bypass_ports"
  set a_hbs_vars(module_attribute)        "hier_bypass_mod"
  set a_hbs_vars(b_bypass_module)         0
  set a_hbs_vars(b_driver_module)         0
  set a_hbs_vars(b_pseudo_top_testbench)  0
  set a_hbs_vars(b_user_design_testbench) 0
  set a_hbs_vars(b_hbs_dir)               0 
  set a_hbs_vars(b_log)                   0

  set a_hbs_vars(copyright)               "Copyright (C) 2020 Xilinx, Inc. All rights reserved."
  set a_hbs_vars(date_time)               [clock format [clock seconds]]
}

proc generate_hier_access {args} {
  # Summary: Generate sources for hierarchical access simulation
  
  # Argument Usage: 
  # [-bypass <arg> = xil_dut_bypass]: Hierarchical access module name
  # [-driver <arg> = xil_bypass_driver]: Signal driver template module name
  # [-directory <arg> = current working directory]: Output directory for the generated sources
  # [-pseudo_top <arg>]: Top-level pseudo testbench module name
  # [-testbench <arg>]: User design testbench module name
  # [-log <arg>]: Simulator log containing hierarchical path information (required for the non-Vivado standalone flow only)

  # Return Value:
  # None
  
  # Categories: simulation, xilinxtclstore
  
  variable a_hbs_vars
  hbs_init_vars

  set a_hbs_vars(options) [split $args " "]
  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch $option {
      "-bypass"     { incr i; set a_hbs_vars(bypass_module)         [lindex $args $i]; set a_hbs_vars(b_bypass_module)         1 }
      "-driver"     { incr i; set a_hbs_vars(driver_module)         [lindex $args $i]; set a_hbs_vars(b_driver_module)         1 }
      "-directory"  { incr i; set a_hbs_vars(hbs_dir)               [lindex $args $i]; set a_hbs_vars(b_hbs_dir)               1 }
      "-pseudo_top" { incr i; set a_hbs_vars(pseudo_top_testbench)  [lindex $args $i]; set a_hbs_vars(b_pseudo_top_testbench)  1 }
      "-testbench"  { incr i; set a_hbs_vars(user_design_testbench) [lindex $args $i]; set a_hbs_vars(b_user_design_testbench) 1 }
      "-log"        { incr i; set a_hbs_vars(log)                   [lindex $args $i]; set a_hbs_vars(b_log)                   1 }
      default {
        if { [regexp {^-} $option] } {
          hbs_print_msg_id "ERROR" "1" "Unknown option '$option', please type 'generate_hier_access -help' for usage info." 
        }
      }
    }
  }

  #
  # command line error
  #
  # testbench name is a must for -log mode
  if { ($a_hbs_vars(b_pseudo_top_testbench)) && ({} == $a_hbs_vars(pseudo_top_testbench)) } {
    set a_hbs_vars(pseudo_top_testbench) "pseudo_top_testbench"
  }
  
  # log exists?
  if { $a_hbs_vars(b_log) } {
    if { ![file exists $a_hbs_vars(log)] } {
      hbs_print_msg_id "ERROR" "2" "File does not exist! '$a_hbs_vars(log)'" 
      return
    }
  }

  if { !$a_hbs_vars(b_log) } {
    set version_info [split [version] "\n"]
    set release      [lindex $version_info 0]
    set product      [lindex [split $release " "] 0]
    set version_id   [join [lrange $release 1 end] " "]
    set a_hbs_vars(vivado_build) "$product (TM) $version_id"
  }

  #
  # file existence checks
  #
  hbs_generate_bypass

  if { $a_hbs_vars(b_log) } {
    hbs_print_msg_id "STATUS" 7 "Done"
  }
  return 
}

proc hbs_generate_bypass {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_hbs_vars

  # create bypass file
  set a_hbs_vars(bypass_file) "$a_hbs_vars(hbs_dir)/$a_hbs_vars(bypass_module).sv"
  set fh 0
  if { [file exists $a_hbs_vars(bypass_file)] } {
    if { [catch {file delete -force $a_hbs_vars(bypass_file)} error_msg] } {
      hbs_print_msg_id "ERROR" "8" "Failed to delete file ($a_hbs_vars(bypass_file))"
      return 1
    }
  }
  if { [catch {open $a_hbs_vars(bypass_file) w} fh] } {
    hbs_print_msg_id "ERROR" "9" "Failed to open file to write ($a_hbs_vars(bypass_file))"
    return 1
  } 

  #
  # write top-level pseudo module instantiating test bench
  #
  hbs_write_header $fh

  #
  # write pseudo testbench (top-level testbench in the design for simulating gtm signals)
  #
  if { [hbs_write_pseudo_top_testbench] } {
    return 1
  }

  set log_data {}
  if { $a_hbs_vars(b_log) } {
    set log_data [hbs_extract_hier_paths_from_simulator_log]
    if { {} == $a_hbs_vars(b_user_design_testbench) } {
      hbs_print_msg_id "ERROR" "2" "Failed to find the simulation design top from the hierarchical paths in the specified log file! Please specify the top with the '-testbench' switch and retry this operation."
      return 1
    }
  } else {
    set log_data [rdi::get_design_hier_path $a_hbs_vars(port_attribute)] 
    #foreach hier_path $log_data {
    #  puts "HIER_PATH:$hier_path"
    #}
  }

  #
  # Set the testbench top for Vivado flow
  #
  set user_tb_top $a_hbs_vars(user_design_testbench)
  if { {} == $a_hbs_vars(b_user_design_testbench) } {
    set user_tb_top [get_property top [current_fileset -simset]]
  }

  # port list for the driver signal code
  set input_port_list      [list]
  set output_port_list     [list]
  set instance_port_list   [list]
  set input_sig_port_list  [list]
  set output_sig_port_list [list]

  #
  # write module declaration
  #
  puts $fh "`timescale 1ps/1ps"
  puts $fh ""
  puts $fh "/* Hierarchical access module attribute"
  puts $fh " * --------- DONOT MODIFY -------------*/"
  puts $fh "(* $a_hbs_vars(module_attribute) *)"
  puts -nonewline $fh "module $a_hbs_vars(bypass_module)( "

  if { $a_hbs_vars(b_log) } {
    hbs_print_msg_id "STATUS" 10 "Extracting port information..."
  }
  set port_index 1
  foreach line $log_data {
    if { ![hbs_is_valid_hier_path $user_tb_top $line] } { continue }
    set port_count 1
    if { $port_index > 1 } {
      puts -nonewline $fh ","
    }
    set line [string trim $line]
    if { [string length $line] == 0 } { continue }
    #
    # tb.dut_i.gtmWiz_00.gtm_i#in:integer:in1:in_var1 in:integer:in2:in_var2 out:integer:out1:out_var1 out:integer:out2:out_var2
    # 
    set line_v    [split $line {#}]
    set hier_path [lindex $line_v 0]
    set path_spec [lindex $line_v 1]
    set path_spec_v [split $path_spec { }]
    foreach spec $path_spec_v {
      #
      # in:integer:in1:in_var1
      #
      set port_spec [split $spec {:}]
      set port_dir  [lindex $port_spec 0]
      set port_type [lindex $port_spec 1]
      set port_name [lindex $port_spec 2]
      set port_var  [lindex $port_spec 3]
     
      set sig_port "${port_name}_xil_${port_index}" 
      set sig_port_driver "${port_name}_${port_index}" 

      if { "in"  == $port_dir } {
        lappend input_port_list ${sig_port_driver}
        lappend input_sig_port_list ${sig_port}
      }
      if { "out" == $port_dir } {
        lappend output_port_list ${sig_port_driver}
        lappend output_sig_port_list ${sig_port}
      }
      lappend instance_port_list $sig_port_driver
      if { $port_count != 1 } {
        puts -nonewline $fh ", "
      }
      puts -nonewline $fh $sig_port 
      incr port_count
    }
    incr port_index
  }
  puts $fh " );"
  #
  # write input/output ports declaration
  #
  if { $a_hbs_vars(b_log) } {
    # log mode
  } else {
    package require struct::matrix
    struct::matrix mt;
    mt add columns 2;
  }
 
  set print_lines_v [list]
  set port_index 1
  foreach line $log_data {
    if { ![hbs_is_valid_hier_path $user_tb_top $line] } { continue }
    set port_count 1
    set line [string trim $line]
    if { [string length $line] == 0 } { continue }
    #
    # tb.dut_i.gtmWiz_00.gtm_i#in:integer:in1:in_var1 in:integer:in2:in_var2 out:integer:out1:out_var1 out:integer:out2:out_var2
    # top.I1.\g_MODEM_GTM_PRI[0].u_modem_gtm_pri#.\g_gt.u_modem_gtm_ch0  in:integer:CH0_GTMRXN:CH0_GTMRXN_integer out:integer:CH1_GTMTXP:CH1_GTMTXP_integer
    # 
    set line_v      [split $line {#}]
    set hier_path   [lindex $line_v 0]
    set hier_path_v [split $hier_path {.}]
    #
    # dut_i.gtmWiz_00.gtm_i#in:integer:in1:in_var1 in:integer:in2:in_var2 out:integer:out1:out_var1 out:integer:out2:out_var2
    # top.I1.\g_MODEM_GTM_PRI[0].u_modem_gtm_pri#.\g_gt.u_modem_gtm_ch0  in:integer:CH0_GTMRXN:CH0_GTMRXN_integer out:integer:CH1_GTMTXP:CH1_GTMTXP_integer
    # 
    set hier_path   [join [lrange $hier_path_v 1 end] {.}]
    set path_spec   [lindex $line_v 1]
    set path_spec_v [split $path_spec { }]
    if { $port_index > 1 } {
      if { $a_hbs_vars(b_log) } {
        # not required
      } else {
        lappend print_lines_v "\" \" \" \""
      }
    }
    foreach spec $path_spec_v {
      #
      # in:integer:in1:in_var1
      #
      set port_spec [split $spec {:}]
      set port_dir  [lindex $port_spec 0]
      set port_type [lindex $port_spec 1]
      set port_name [lindex $port_spec 2]
      set port_var  [lindex $port_spec 3]
    
      set port_dir_type "input"
      if { "out" == $port_dir } { set port_dir_type "output" }
      set port_col "$port_dir_type $port_type ${port_name}_xil_${port_index};"
      if { "in" == $port_dir } {
        if { {} == $a_hbs_vars(pseudo_top_testbench) } {
          if { [string index $hier_path end] == "\\" } {
            set hier_path_t [string trimright $hier_path {\\}]
            set cmnt_col "// => '\$root.${user_tb_top}.${hier_path_t} .${port_var}'"
          } else {
            set cmnt_col "// => '\$root.${user_tb_top}.${hier_path}.${port_var}'"
          }
        } else {
          set cmnt_col "// => '$a_hbs_vars(pseudo_top_testbench).${user_tb_top}_i.${hier_path}.${port_var}'"
        }
      } elseif { "out" == $port_dir } {
        if { {} == $a_hbs_vars(pseudo_top_testbench) } {
          if { [string index $hier_path end] == "\\" } {
            set hier_path_t [string trimright $hier_path {\\}]
            set cmnt_col "// <= '\$root.${user_tb_top}.${hier_path_t} .${port_var}'"
          } else {
            set cmnt_col "// <= '\$root.${user_tb_top}.${hier_path}.${port_var}'"
          }
        } else {
          set cmnt_col "// <= '$a_hbs_vars(pseudo_top_testbench).${user_tb_top}_i.${hier_path}.${port_var}'"
        }
      }
      if { $a_hbs_vars(b_log) } {
        lappend print_lines_v "  $port_col    $cmnt_col"
      } else {
        lappend print_lines_v "\"  $port_col\" \"    $cmnt_col\""
      }
    }
    incr port_index
  }
  puts $fh ""
  if { $a_hbs_vars(b_log) } {
    foreach p_line $print_lines_v {
      puts $fh $p_line
    }
  } else {
    foreach p_line $print_lines_v {mt add row $p_line}
    puts $fh [mt format 2string]
    mt destroy
  }
  #
  # write DUT bypass driver template code (to be inserted into test bench by the user for driving the input)
  #
  if { [hbs_write_bypass_driver_file input_sig_port_list output_sig_port_list input_port_list output_port_list instance_port_list] } {
    return 1
  }
  # 
  # write always block with port assigment
  #
  set port_index 1
  foreach line $log_data {
    if { ![hbs_is_valid_hier_path ${user_tb_top} $line] } { continue }
    set port_count 1
    set line [string trim $line]
    if { [string length $line] == 0 } { continue }
    #
    # tb.dut_i.gtmWiz_00.gtm_i#in:integer:in1:in_var1 in:integer:in2:in_var2 out:integer:out1:out_var1 out:integer:out2:out_var2
    # 
    set line_v      [split $line {#}]
    set hier_path   [lindex $line_v 0]
    set hier_path_v [split $hier_path {.}]
    #
    # dut_i.gtmWiz_00.gtm_i#in:integer:in1:in_var1 in:integer:in2:in_var2 out:integer:out1:out_var1 out:integer:out2:out_var2
    # 
    set hier_path   [join [lrange $hier_path_v 1 end] {.}]
    set path_spec   [lindex $line_v 1]
    set path_spec_v [split $path_spec { }]
    puts $fh ""

    # write for in type
    foreach spec $path_spec_v {
      #
      # in:integer:in1:in_var1
      #
      set port_spec [split $spec {:}]
      set port_dir  [lindex $port_spec 0]
      set port_type [lindex $port_spec 1]
      set port_name [lindex $port_spec 2]
      set port_var  [lindex $port_spec 3]

      set port_id ${port_name}_xil_${port_index}  
      if { "in" == $port_dir } {
        puts $fh "  always @ (${port_id}) begin"
        if { {} == $a_hbs_vars(pseudo_top_testbench) } {
          if { [string index $hier_path end] == "\\" } {
            set hier_path_t [string trimright $hier_path {\\}]
            puts $fh "    \$root.${user_tb_top}.${hier_path_t} .${port_var} = ${port_id};"
          } else {
            puts $fh "    \$root.${user_tb_top}.${hier_path}.${port_var} = ${port_id};"
          }
        } else {
          puts $fh "    $a_hbs_vars(pseudo_top_testbench).${user_tb_top}_i.${hier_path}.${port_var} = ${port_id};"
        }
        puts $fh "  end"
      }
    }
    puts $fh ""
    # write for out type
    foreach spec $path_spec_v {
      #
      # in:integer:in1:in_var1
      #
      set port_spec [split $spec {:}]
      set port_dir  [lindex $port_spec 0]
      set port_type [lindex $port_spec 1]
      set port_name [lindex $port_spec 2]
      set port_var  [lindex $port_spec 3]

      set port_id ${port_name}_xil_${port_index}  
      if { "out" == $port_dir } {
        if { {} == $a_hbs_vars(pseudo_top_testbench) } {
          if { [string index $hier_path end] == "\\" } {
            set hier_path_t [string trimright $hier_path {\\}]
            puts $fh "  always @ (\$root.${user_tb_top}.${hier_path_t} .${port_var}) begin"
            puts $fh "    ${port_id} = \$root.${user_tb_top}.${hier_path_t} .${port_var};"
          } else {
            puts $fh "  always @ (\$root.${user_tb_top}.${hier_path}.${port_var}) begin"
            puts $fh "    ${port_id} = \$root.${user_tb_top}.${hier_path}.${port_var};"
          }
          puts $fh "  end"
        } else {
          puts $fh "  always @ ($a_hbs_vars(pseudo_top_testbench).${user_tb_top}_i.${hier_path}.${port_var}) begin"
          puts $fh "    ${port_id} = $a_hbs_vars(pseudo_top_testbench).${user_tb_top}_i.${hier_path}.${port_var};"
          puts $fh "  end"
        }
      }
    }
    incr port_index
  }
  puts $fh ""
  #
  # write module end
  #
  puts $fh "endmodule"
  #
  # close bypass file
  #
  close $fh

  if { $a_hbs_vars(b_log) } {
    hbs_print_msg_id "STATUS" 11 "Generated module for setting up bypass hierarchy: $a_hbs_vars(bypass_file)"
  }
}

proc hbs_write_header { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_hbs_vars
  set filename [file tail $a_hbs_vars(bypass_file)]
  
  puts $fh "//-------------------------------------------------------------------------------------------------------"
  if { !$a_hbs_vars(b_log) } {
    puts $fh "// $a_hbs_vars(vivado_build)"
    puts $fh "//"
  }
  puts $fh "// Filename: ${filename}"
  puts $fh "// Purpose : This is an auto generated bypass module that defines the ports and hierarchical paths for"
  puts $fh "//           propagating the signal values from the top-level testbench to the unisim compoenents. The"
  puts $fh "//           module defines the 'hier_bypass_mod' attribute for identifyng this module to make sure the"
  puts $fh "//           design hierarchy is established for the bypass simulation flow."
  puts $fh "//"
  puts $fh "// $a_hbs_vars(copyright)"
  puts $fh "//"
  puts $fh "// Generated on $a_hbs_vars(date_time)"
  puts $fh "//-------------------------------------------------------------------------------------------------------"
}

proc hbs_write_pseudo_top_testbench {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_hbs_vars

  set top $a_hbs_vars(pseudo_top_testbench)
  if { {} == $top } {
    return 0
  }

  set tb  $a_hbs_vars(user_design_testbench)

  set fh 0
  set file_name "$a_hbs_vars(hbs_dir)/${top}.sv"
  if { [catch {file delete -force $file_name} error_msg] } {
    hbs_print_msg_id "ERROR" "12" "Failed to delete file ($file_name)"
    return 1
  }
  if { [catch {open $file_name w} fh] } {
    hbs_print_msg_id "ERROR" "13" "Failed to open file to write ($file_name)"
    return 1
  } 
  puts $fh "//-------------------------------------------------------------------------------------------------------"
  if { !$a_hbs_vars(b_log) } {
    puts $fh "// $a_hbs_vars(vivado_build)"
    puts $fh "//"
  }
  puts $fh "// Filename: ${top}.sv"
  puts $fh "// Purpose : This is an auto generated top level testbench that instantiates the underlying testbench"
  puts $fh "//           or a DUT in the current simulation source hierarchy. The purpose of this testbench source"
  puts $fh "//           is to setup a mixed-language design configuration for calculating the hierarchical path to"
  puts $fh "//           the unisim library components for the purpose of propagating the signal values via the" 
  puts $fh "//           bypass module*. Please verify the design source hierarchy to make sure that this bypass"
  puts $fh "//           module is instantiated correctly."
  puts $fh "//"
  puts $fh "//           *bypass module is a system verilog module that defines the ports and signal propagation" 
  puts $fh "//"
  puts $fh "// $a_hbs_vars(copyright)"
  puts $fh "//"
  puts $fh "// Generated on $a_hbs_vars(date_time)"
  puts $fh "//---------------------------------------------------------------------------------------------------- --"
  puts $fh "`timescale 1ps/1ps"
  puts $fh ""
  puts $fh "module ${top}();"
  puts $fh "  /*"
  puts $fh "   * User design testbench instantiation or a DUT"
  puts $fh "  */"
  puts $fh "  ${tb} ${tb}_i();\n"
  puts $fh "endmodule\n"
  close $fh
  if { $a_hbs_vars(b_log) } {
    hbs_print_msg_id "STATUS" 14 "Generated top-level testbench source for instantiating design testbench '$a_hbs_vars(user_design_testbench)': ${file_name}"
  }
  return 0
}

proc hbs_write_bypass_driver_file { input_sig_ports_arg output_sig_ports_arg input_ports_arg output_ports_arg instance_ports_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $input_sig_ports_arg input_sig_ports
  upvar $output_sig_ports_arg output_sig_ports
  upvar $input_ports_arg input_ports
  upvar $output_ports_arg output_ports
  upvar $instance_ports_arg instance_ports

  variable a_hbs_vars
  set fh 0
 
  # get file extesion of the top file in simset 
  if { $a_hbs_vars(b_log) } {
    # TODO
    set extn ".sv"
  } else {
    set co_file_list [get_files -compile_order sources -used_in simulation -of_objects [current_fileset -simset]]
    set top_file [lindex $co_file_list end]
    set extn [file extension $top_file]
    if { {.v} == $extn } {
      set extn ".sv"
    }
  }

  set driver_file "$a_hbs_vars(hbs_dir)/$a_hbs_vars(driver_module)$extn"
  if { [catch {file delete -force $driver_file} error_msg] } {
    hbs_print_msg_id "ERROR" "15" "Failed to delete file ($driver_file)"
    return 1
  }
  if { [catch {open $driver_file w} fh] } {
    hbs_print_msg_id "ERROR" "16" "Failed to open file to write ($driver_file)"
    return 1
  }

  # get driver file type
  set extn [string tolower [file extension $driver_file]]
  if { ({.vhd} == $extn) } { 
    hbs_generate_vhdl_driver $fh $driver_file $input_ports $output_ports $instance_ports
  } elseif { ({.v} == $extn) || ({.sv} == $extn) } { 
    hbs_generate_verilog_driver $fh $extn $driver_file $input_sig_ports $output_sig_ports $input_ports $output_ports $instance_ports
  }
  if { $a_hbs_vars(b_log) } {
    hbs_print_msg_id "STATUS" 17 "Generated signal driver template for instantiating bypass module: ${driver_file}"
  }
  close $fh
  return 0
}

proc hbs_generate_vhdl_driver { fh driver_file input_ports output_ports instance_ports } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_hbs_vars
  set filename [file tail ${driver_file}]
  puts $fh "-- ------------------------------------------------------------------------------------------------------"
  if { !$a_hbs_vars(b_log) } {
    puts $fh "-- $a_hbs_vars(vivado_build)"
    puts $fh "--"
  }
  puts $fh "-- Filename: ${filename}"
  puts $fh "-- Purpose : This is an auto generated signal driver template code for setting up the input waveform and" 
  puts $fh "--           for instantiating the bypass module in order to propagate the values from the testbench to"
  puts $fh "--           the lower-level unisim components. Please use this code as a reference for setting up the"
  puts $fh "--           input and source hierarchy."  
  puts $fh "--"  
  puts $fh "-- $a_hbs_vars(copyright)"
  puts $fh "--"  
  puts $fh "-- Generated on $a_hbs_vars(date_time)"
  puts $fh "-- ------------------------------------------------------------------------------------------------------"
  puts $fh "-- ***********************************************************************************"
  puts $fh "-- INSERT FOLLOWING CODE IN YOUR TESTBENCH SOURCE FILE TO REFERENCE IEEE MATH PACKAGES"
  puts $fh "-- ****************************** COPY START *****************************************"
  puts $fh "library ieee;"
  puts $fh "use ieee.math_real.uniform;"
  puts $fh "use ieee.math_real.floor;"
  puts $fh "-- ****************************** COPY END *********************************************"
  puts $fh ""
  set entity [file root [file tail ${driver_file}]]
  puts $fh "entity $entity is"
  puts $fh "end entity;"
  puts $fh ""

  puts $fh "architecture a_${entity} of $entity is"
  puts $fh "-- *************************************************************************************"
  puts $fh "-- INSERT FOLLOWING CODE IN YOUR TESTBENCH SOURCE FILE TO DEFINE RANDOM SIGNAL GENERATOR"
  puts $fh "-- ****************************** COPY START *******************************************"
  puts $fh "  shared variable seed_1 : positive := 1;"
  puts $fh "  shared variable seed_2 : positive := 1;"
  puts $fh "  function rand_hbs return INTEGER is"
  puts $fh "    variable x: REAL;"
  puts $fh "    begin"
  puts $fh "      uniform(seed_1, seed_2, x);"
  puts $fh "      return integer(floor(x * 4.0));"
  puts $fh "  end function;"
  puts $fh "-- ****************************** COPY END *********************************************"
  puts $fh ""
  foreach in_port $input_ports {
    puts $fh "  signal $in_port : integer;"
  }
  foreach out_port $output_ports {
    puts $fh "  signal $out_port : integer;"
  }
  puts $fh "begin"
  puts $fh "-- ************************************************************************************"
  puts $fh "-- INSERT FOLLOWING CODE IN YOUR TESTBENCH SOURCE FILE TO INSTANTIATE THE BYPASS MODULE"
  puts $fh "-- ****************************** COPY START ******************************************"
  puts $fh "  DRIVE_INPUT: process"
  puts $fh "  begin"
  puts $fh "    for n in 1 to 100 loop"
  foreach in_port $input_ports {
    puts $fh "      $in_port <= rand_hbs;"
  }
  puts $fh "      wait for 20ns;"
  set sig_port_v [list]
  foreach in_port $input_ports {
    lappend sig_port_v "& integer'image($in_port)"
  }
  set sig_port_str [join $sig_port_v { }]
  puts $fh "      report \"HBS_SIGNAL: \" ${sig_port_str};"
  puts $fh "   end loop;"
  puts $fh "   wait;"
  puts $fh "  end process;"
  puts $fh ""
  set instance_ports_str [join $instance_ports {, }]
  puts $fh "  HIER_BYPASS : entity work.$a_hbs_vars(bypass_module) port map( $instance_ports_str );"
  puts $fh "-- ****************************** COPY END *********************************************"
  puts $fh ""
  puts $fh "end architecture a_${entity};"
}

proc hbs_generate_verilog_driver { fh extn driver_file input_sig_ports output_sig_ports input_ports output_ports instance_ports } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_hbs_vars

  set filename [file tail ${driver_file}]
  set module [file root ${filename}]

  puts $fh "/*------------------------------------------------------------------------------------------------------"
  if { !$a_hbs_vars(b_log) } {
    puts $fh "  $a_hbs_vars(vivado_build)"
    puts $fh ""
  }
  puts $fh "  Filename: ${filename}"
  puts $fh "  Purpose : This is an auto generated signal driver template code for setting up the input waveform and" 
  puts $fh "            for instantiating the bypass module in order to propagate the values from the testbench to"
  puts $fh "            the lower-level unisim components. Please use this code as a reference for setting up the"
  puts $fh "            input and source hierarchy."  
  puts $fh ""
  puts $fh "  $a_hbs_vars(copyright)"
  puts $fh ""
  puts $fh "  Generated on $a_hbs_vars(date_time)"
  puts $fh " -------------------------------------------------------------------------------------------------------*/"
  puts $fh "`timescale 1ps/1ps"
  puts $fh ""
  puts $fh "/*******************************************************************************************"
  puts $fh " INSERT FOLLOWING CODE IN YOUR TESTBENCH SOURCE FILE TO DEFINE PSEUDO RANDOM NUMBER VARIABLE"
  puts $fh " ******************************* COPY START ************************************************/"
  puts $fh "`define rand_hbs_var \$urandom%4;"
  puts $fh "/****************************** COPY END ***************************************************/"
  puts $fh ""
  puts $fh "module $module\(\);"
  set in_port_decl [join $input_ports {, }]
  set out_port_decl [join $output_ports {, }]
  puts $fh ""
  puts $fh "/************************************************************************************"
  puts $fh " INSERT FOLLOWING CODE IN YOUR TESTBENCH SOURCE FILE TO INSTANTIATE THE BYPASS MODULE"
  puts $fh " ******************************* COPY START *****************************************/"
  puts $fh "  integer ${in_port_decl};"
  if { {.sv} == $extn } {
    puts $fh "  integer ${out_port_decl};"
  } else {
    puts $fh "  wire[31:0] ${out_port_decl};"
  }
  puts $fh ""
  puts $fh "  integer n;"
  puts $fh ""
  puts $fh "  initial begin"
  puts $fh "    for (n=1;n<=100;n=n+1) begin"
  foreach in_port $input_ports {
    puts $fh "      $in_port = `rand_hbs_var;"
  }
  puts $fh "      #20;"
  puts $fh "      \$display(\"HBS_SIGNAL: %0d,%0d\", ${in_port_decl}, ${out_port_decl});"
  puts $fh "    end"
  puts $fh "  end"
  puts $fh "" 

  set all_ports [concat $input_ports $output_ports]
  set port_len [llength $all_ports]
  set bmod $a_hbs_vars(bypass_module)
  puts $fh "  $bmod ${bmod}_i \("
  set index 0
  foreach in_port $input_sig_ports {
    set actual_port ${in_port}
    set formal_port [regsub -all {_xil_} $actual_port {_}]
    puts -nonewline $fh "   .${actual_port} \(${formal_port}\)"
    incr index
    if { $index < $port_len } {
      puts $fh ","
    }
  }
  foreach out_port $output_sig_ports {
    set actual_port ${out_port}
    set formal_port [regsub -all {_xil_} $actual_port {_}]
    puts -nonewline $fh "   .${actual_port} \(${formal_port}\)"
    incr index
    if { $index < $port_len } {
      puts $fh ","
    }
  }
  puts $fh "\n  );"
  puts $fh "/******************************* COPY END ********************************************/"
  puts $fh "endmodule"
}

proc hbs_extract_hier_paths_from_simulator_log {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_hbs_vars
  set log_data [list]
  set tmp_data [list]

  set log_file "$a_hbs_vars(log)"
  set fh_log 0
  if { [catch {open $log_file r} fh_log] } {
    hbs_print_msg_id "ERROR" 18 "Failed to open file to read ($log_file)"
    return 1
  }
  set raw_data [split [read $fh_log] "\n"]

  #
  # use-cases:-
  #
  # xilinx_hier_bypass_ports:top.I1.I2.I3 XIL_PORT_SPEC:in:integer:CH0_GTMRXN:CH0_GTMRXN_integer out:integer:CH1_GTMTXP:CH1_GTMTXP_integer
  # xilinx_hier_bypass_ports:top.I1.g_MODEM_GTM_PRI[0].u_modem_gtm_pri XIL_PORT_SPEC:in:integer:CH0_GTMRXN:CH0_GTMRXN_integer out:integer:CH1_GTMTXP:CH1_GTMTXP_integer
  # xilinx_hier_bypass_ports:top.I1.\g_MODEM_GTM_PRI[0].\u_modem_gtm_pri  XIL_PORT_SPEC:in:integer:CH0_GTMRXN:CH0_GTMRXN_integer out:integer:CH1_GTMTXP:CH1_GTMTXP_integer
  #
  foreach line $raw_data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue }
    if { [regexp {xilinx_hier_bypass_ports} $line] } {
      set line [string trim [string trimleft $line {#}]]
      lappend tmp_data $line
    }
  }
  close $fh_log

  foreach line $tmp_data {
    set index [string first {XIL_PORT_SPEC} $line]
    set line_str [string range $line 0 $index-1]
    set hier_path [lindex [split $line_str {:}] 1]

    # set the testbench top name
    set a_hbs_vars(user_design_testbench) [lindex [split $hier_path {.}] 0]
    set port_spec_str [string range $line $index+14 end]
    set value "$hier_path#$port_spec_str" 
    lappend log_data $value
  }
  return $log_data
}

proc hbs_print_msg_id { type id str } {
  # Summary:
  # Argument Usage:
  # Return Value:

  if { [catch {package require Vivado}] } {
    set msg "$type: \[generate_hier_access-Tcl-$id\] \"$str\""
    puts $msg
  } else {
    catch {send_msg_id generate_hier_access-Tcl-${id} $type $str}
  }
}

proc hbs_is_valid_hier_path { top line } {
  # Summary:
  # Argument Usage:
  # Return Value:

  #
  # valid  :- tb.mod_i.ent_i#in:integer:in1:in out:integer:out1:out
  # invalid:- gtm_dual#in:integer:CH0_GTMRXN:CH0_GTMRXN_integer out:integer:CH0_GTMTXN:CH0_GTMTXN_integer
  #
  set spec [string trim $line]
  if { [string length $spec] == 0 } {
    return false
  }
  set hier_path      [lindex [split $spec {#}] 0]
  set hier_inst_v    [split $hier_path {.}]
  set hier_top_value [lindex $hier_inst_v 0]
  if { ([llength $hier_inst_v] > 1) && ($top == $hier_top_value) } {
    #puts "VALID_HIER_PATH:$hier_path"
    return true
  }
  return false
}

proc hbs_resolve_hier_path { path } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # 
  # Replace all \. with " ."
  #
  # Example:-
  #   input -> I1.\g_MODEM_GTM_PRI[0].u_modem_gtm_pri\.\g_gt.u_modem_gtm_ch0\
  #   output > I1.\g_MODEM_GTM_PRI[0].u_modem_gtm_pri .\g_gt.u_modem_gtm_ch0
  #

  set out_path {}
  #
  # 1. remove trailing back-slash (\) -> I1.\g_MODEM_GTM_PRI[0].u_modem_gtm_pri\.\g_gt.u_modem_gtm_ch0
  #
  set in_path [string trim $path {\\}]
  #puts "VAL_1:$in_path"
  #
  # 2. temporarily replace dot with # -> I1#\g_MODEM_GTM_PRI[0]#u_modem_gtm_pri\#\g_gt+u_modem_gtm_ch0
  #
  regsub -all {\.} $in_path {#} in_path
  #puts "VAL_2:$in_path"
  #
  # 3. replace \# with space dot " ." -> I1#\g_MODEM_GTM_PRI[0]#u_modem_gtm_pri .\g_gt+u_modem_gtm_ch0
  #
  regsub -all {\\#} $in_path { .} in_path
  #puts "VAL_3:$in_path"
  #
  # 4. replace # back to dot .        -> I1.\g_MODEM_GTM_PRI[0].u_modem_gtm_pri .\g_gt.u_modem_gtm_ch0
  #
  regsub -all {#} $in_path {.} in_path
  #puts "VAL_4:$in_path"

  set out_path $in_path
  return $out_path
}
}

if { [catch {package require Vivado}] } {
  namespace import ::tclapp::xilinx::projutils::generate_hier_access
}
