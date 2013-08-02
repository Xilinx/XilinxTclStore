####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export generate_netlist_ip
}

proc ::tclapp::xilinx::designutils::generate_netlist_ip { args } {

    # Summary : Generate synthesized design checkpoint file for an IP
    
    # Argument Usage:
    # ip_file : Name of the IP

    # Return Value:
    # true (0) if success, false (1) otherwise

    set ip_file $args
    # ip file is a required argument, print help if not specified
    if {[string length $ip_file] == 0 } {
      puts "ERROR:Missing value for option 'ip_file', please type 'generate_netlist_ip -help' for usage info."
      return 1
    }

    # Validate IP
    if { [validate_ip $ip_file] } {
      return 1
    }

    set src_file       [get_files "$ip_file" -filter {FILE_TYPE==IP}]
    set src_file_dir   [file dirname $src_file]
    set base_file_name [file tail [file rootname $src_file]]
    set dcp_file_path  "$src_file_dir/$base_file_name.dcp"

    set base_file "$src_file_dir/$base_file_name"

    append verilog_stub_file    "$base_file" "_stub.v"
    append vhdl_funcsim_file    "$base_file" "_funcsim.vhd"
    append verilog_funcsim_file "$base_file" "_funcsim.v"

    set src_lang_type  [get_behav_lang_type $src_file]
    set simulator_lang [string toupper [get_property SIMULATOR_LANGUAGE [current_project]]]
  
    # reset ALL targets to remove any externally added sources
    reset_target all $src_file

    # generate output products
    generate_target all $src_file

    # synthesis
    synth_design -top $base_file_name -mode out_of_context
    rename_ref -prefix_all $base_file_name

    # write checkpoint, stub file and add to fileset
    write_checkpoint $dcp_file_path
    write_verilog -force -mode synth_stub $verilog_stub_file

    add_files -of [get_files $src_file] $dcp_file_path 
    add_files -of [get_files $src_file] $verilog_stub_file 
    
    # write structural verilog or vhdl simulation file based on simulator and source lang type
    if { [expr {$simulator_lang == "MIXED"} || \
               {$simulator_lang == "VERILOG"} && {$src_lang_type == "VHDL"  } || \
               {$simulator_lang == "VERILOG"} && {$src_lang_type == "MIXED" }] } {

      write_verilog -force -mode funcsim $verilog_funcsim_file
      add_files -of [ get_files $src_file ] $verilog_funcsim_file 
    } else {
      write_vhdl -force -mode funcsim $vhdl_funcsim_file
      add_files -of [ get_files $src_file ] $vhdl_funcsim_file 
    }
   
    close_design

    if {[file exists $dcp_file_path]} {
      puts "INFO: Design checkpoint file created:$dcp_file_path"
    } else {
      puts "ERROR: Design checkpoint file does not exist! '$dcp_file_path'"
      return 1
    }
    return 0
}

proc ::tclapp::xilinx::designutils::get_behav_lang_type { ip_file } {

    # Summary : Determine the behavioral language that the IP support by examining its simulation files
    
    # Argument Usage:
    # ip_file : Name of the ip to be examined

    # Return Value:
    # VERILOG : (default) Verilog language
    # VHDL    : VHDL language
    # MIXED   : Both languages are suppored
  
    set lang_type "VERILOG"
    # check if vhdl sources present. If yes, set lang_type vhdl. Further check if verilog also present. If yes, then set mixed. 
    if { [llength [get_files -quiet -of [get_files $ip_file] -used_in simulation -filter {FILE_TYPE==VHDL}]] > 0 } {
      set lang_type "VHDL"

      # any verilog sources? 
      if { [llength [get_files -quiet -of [get_files $ip_file] -used_in simulation -filter {FILE_TYPE==VERILOG}]] > 0 } {
        set lang_type "MIXED"
      }
    }
  
    return $lang_type
}

proc ::tclapp::xilinx::designutils::validate_ip { ip_file } {

    # Summary : Validate that the given IP file is valid to create a netlist for
    
    # Argument Usage:
    # ip_file : Name of the ip to be validated

    # Return Value:
    # true (0) if IP is valid, false (1) otherwise (not a valid IP)

    # is IP part of the project
    if { [llength [get_files -quiet "$ip_file" ]] == 0 } {
      puts "ERROR: The given file is not part of the project: '$ip_file'"
      return 1
    }

    # duplicate IP's present in the project
    if { [llength [get_files -quiet "$ip_file"]] > 1 } {
      puts "ERROR: There more then one IP file with the same given name in the project: '$ip_file'"
      return 1
    }

    # make sure specified file is an IP
    if { [llength [get_files -quiet "$ip_file" -filter {FILE_TYPE==IP}]] == 0 } {
      puts "ERROR: The given file is not an IP: '$ip_file'"
      return 1
    }

    # make sure the 'generate_synth_checkpoint' value is set
    if { [get_property GENERATE_SYNTH_CHECKPOINT [get_files -quiet "$ip_file"]] == 0 } {
      puts "ERROR: The specified IP file is not marked to generate a synthesis checkpoint:'$ip_file'"
      return 1
    }

    # make sure the IP's is not locked
    if { [get_property IS_LOCKED [get_files -quiet "$ip_file"]] == 1 } {
      puts "ERROR: The specified IP file is locked:'$ip_file'"
      return 1
    }

    # IP is valid
    return 0
}
