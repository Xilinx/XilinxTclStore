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

proc ::tclapp::xilinx::designutils::generate_netlist_ip { ipFile } {

    # Summary : Helper proc to generate a functional simulation netlist for a given IP
    
    # Argument Usage:
    # ipFile : Name of the IP to be generated

    # Return Value:
    # 0 : operation successful
    # 1 : an error occured

    # 1.  Validate the IP
    if { [ validateIP $ipFile ] > 0 } {
      return 1;
    }

    # 2. Determine working values
    set srcFile                     [ get_files "$ipFile" -filter {FILE_TYPE==IP} ];
    set srcFileDir                  [ file dirname $srcFile ]
    set baseName                    [ file tail [ file rootname $srcFile ] ]
    set dcpFullPath                 "$srcFileDir/$baseName.dcp"

    append stubFullPath             "$srcFileDir/$baseName" "_stub.v"
    append structSimVHDLFullPath    "$srcFileDir/$baseName" "_funcsim.vhd"
    append structSimVerilogFullPath "$srcFileDir/$baseName" "_funcsim.v"

    set srcFileBehavioralLanguage   [ getBehaviorialLanguage $srcFile ]
    set projectSimulatorLanguage    [ string toupper [ get_property SIMULATOR_LANGUAGE [current_project] ] ]
  
    # 3. Generate the output products of the file
    #    Note: Need to reset ALL the targets to remove any externally added sources
    reset_target all $srcFile
    generate_target all $srcFile

    # 4. Synthesis the design
    synth_design -top $baseName -mode out_of_context
    rename_ref -prefix_all $baseName

    # 5. Write out the checkpoint and stub file
    write_checkpoint $dcpFullPath
    add_files -of [ get_files $srcFile ] $dcpFullPath 

    write_verilog -force -mode synth_stub $stubFullPath
    add_files -of [ get_files $srcFile ] $stubFullPath 
    
    # 6. Write out the structural simulation file
    if { [ expr { $projectSimulatorLanguage == "MIXED" } || \
                { $projectSimulatorLanguage == "VERILOG" } && { $srcFileBehavioralLanguage == "VHDL" } || \
                { $projectSimulatorLanguage == "VERILOG" } && { $srcFileBehavioralLanguage == "MIXED" } ] } {

      # Write out the structural verilog simulation file
      write_verilog -force -mode funcsim $structSimVerilogFullPath
      add_files -of [ get_files $srcFile ] $structSimVerilogFullPath 
    } else {

      # Write out the structural VHDL simulation file
      write_vhdl -force -mode funcsim $structSimVHDLFullPath
      add_files -of [ get_files $srcFile ] $structSimVHDLFullPath 
    }
    
    # 7. Close the design and exit
    close_design

    return 0;
}

proc ::tclapp::xilinx::designutils::getBehaviorialLanguage { ipFile } {

  # Summary : Determines the behavioral language that the IP support by examining
  #           the simulation files it has.
    
  # Argument Usage:
  # ipFile : Name of the ip to be examined

  # Return Value:
  # VERILOG : (default) Verilog language
  # VHDL    : VHDL language
  # MIXED   : Both languages are suppored

  set retVal "VERILOG"

  if { [llength [get_files -quiet -of [get_files $ipFile] -used_in simulation -filter {FILE_TYPE==VHDL} ]] > 0 } {
    set retVal "VHDL"

    if { [llength [get_files -quiet -of [get_files $ipFile] -used_in simulation -filter {FILE_TYPE==VERILOG} ]] > 0 } {
      set retVal "MIXED"
    }
  } 

  return $retVal;
}

proc ::tclapp::xilinx::designutils::validateIP { ipFile } {

  # Summary : Validate that the given file is valid to create a netlist for
    
  # Argument Usage:
  # ipFile : Name of the ip to be validated

  # Return Value:
  # 0 : The IP is valid
  # 1 : The IP is not valid

  # 1. Is the IP part of the project
  if { [ llength [get_files -quiet "$ipFile" ] ] == 0 } {
    puts "ERROR: The given file isn't part of the project: '$ipFile'";
    return 1;
  }

  # 2. Are there more then one IP with this given name
  if { [ llength [ get_files -quiet "$ipFile" ] ] > 1 } {
    puts "ERROR: The more then one file with the same given name in the project: '$ipFile'";
    return 1;
  }

  # 3. Make sure that the IP file is an IP
  if { [ llength [get_files -quiet "$ipFile" -filter {FILE_TYPE==IP} ] ] == 0 } {
    puts "ERROR: The given file isn't an IP: '$ipFile'";
    return 1;
  }

  # 4. Make sure that the IP's generate_synth_checkpoint value is set
  if { [ get_property GENERATE_SYNTH_CHECKPOINT [ get_files -quiet "$ipFile" ] ] == 0} {
    puts "ERROR: The given file isn't marked to generate a synthesis checkpoint: '$ipFile'";
    return 1;
  }

  # 5. Make sure that the IP's isn't locked
  if { [ get_property IS_LOCKED [ get_files -quiet "$ipFile" ] ] == 1} {
    puts "ERROR: The given file is locked: '$ipFile'";
    return 1;
  }

  # At this point all is good
  return 0;
}
