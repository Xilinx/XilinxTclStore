# Usage: write_questa_autocheck_script <top_module> [-output_directory <output_directory>] [-use_existing_xdc|-generate_sdc]
###############################################################################
#
# write_questa_autocheck_script.tcl (Routine for Mentor Graphics Questa AutoCheck Application)
#
# Script created on 12/20/2016 by Islam Ahmed (Mentor Graphics Inc) &
#                                 Ravi Kurlagunda
# Script last Modified on 05/29/2023
# Vivado v2022.1
###############################################################################

namespace eval ::tclapp::mentor::questa_cdc {
  # Export procs that should be allowed to import into other namespaces
  namespace export write_questa_autocheck_script
}

proc ::tclapp::mentor::questa_cdc::matches_default_libs {lib} {
  
  # Summary: internally used routine to check if default libs used
  
  # Argument Usage:
  # lib: name of lib to check if default lib

  # Return Value:
  # 1 is returned when the passed library matches on of the names of the default libraries

  # Categories: xilinxtclstore, siemens, questa_autocheck

  regsub ":.*" $lib {} lib
  if {[string match -nocase $lib "xil_defaultlib"]} {
    return 1
  } elseif {[string match -nocase $lib "work"]} {
    return 1
  } else {
    return 0
  }
}

proc ::tclapp::mentor::questa_cdc::uniquify_lib {lib lang num} {
  
  # Summary: internally used routine to uniquify libs
  
  # Argument Usage:
  # lib  : lib name to uniquify
  # lang : HDL language
  # num  : uniquified lib name

  # Return Value:
  # The name of the uniquified library is returned 

  # Categories: xilinxtclstore, siemens, questa_autocheck


  set new_lib ""
  if {[matches_default_libs $lib]} {
    set new_lib [concat $lib:$lang:$num]
  } else {
    set new_lib [concat $lib:$lang]
  }
  return $new_lib
}
proc ::tclapp::mentor::questa_cdc::sv_vhdl_keyword_table {keyword_table} {

  set keywords {library module entity package ENTITY PACKAGE `protect all define function task localparam interface `timescale}
  foreach keyword $keywords {
    dict incr keyword_table $keyword
  }    
  return $keyword_table
}
proc ::tclapp::mentor::questa_cdc::is_sv_vhdl_keyword {keyword_table word} {

  return [dict exists $keyword_table $word]
}

proc ::tclapp::mentor::questa_cdc::write_questa_autocheck_script {args} {

  # Summary : This proc generates the Questa AutoCheck script file

  # Argument Usage:
  # top_module : Provide the design top name
  # [-output_directory <arg>]: Specify the output directory to generate the scripts in
  # [-use_existing_xdc]: Ignore running write_xdc command to generate the SDC file of the synthesized design, and use the input constraints file instead
  # [-generate_sdc]: To generate the SDC file of the synthesized design
  # [-autocheck_constraints]:Directives in the form of tcl File
  # [-run <arg>]: Run Questa AutoCheck and invoke the UI of Questa AutoCheck debug after generating the running scripts, default behavior is to stop after the generation of the scripts
  # [-verify_timeout <arg>]: Specify the timeout for Questa AutoCheck Verify run. By default the value specified is in seconds, use 'm' or 'h' suffix to interpret the value as minutes or hours 
  # [-add_button]: Add a button to run Questa AutoCheck in Vivado UI.
  # [-remove_button]: Remove the Questa AutoCheck button from Vivado UI.

  # Return Value: Returns '0' on successful completion

  # Categories: xilinxtclstore, siemens, questa_autocheck

  set args [subst [regsub -all \{ $args ""]]
  set args [subst [regsub -all \} $args ""]]



  set userOD "."
  set top_module ""
  set use_existing_xdc 0
  set generate_sdc 0
  set autocheck_constraints ""
  set run_questa_autocheck "autocheck compile"
  set autocheck_verify_timeout "10m"
  set autocheck_constraints ""
  set add_button 0
  set remove_button 0
  set usage_msg "Usage : write_questa_autocheck_script <top_module> \[-output_directory <out_dir>\] \[-use_existing_xdc|-generate_sdc\] \[-run <autocheck_compile|autocheck_verify>\] \[-verify_timeout <value>\] \[-autocheck_constraints <constraints_file>\] \[-add_button\] \[-remove_button\]"
  # Parse the arguments
  if { [llength $args] > 10 } {
    puts "** ERROR : Extra arguments passed to the proc."
    puts $usage_msg
    return 1
  }
  # Generate help message
  if { ([llength $args] >= 1) && ([lsearch -exact $args "-help"] != "-1") } {
    puts $usage_msg
    return 0
  }
  for {set i 0} {$i < [llength $args]} {incr i} {
    if { [lindex $args $i] == "-output_directory" } {
      incr i
      set userOD "[lindex $args $i]"
      if { $userOD == "" } {
        puts "** ERROR : Specified output directory can't be null."
        puts $usage_msg
        return 1
      }
    } elseif { [lindex $args $i] == "-use_existing_xdc" } {
      set use_existing_xdc 1
    } elseif { [lindex $args $i] == "-generate_sdc" } {  
      set generate_sdc 1
    } elseif { [lindex $args $i] == "-autocheck_constraints" } { 
      incr i
        set autocheck_constraints "[lindex $args $i]" 
        if { ($autocheck_constraints == "") } { 
          puts "** ERROR : Missing argument value for -autocheck_constraints"
            puts $usage_msg
            return 1
        }     
     set autocheck_constraints [file normalize $autocheck_constraints]
    } elseif { [lindex $args $i] == "-run" } {
     incr i
     set run_questa_autocheck "[lindex $args $i]"
     if { ($run_questa_autocheck != "autocheck_compile") && ($run_questa_autocheck != "autocheck_verify") } {
       puts "** ERROR : Invalid argument value for -run '$run_questa_autocheck'"
       puts $usage_msg
       return 1
     }
    } elseif { [lindex $args $i] == "-verify_timeout" } {
      incr i
      set autocheck_verify_timeout "[lindex $args $i]"
      if { ($autocheck_verify_timeout == "") } {
        puts "** ERROR : Missing argument value for -verify_timeout"
        puts $usage_msg
        return 1
      }
    } elseif { [lindex $args $i] == "-autocheck_constraints" } {
      incr i
      set autocheck_constraints "[lindex $args $i]"
      if { ($autocheck_constraints == "") } {
        puts "** ERROR : Missing argument value for -autocheck_constraints"
        puts $usage_msg
        return 1
      }
      set autocheck_constraints [file normalize $autocheck_constraints]
    } elseif { [lindex $args $i] == "-add_button" } {
      set add_button 1
    } elseif { [lindex $args $i] == "-remove_button" } {
      set remove_button 1
    } else {
      set top_module [lindex $args $i]
    }
  }

  ## Set return code to 0
  set rc 0

  # Getting the current vivado version and remove 'v' from the version string
  set vivado_version [lindex [version] 1]
  regsub {v} $vivado_version {} vivado_version
  set major [lindex [split $vivado_version .] 0]
  set minor [lindex [split $vivado_version .] 1]
  set vivado_version "$major\.$minor"
 

  ## -add_button and -remove_button can't be specified together
  if { ($remove_button == 1) && ($add_button == 1) } {
    puts "** ERROR : '-add_button' and '-remove_button' can't be specified together."
    return 1
  }

  ## Add Vivado GUI button for Questa AutoCheck
  if { $add_button == 1 } {
    ## Example for code of the Vivado GUI button
    ## -----------------------------------------
    ## 0=Run%20Questa%20AutoCheck tclapp::mentor::questa_cdc::write_questa_autocheck_script "" /home/iahmed/questa_autocheck_logo.PNG "" "" true ^@ "" true 4 Top%20Module "" "" false Output%20Directory "" -output_directory%20OD1 true Use%20Existing%20XDC "" -use_existing_xdc true Invoke%20Questa%20AutoCheck%20Run "" -run true
    ## -----------------------------------------

    set OS [lindex $::tcl_platform(os) 0]
    if { $OS == "Linux" } {
      set commands_file "$::env(HOME)/.Xilinx/Vivado/$vivado_version/commands/commands.xml"
    } else {
      set commands_file "$::env(HOME)\\AppData\\Roaming\\Xilinx\\Vivado\\$vivado_version\\commands\\commands.xml"
    }
    #set status [catch {exec grep write_questa_autocheck_script $commands_file} result]
    #if { $status == 0 } {
    #  puts "INFO : Vivado GUI button for running Questa AutoCheck is already installed in $commands_file. Exiting ..."
    #  return $rc
    #}
    set questa_autocheck_logo "$::env(QUESTA_AUTOCHECK_TCL_SCRIPT_PATH)/questa_autocheck_logo.PNG"
    if { ! [file exists $questa_autocheck_logo] } {
      set questa_autocheck_logo "\"$questa_autocheck_logo\""
      puts "INFO: Can't find the Questa AutoCheck logo at $questa_autocheck_logo"
      if { [file exists "$::env(QHOME)/share/fpga_libs/Xilinx/questa_autocheck_logo.PNG"] } {
        set questa_autocheck_logo "\$::env(QHOME)/share/fpga_libs/Xilinx/questa_autocheck_logo.PNG"
        puts "INFO: Found the Questa AutoCheck logo at $questa_autocheck_logo"
      }
    }
    if { [catch {open $commands_file a} result] } {
      puts stderr "ERROR: Could not open commands.xml to add the Questa AutoCheck button, path '$commands_file'\n$result"
      set rc 9
      return $rc
    } else {
      set commands_fh $result
      puts "INFO: Adding Vivado GUI button for running Questa AutoCheck in $commands_file"
    }
    set questa_autocheck_command_index 0
    set vivado_cmds_version "1.0"
    set encoding_cmds_version "UTF-8"
    set major_cmds_version "1"
    set minor_cmds_version "0"
    set name_cmds_version "USER"
    if { [file size $commands_file] } {
      set file1 [open $commands_file r]
      set file2 [read $file1]
      set commands_file_line [split $file2 "\n"]
      set last_command [lindex $commands_file_line end-1]
      
      foreach line $commands_file_line {
	if {[regexp {write_questa_autocheck_script} $line]} {
	  puts "INFO : Vivado GUI button for running Questa AutoCheck is already installed in $commands_file. Exiting ..."
          close $commands_fh
	  close $file1
	  return $rc
	}
      }
      
      if { $last_command == "<custom_commands major=\"$major_cmds_version\" minor=\"$minor_cmds_version\">"} {
        set questa_autocheck_command_index 0
 
      } else {
        set numbers 0
        foreach line $commands_file_line {
	  if {[regexp {<position>([0-9]+)} $line m1 m2]} {
	    set numbers $m2
	  }
	}
	set last_command_index $numbers
        set questa_autocheck_command_index [incr last_command_index]
 
      }
	close $file1
    } else {
      puts $commands_fh "<?xml version=\"$vivado_cmds_version\" encoding=\"$encoding_cmds_version\"?>"
      puts $commands_fh "<custom_commands major=\"$major_cmds_version\" minor=\"$minor_cmds_version\">"
      set questa_autocheck_command_index 0
    }
    puts $commands_fh "  <custom_command>"
    puts $commands_fh "    <position>$questa_autocheck_command_index</position>"
    puts $commands_fh "    <name>Run_Questa_AutoCheck</name>"
    puts $commands_fh "    <menu_name>Run Questa AutoCheck</menu_name>"
    puts $commands_fh "    <command>source $::env(QHOME)/share/fpga_libs/Xilinx/write_questa_autocheck_script.tcl; tclapp::mentor::questa_cdc::write_questa_autocheck_script</command>"
    puts $commands_fh "    <toolbar_icon>$questa_autocheck_logo</toolbar_icon>"
    puts $commands_fh "    <show_on_toolbar>true</show_on_toolbar>"
    puts $commands_fh "    <run_proc>true</run_proc>"
    puts $commands_fh "    <source name=\"$name_cmds_version\"/>"
    puts $commands_fh "    <args>"
    puts $commands_fh "     <arg>"
    puts $commands_fh "        <name>Top_Module</name>"
    puts $commands_fh "        <default>\[lindex \[find_top\] 0\]</default>"
    puts $commands_fh "        <optional>false</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>Output_Directory</name>"
    puts $commands_fh "        <default>-output_directory Questa_AutoCheck</default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>Use_Existing_XDC</name>"
    puts $commands_fh "        <default>-use_existing_xdc</default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "        <name>Generate_SDC</name>"
    puts $commands_fh "        <default>-generate_sdc</default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>Invoke_Questa_AutoCheck_Run</name>"
    puts $commands_fh "        <default>-run autocheck_verify</default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>AutoCheck_Verify_Timeout</name>"
    puts $commands_fh "        <default>-verify_timeout 10m</default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>AutoCheck_Constraints_File</name>"
    puts $commands_fh "        <default></default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "    </args>"
    puts $commands_fh "  </custom_command>"
    puts $commands_fh "</custom_commands>"
# obselet generating .paini file
#    set button_code "$questa_autocheck_command_index=Run%20Questa%20AutoCheck"
#    set button_code "$button_code source%20\$::env(QHOME)/share/fpga_libs/Xilinx/write_questa_autocheck_script.tcl;%20tclapp::mentor::questa_cdc::write_questa_autocheck_script"
                 
#   set button_code "$button_code source%20\$::env(QHOME)/share/fpga_libs/Xilinx/write_questa_autocheck_script.tcl;%20tclapp::mentor::questa_cdc::write_questa_autocheck_script"
#    set button_code "$button_code \"\" $questa_autocheck_logo \"\" \"\" true ^@ \"\" true 6"
#    set button_code "$button_code Top%20Module \"\" \[lindex%20\[find_top\]%200\] false"
#    set button_code "$button_code Output%20Directory \"\" -output_directory%20QAUTOCHECK true"
#    set button_code "$button_code Use%20Existing%20XDC \"\" -use_existing_xdc true"
#    set button_code "$button_code Invoke%20Questa%20AutoCheck%20Run \"\" -run%20autocheck_verify true"
#    set button_code "$button_code AutoCheck%20Verify%20Timeout \"\" -verify_timeout%2010m true"
#    set button_code "$button_code AutoCheck%20Constraints%20File \"\" \"\" true"
#    puts $commands_fh $button_code
 
    close $commands_fh
    ##################################################################################################
    ## to delete the last line in the file equal to set a [catch {exec sed -i "\$d" $commands_file} b]
    set op_file [open "$commands_file.tmp" w]

    ## Read the original commands.xml file
    set ip_file [open "$commands_file" r]
    set ip_data [read $ip_file]
    set ip_lines [split $ip_data "\n"]
    
    for {set i 0} {$i < [llength $ip_lines]} {incr i} { 
      if {[lindex $ip_lines $i] == ""} {
        continue
      } elseif {[lindex $ip_lines $i] == "</custom_commands>"} {
        continue
      } else {
        puts $op_file "[lindex $ip_lines $i]" 
      }
    }    
    puts $op_file "</custom_commands>" 
    close $ip_file
    close $op_file

    #file delete -force $commands_file
    if { $OS == "Linux" } {
       exec rm -rf $commands_file
    } else {
       file delete -force $commands_file
    }
    file rename ${commands_file}.tmp $commands_file
    ##################################################################################################
    return $rc
  }

  ## Remove Vivado GUI button for Questa AutoCheck
  if { $remove_button == 1 } {
    set OS [lindex $::tcl_platform(os) 0]
    if { $OS == "Linux" } {
      set commands_file "$::env(HOME)/.Xilinx/Vivado/$vivado_version/commands/commands.xml"
    } else {
      set commands_file "$::env(HOME)\\AppData\\Roaming\\Xilinx\\Vivado\\$vivado_version\\commands\\commands.xml"
    }
    if { [file exist $commands_file] } {
    ## Temp file to write the modified file
    set op_file [open "$commands_file.tmp" w]

    ## Read the original commands.xml file
    set ip_file [open "$commands_file" r]
    set ip_data [read $ip_file]
    set ip_lines [split $ip_data "\n"]

    set questa_autocheck_command_found 0
    set questa_autocheck_command_found_flag 0
    set position 0

    for {set i 0} {$i < [llength $ip_lines]} {incr i} {
	if { $questa_autocheck_command_found_flag == 0 } {
	  if { [regexp {\s\s\<custom_command\>} [lindex $ip_lines $i]]  && [regexp {\s\s\s\<name\>Run_Questa_AutoCheck\</name\>} [lindex $ip_lines [expr $i + 2]]] } {
	    regexp {<position>([0-9]+)\</position\>} [lindex $ip_lines [expr $i + 1]] m1 m2
	    set position $m2
            set questa_autocheck_command_found 1
            set questa_autocheck_command_found_flag 1
	    continue
          }
        } else {
	  if { ! [regexp {\s\s\</custom_command\>} [lindex $ip_lines $i]] } {
	    continue
	  } else {
  	    set questa_autocheck_command_found_flag 0
	    continue
	  }
        }
      
      if {$questa_autocheck_command_found_flag == 0 && $questa_autocheck_command_found == 1 && [regexp {<position>([0-9]+)\</position\>} [lindex $ip_lines $i]]} {
        puts $op_file "  <position>$position\</position\>"
	incr position
      } else {
          if {[lindex $ip_lines $i] == ""} {
	    continue
	  } else {
	  puts $op_file "[lindex $ip_lines $i]"
	}
      }
    }
    close $ip_file
    close $op_file

    ## Now, remove the old commands file and replace it with the new one
    #exec rm -f 
    #file delete -force $commands_file
    if { $OS == "Linux" } {
       exec rm -rf $commands_file
    } else {
       file delete -force $commands_file
    }
    file rename ${commands_file}.tmp $commands_file
    if { $questa_autocheck_command_found == 1 } {
      puts "INFO: Vivado GUI button for running Questa AutoCheck is removed from $commands_file"
    } else {
      puts "INFO: Vivado GUI button for running Questa AutoCheck wasn't found in $commands_file."
      puts "    : File has not been changed."
    }
  } else {
    puts "INFO: File $::env(HOME)/.Xilinx/Vivado/$vivado_version/commands/commands.xml not exist, cannot remove from unexisting file"
  }
    return $rc
  }

  if { $top_module == "" } {
    puts "** ERROR : No top_module specified to the proc."
    puts $usage_msg
    return 1
  }
  if { $userOD == "." } {
    puts "INFO: Output files will be generated at [file join [pwd] $userOD]"
  } else {
    puts "INFO: Output files will be generated at $userOD"
    file mkdir $userOD
  }

  set qautocheck_ctrl "qautocheck_ctrl.tcl"
  set qautocheck_compile_tcl "qautocheck_compile.tcl"
  set run_makefile "Makefile.qautocheck"
  set run_batfile "run_qac.bat"
  set run_sdcfile "qautocheck_sdc.tcl"
  set run_script "qautocheck_run.sh"
  set encrypted_lib "dummmmmy_lib"

  ## Vivado install dir
  set vivado_dir $::env(XILINX_VIVADO)
  puts "INFO: Using Vivado install directory $vivado_dir"

  ## If set to 1, will strictly respect file order - if lib files appear non-consecutively this order is maintained
  ## otherwise will respect only library order - if lib files appear non-consecutively they will still be merged into one compile command
  set resp_file_order 1
  ##creating Verilog and VHDL keywords table 
  set keyword_table [dict create]
  set keyword_table [sv_vhdl_keyword_table $keyword_table]

  ## Does VHDL file for default lib exist
  set vhdl_default_lib_exists 0
  ## Does Verilog file for default lib exist
  set vlog_default_lib_exists 0

  set vhdl_std "-93"
  set timescale "1ps"

  # Settings
  set top_lib_dir "qft"
  set autocheck_out_dir "AUTOCHECK_RESULTS"
  set modelsimini "modelsim.ini"

  # Open output files to write
  if { [catch {open $userOD/$run_batfile w} result] } {
    puts stderr "ERROR: Could not open $run_batfile for writing\n$result"
    set rc 2
    return $rc
  } else {
    set qautocheck_run_batfile_fh $result
    puts "INFO: Writing Questa autocheck run batfile to file $userOD/$run_batfile"
  }
  if { [catch {open $userOD/$run_sdcfile w} result] } {
    puts stderr "ERROR: Could not open $run_sdcfile for writing\n$result"
    set rc 2
    return $rc
  } else {
    set qautocheck_run_sdcfile_fh $result
    puts "INFO: Writing Questa autocheck run batfile to file $userOD/$run_sdcfile"
  }
  if { [catch {open $userOD/$run_script w} result] } {
    puts stderr "ERROR: Could not open $run_script for writing\n$result"
    set rc 2
    return $rc
  } else {
    set qautocheck_run_fh $result
    puts "INFO: Writing Questa autocheck run script to file $userOD/$run_script"
  }
  if { [catch {open $userOD/$run_makefile w} result] } {
    puts stderr "ERROR: Could not open $run_makefile for writing\n$result"
    set rc 2
    return $rc
  } else {
    set qautocheck_run_makefile_fh $result
    puts "INFO: Writing Questa AutoCheck run Makefile to file $userOD/$run_makefile"
  }

  if { [catch {open $userOD/$qautocheck_ctrl w} result] } {
    puts stderr "ERROR: Could not open $qautocheck_ctrl for writing\n$result"
    set rc 3
    return $rc
  } else {
    set qautocheck_ctrl_fh $result
    puts "INFO: Writing Questa AutoCheck control directives script to file $userOD/$qautocheck_ctrl"
  }

  if { [catch {open $userOD/$qautocheck_compile_tcl w} result] } {
    puts stderr "ERROR: Could not open $qautocheck_compile_tcl for writing\n$result"
    set rc 4
    return $rc
  } else {
    set qautocheck_compile_tcl_fh $result
    puts "INFO: Writing Questa AutoCheck Tcl script to file $userOD/$qautocheck_compile_tcl"
  }


  set found_top 0
  foreach t [find_top] {
    if {[string match $t $top_module]} {
      set found_top 1
    }
  }
  if {$found_top == 0} {
    puts stderr "ERROR: Could not find any user specified $top_module in the list of top modules identified by Vivado - [find_top]"
    set rc 5
    return $rc
  }

  # Get the PART and the ARCHITECTURE of the target device 
  set arch_name [get_property ARCHITECTURE [get_parts [get_property PART [current_project]]]]
  # Identify synthesis fileset
  #set synth_fileset [lindex [get_filesets * -filter {FILESET_TYPE == "DesignSrcs"}] 0]
  set synth_fileset [current_fileset]
  if { [string match $synth_fileset ""] } {
    puts stderr "ERROR: Could not find any synthesis fileset"
    set rc 6
    return $rc
  } else {
    puts "INFO: Found synthesis fileset $synth_fileset"
  }
  update_compile_order -fileset $synth_fileset

  ######CDC-25493- Extraction of +define options########
   set verilog_define_options [ get_property verilog_define [current_fileset] ]
   if { [string match $verilog_define_options ""]  } {
   } else {
         set modified_verilog_define_options [regsub -all " " $verilog_define_options "+"]
         set prefix_verilog_define_options "+define+"
         set verilog_define_options "${prefix_verilog_define_options}${modified_verilog_define_options}"
  }  
 


  
  ## Blackbox unisims
#  link_design -part [get_parts [get_property PART [current_project]]]
#  puts "set_option stop {\\"
#  set num_c 0
#  foreach c [get_lib_cells] {
#    incr num_c
#    puts -nonewline "$c "
#    if {[expr $num_c%10] == 0} {
#      puts "\\"
#    }
#  }
#  puts "}\n"

  #set proj_name [get_property NAME [current_project]]
  ## Get list of IPs being used
  set ips [get_ips *]
  set num_ip [llength $ips]
  puts "INFO: Found $num_ip IPs in design"

  ## Keep track of libraries to avoid duplicat compilation
  array set compiled_lib_list {}
  array set lib_incdirs_list {}
  array set black_box_libs {}
  set compile_lines [list ]
  set black_box_lines [list ]
  set line ""

  ## Set black-boxes for blk_mem_gen and fifo_gen if they are part of the IP
  foreach ip $ips {
    set ip_ref [get_property IPDEF $ip]
    regsub {xilinx.com:ip:} $ip_ref {} ip_name
    regsub {:} $ip_name {_v} ip_name
    regsub {\.} $ip_name {_} ip_name
    if {[regexp {xilinx.com:ip:blk_mem_gen:} $ip_ref]} {
      set line "netlist blackbox ${ip_name}_synth"
      lappend black_box_lines $line
      set black_box_libs($ip_name) 1
    }
  }

  set num_files 0
  set global_incdirs [list ]

  ## Get filelist for each IP
  for {set i 0} {$i <= $num_ip} {incr i} {
    if {$i < $num_ip} {
      set ip [lindex $ips $i]
      if {[catch {  set ip_container [get_property IP_CORE_CONTAINER $ip]       } errmsg]} {
        puts "ErrorMsg: $errmsg"
	set ip_container "dummy"
	} 


#support for CDC-25506 - "write_questa_cdc_script" needs to be enhanced to automatically extract source code for compressed Xilinx IP Containers (.xcix files).
      if {[regexp {xcix} $ip_container all value] && [file exists $ip_container]}  {
              set is_xcix "1"
              set ip_name [get_property NAME $ip]
              set xcix_ip_name [get_property NAME $ip]
              set ip_ref [get_property IPDEF $ip]
              set extracted_files [extract_files -base_dir $userOD/ip [get_files $ip_name.xcix]]
	      set wrong_files [get_files -compile_order sources -used_in synthesis -of_objects $ip]
              set files ""
              foreach wrong_file $wrong_files {
			set hdl_file [file tail $wrong_file]
			foreach extract_file $extracted_files { 
				if {[regexp $hdl_file $extract_file]}  {
                                        if {[regexp {vho} $extract_file all value]  || [regexp {veo} $extract_file all value]  || [regexp {txt} $extract_file all value] || [regexp {tb_} $extract_file all value]}	{ 
					} else {						 
					      lappend files $extract_file
                                        }
				}
			}
	      }
      } else  { 
	      set is_xcix "0"
	      set ip [lindex $ips $i]
	      set ip_name [get_property NAME $ip]
	      set ip_ref [get_property IPDEF $ip]
	      puts "INFO: Collecting files for IP $ip_ref ($ip_name)"
	      set files ""
	      set files_tmp [get_files -compile_order sources -used_in synthesis -of_objects $ip]
 	      foreach file_tmp $files_tmp {
		  if {[file exists $file_tmp]} {
		          lappend files $file_tmp
		 }
	      }
              # Keep a list of all the include files, this is added to handle an issue in the 'wavegen' Xilinx example in which clog2b.vh wasn't added into compilation file
              set all_include_files [get_files -filter {USED_IN_SYNTHESIS && FILE_TYPE =="Verilog Header"}]
              foreach include_file $all_include_files {
#                 if { [lsearch -exact $files $include_file] == "-1" } {
	      if {[file exists $include_file]} {
                      lappend files $include_file
		}
#                  }
             }
       }
    } else {
      set is_xcix "0"
      set ip $top_module
      set ip_name $top_module
      set ip_ref  $top_module
      set files ""
      set files_tmp [get_files -norecurse -compile_order sources -used_in synthesis]
      foreach ftmp $files_tmp {
            if {[file exists $ftmp]}  {
                   lappend files $ftmp
            }
      }
      # Keep a list of all the include files, this is added to handle an issue in the 'wavegen' Xilinx example in which clog2b.vh wasn't added into compilation file
      set all_include_files [get_files -filter {USED_IN_SYNTHESIS && FILE_TYPE =="Verilog Header"}]
      foreach include_file $all_include_files {
        if { [lsearch -exact $files $include_file] == "-1" && [file exists $include_file] } {
          lappend files $include_file
        }
      }
      puts "INFO: Collecting files for Top level"
    }





    puts "DEBUG: Files for (IP: $ip) are: $files"

    set lib_file_order []
    array set lib_file_array {}

    set prev_lib ""
    set prev_hdl_lang ""
    set num_lib 0
    ## Find all files for the IP or Top level
    foreach f $files {
      #set f1 [lindex [get_files -of [get_filesets $synth_fileset] $f] 0]
      incr num_files
      if {$is_xcix == "1"} {
            set fn $f
            set lib $xcix_ip_name
	    set wrong_files2 [get_files -compile_order sources -used_in synthesis -of_objects $ip]
			set hdl_file2 [file tail $f]
			foreach wrong_file2 $wrong_files2 { 
				if {[regexp $hdl_file2 $wrong_file2]}  {
                                        if {[regexp {vho} $wrong_file2 all value]  || [regexp {veo} $wrong_file2 all value] || [regexp {txt} $extract_file all value] || [regexp {tb_} $extract_file all value] }	{ 
					} else {						 
					      set f_original  $wrong_file2
                                        }
				}
			}
#            set lib [get_property LIBRARY [lindex [get_files -all -of [get_filesets $synth_fileset] $f_original] 0]]
             if { [catch {set lib [get_property LIBRARY [lindex [get_files -all -of [get_filesets $synth_fileset] $f_original] 0]]} result] } {
                      set lib $xcix_ip_name
             } else {
                      set lib [get_property LIBRARY [lindex [get_files -all -of [get_filesets $synth_fileset] $f_original] 0]]
             }
            if ([regexp {vhd} $f all value]) {
                     set ft "VHDL"
	    } else   {
                     set ft "SystemVerilog"
            }
      } else {
            if { [get_files -all -of [get_filesets $synth_fileset] $f] != "" } {
                  set fn [get_property NAME [lindex [get_files -all -of [get_filesets $synth_fileset] $f] 0]]
                  set ft [get_property FILE_TYPE [lindex [get_files -all -of [get_filesets $synth_fileset] $f] 0]]
     		 if { [string match $ft "VHDL 2008"] }  {
      		     set ft "VHDL"
      		     set vhdl_std "-2008"
    		  }
                  set fs [get_property FILESET_NAME [lindex [get_files -all -of [get_filesets $synth_fileset] $f] 0]]
                  set lib [get_property LIBRARY [lindex [get_files -all -of [get_filesets $synth_fileset] $f] 0]]
            } else {
                 set fn [get_property NAME [lindex [get_files -all $f] 0]]
                 set ft [get_property FILE_TYPE [lindex [get_files -all $f] 0]]
    		  if { [string match $ft "VHDL 2008"] }  {
      		     set ft "VHDL"
      		     set vhdl_std "-2008"
     		 }
                 set fs [get_property FILESET_NAME [lindex [get_files -all $f] 0]]
                 set lib [get_property LIBRARY [lindex [get_files -all $f] 0]]
            }
      }

      puts "\nINFO: File= $fn Library= $lib File_type= $ft "
      ## Create a new compile unit if library or language changes between the previous and current files
      if {$prev_lib == ""} {
        set num_lib 0
      } elseif {![string match -nocase $lib $prev_lib]} {
        incr num_lib
      }
      if {$resp_file_order == 1} {
        set lib [uniquify_lib $lib $ft $num_lib]
      }

      ## Create a list of files for each library
      if {[string match $ft "Verilog"] || [string match $ft "Verilog Header"] || [string match $ft "SystemVerilog"] || [string match $ft "VHDL"] || [string match $ft "VHDL 2008"]} {
        if {[info exists lib_file_array($lib)]} {
 

      	  set file_h [open $fn]
      	  set found_encrypted 1
      	  while {[gets $file_h line] >= 0} {
            foreach word [split $line] {
              if { [ is_sv_vhdl_keyword $keyword_table $word ]  } {
                set found_encrypted 0
                  break
              }
            }
      
            if {  [regexp $encrypted_lib $line ]    } {
                 set found_encrypted 1
                 break
             }
                    
      	  }
      	  close $file_h
            if {$found_encrypted == "1"} {
              regsub ":.*" $lib {} encrypted_lib
            }  else {
              set lib_file_array($lib) [concat $lib_file_array($lib) " " $fn]
            }
      
         } else {

          set file_h [open $fn]
          set found_encrypted 1
          while {[gets $file_h line] >= 0} {
            foreach word [split $line] {
              if { [ is_sv_vhdl_keyword $keyword_table $word ]  } {
                set found_encrypted 0
                  break
              }
            }
            if {  [regexp $encrypted_lib $line ]    } {
                  set found_encrypted 1
                  break
              }
          }
          close $file_h
          if {$found_encrypted == "1" } {
            regsub ":.*" $lib {} encrypted_lib
          }  else {
            set lib_file_array($lib) $fn
              if { ![regexp {mem_gen_v\d+_\d+} $lib] && ![regexp {fifo_generator_v\d+_\d+} $lib]  } {
                  lappend lib_file_order $lib
            } else {
                  set lib_file_order_tmp $lib_file_order
                  set lib_file_order $lib
                  foreach lib_tmp $lib_file_order_tmp  {
                          lappend lib_file_order  $lib_tmp
                  }
            }

          }



          puts "\nINFO: Adding Library= $lib to list of libraries"
        }
      }

      set lib_file_lang($lib) $ft
      regsub ":.*" $lib {} prev_lib

      ## Header files don't count and will not cause new compile unit to be created
      if {![string match -nocase $ft "Verilog Header"]} {
        set prev_hdl_lang $ft
      }

      if {([string match $ft "Verilog"] || [string match $ft "SystemVerilog"]) && [matches_default_libs $lib]} {
        set vlog_default_lib_exists 1
      }
      if {[string match $ft "VHDL"] && [matches_default_libs $lib]} {
        set vhdl_default_lib_exists 1
      }
    }

    ## Check that the header files of a specific IP really exists in all the libraries' lists for this IP
    foreach f $files {
#      set ft [get_property FILE_TYPE [lindex [get_files -all $f] 0]]
#      set fn [get_property NAME [lindex [get_files -all $f] 0]]
      if {[string match $ft "Verilog Header"]} {
        foreach lib $lib_file_order {
          set lang $lib_file_lang($lib)
          if { ([regexp {Verilog} $lang]) && ([lsearch -exact $lib_file_array($lib) $fn] == "-1") } {
            set lib_file_array($lib) [concat $lib_file_array($lib) " " $fn]
            puts $lib_file_array($lib)
          }
        }
      }
    }

    puts "DEBUG: IP= $ip_ref IPINST = $ip_name has following libraries $lib_file_order" 

    # For each library, list the files
    foreach lib $lib_file_order {
#      if {![info exists compiled_lib_list($lib)] || [matches_default_libs $lib]} {
        regsub ":.*" $lib {} lib_no_num
        puts "INFO: Obtaining list of files for design= $ip_ref, library= $lib"
        set lang $lib_file_lang($lib)
        set incdirs [list ]
        array unset incdir_ar 
        ## Create list of include files
        if {[regexp {Verilog} $lang]} {
          foreach f [split $lib_file_array($lib)] {
          if {$is_xcix == "1"} {
		      set is_include "0"
                      if ([regexp {vhd} $f all value]) {
                          set f_type "VHDL"
	              } else   {
                          set f_type "SystemVerilog"
                      }
           } else {
            if { [get_files -all -of [get_filesets $synth_fileset] $f] != "" } {
              set is_include [get_property IS_GLOBAL_INCLUDE [lindex [get_files -all -of [get_filesets $synth_fileset] $f] 0]]
              set f_type [get_property FILE_TYPE [lindex [get_files -all -of [get_filesets $synth_fileset] $f] 0]]
	      if { [string match $f_type "VHDL 2008"] }  {
		      set f_type "VHDL"
		      set vhdl_std "-2008"
	         }
            } else {
              set is_include [get_property IS_GLOBAL_INCLUDE [lindex [get_files -all $f] 0]]
              set f_type [get_property FILE_TYPE [lindex [get_files -all $f] 0]]
		      if { [string match $f_type "VHDL 2008"] }  {
		      set f_type "VHDL"
		      set vhdl_std "-2008"
	         }
            }
	    }
            if {$is_include == 1 || [string match $f_type "Verilog Header"]} {
              set file_dir [file dirname $f]
              if {![info exists incdir_ar($file_dir)]} {
                lappend incdirs [concat +incdir+$file_dir]
                lappend global_incdirs [concat +incdir+$file_dir]
                puts "INFO: Found include file $f"
                set incdir_ar($file_dir) 1
                set lib_incdirs_list($lib_no_num) $incdirs
              }
            }
          }
        }
        ## Print files to compile script
        set debug_num [llength lib_file_array($lib)]
        puts "DEBUG: Found $debug_num of files in library= $lib, IP= $ip_ref IPINST= $ip_name" 
        if {[string match $lang "VHDL"]} {
          set line "vcom -allowProtectedBeforeBody $vhdl_std -work $lib_no_num \\"
          lappend compile_lines $line
          foreach f [split $lib_file_array($lib)] {
                  if {$is_xcix == "1"} {
                      if ([regexp {vhd} $f all value]) {
                          set f_type "VHDL"
	              } else   {
                          set f_type "SystemVerilog"
                      }
                  } else {
                      if { [get_files -all -of [get_filesets $synth_fileset] $f] != "" } {
                          set f_type [get_property FILE_TYPE [lindex [get_files -all -of [get_filesets $synth_fileset] $f] 0]]
	      if { [string match $f_type "VHDL 2008"] }  {
		      set f_type "VHDL"
		      set vhdl_std "-2008"
	         }
                      } else {
                           set f_type [get_property FILE_TYPE [lindex [get_files -all $f] 0]]
	      if { [string match $f_type "VHDL 2008"] }  {
		      set f_type "VHDL"
		      set vhdl_std "-2008"
	         }
                      }
                  }
            if {[string match $f_type "VHDL"]} {
              if {![regexp {^blk_mem_gen_v\d+_\d+$} $lib] || ([regexp {^blk_mem_gen_v\d+_\d+$} $lib] && [regexp {/blk_mem_gen_v\d+_\d+\.v} $f]) } {
                set line "  $f \\"
                lappend compile_lines $line
              }
            } else {
              puts "DEBUG: FILE_TYPE for file $f is $f_type, library= $lib $lib_no_num fileset= $synth_fileset and does not match VHDL"
            }
          }
          set line "\n"
          lappend compile_lines $line
        } elseif {[string match $lang "Verilog"] || [string match $lang "SystemVerilog"]} {
          if {[string match $lang "SystemVerilog"]} {
            set sv_switch "-sv"
          } else {
            set sv_switch ""
          }

          set line "vlog  -suppress 13389  $verilog_define_options $sv_switch -incr -work $lib_no_num \\"
          lappend compile_lines $line
          if { [info exists lib_incdirs_list($lib_no_num)] && $lib_incdirs_list($lib_no_num) != ""} {
#            foreach idir $lib_incdirs_list($lib_no_num) {
#              set line "  $idir \\"
               set line "  $global_incdirs \\"
              lappend compile_lines $line
#            }
          }
          foreach f [split $lib_file_array($lib)] {
          if {$is_xcix == "1"} {
		      
                      if ([regexp {vhd} $f all value]) {
                          set f_type "VHDL"
	              } else   {
                          set f_type "SystemVerilog"
                      }
           } else {
            if { [get_files -all -of [get_filesets $synth_fileset] $f] != "" } {
              set f_type [get_property FILE_TYPE [lindex [get_files -all -of [get_filesets $synth_fileset] $f] 0]]
	      if { [string match $f_type "VHDL 2008"] }  {
		      set f_type "VHDL"
		      set vhdl_std "-2008"
	         }
            } else {
              set f_type [get_property FILE_TYPE [lindex [get_files -all $f] 0]]
	      if { [string match $f_type "VHDL 2008"] }  {
		      set f_type "VHDL"
		      set vhdl_std "-2008"
	         }
            }
	    }
            if {[string match $f_type "Verilog"] || [string match $f_type "SystemVerilog"]} {
              if {![regexp {^blk_mem_gen_v\d+_\d+$} $lib] || ([regexp {^blk_mem_gen_v\d+_\d+$} $lib] && [regexp {/blk_mem_gen_v\d+_\d+\.v} $f]) } {
                set line "  $f \\"
                lappend compile_lines $line
              }
            } else {
              puts "DEBUG: FILE_TYPE for file $f, fileset= $synth_fileset do not match Verilog or SystemVerilog"
            }
          }
          set line "\n"
          lappend compile_lines $line
        }
#      } else {
#        puts "INFO: Library $lib has already been compiled. Skipping it."
#      }
    }

    ## Bookkeeping on which libraries are already compiled
    foreach lib $lib_file_order {
      regsub ":.*" $lib {} lib
      set compiled_lib_list($lib) 1
    }

    ## Set black-boxes for blk_mem_gen and fifo_gen if they are sub-cores
    foreach subcore $lib_file_order {
      if {![info exists black_box_libs($subcore)]} {
        if {[regexp {^blk_mem_gen_v\d+_\d+} $subcore]} {
         # set line "netlist blackbox ${subcore}_synth"
          lappend black_box_lines $line
          set black_box_libs($subcore) 1
        }
      }
    }

    ## Delete all information related to this IP 
    set lib_file_order []
    array unset lib_file_array *
    array unset lib_file_lang  *
  }

  if {$num_files == 0} {
    puts stderr "ERROR: Could not find any files in synthesis fileset"
    set rc 7
    return $rc
  }

  puts $qautocheck_compile_tcl_fh "\n#"
  puts $qautocheck_compile_tcl_fh "# Create work library"
  puts $qautocheck_compile_tcl_fh "#"
  puts $qautocheck_compile_tcl_fh "vlib $top_lib_dir"
  puts $qautocheck_compile_tcl_fh "vlib $top_lib_dir/xil_defaultlib"
  foreach key [array names compiled_lib_list] {
    puts $qautocheck_compile_tcl_fh "vlib $top_lib_dir/$key"
  }

  puts $qautocheck_compile_tcl_fh "\n#"
  puts $qautocheck_compile_tcl_fh "# Map libraries"
  puts $qautocheck_compile_tcl_fh "#"
  puts $qautocheck_compile_tcl_fh "vmap work $top_lib_dir/xil_defaultlib"
  foreach key [array names compiled_lib_list] {
    puts $qautocheck_compile_tcl_fh "vmap $key $top_lib_dir/$key"
  }

  puts $qautocheck_compile_tcl_fh "\n#"
  puts $qautocheck_compile_tcl_fh "# Compile files section"
  puts $qautocheck_compile_tcl_fh "#"


  set first_pack "1"
  foreach l $compile_lines {
    if {[regexp {\_pack\.vhd} $l all value] } {
	if {$first_pack == "1"} {
                 puts $qautocheck_compile_tcl_fh "\n$vcom_line\n $l"
                 set first_pack "0"
        } else {
                 puts $qautocheck_compile_tcl_fh "$l"
                 set first_pack "0"

        }
    }
    if {[regexp {allowProtectedBeforeBody} $l all value] } {
        set vcom_line $l
        set first_pack "1"
    }



  }


  puts $qautocheck_compile_tcl_fh "\n"




  foreach l $compile_lines {
    puts $qautocheck_compile_tcl_fh $l
  }

  puts $qautocheck_compile_tcl_fh "\n#"
  puts $qautocheck_compile_tcl_fh "# Add global set/reset"
  puts $qautocheck_compile_tcl_fh "#"
  puts $qautocheck_compile_tcl_fh "vlog  -suppress 13389  $verilog_define_options -work xil_defaultlib $vivado_dir/data/verilog/src/glbl.v"

  close $qautocheck_compile_tcl_fh

  ## Print compile information
  puts $qautocheck_ctrl_fh "netlist fpga -vendor xilinx -version $vivado_version -library vivado"

  if {$black_box_lines != ""} {
    puts $qautocheck_ctrl_fh "\n#"
    puts $qautocheck_ctrl_fh "# Black box blk_mem_gen"
    puts $qautocheck_ctrl_fh "#"
    foreach l $black_box_lines {
      puts $qautocheck_ctrl_fh $l
    }
  }
  close $qautocheck_ctrl_fh

  ## Get the library names and append a '-L' to the library name
  array set qft_libs {}
  foreach lib [array names compiled_lib_list] {
    set qft_libs($lib) 1
  }
  set lib_args ""
  foreach lib [array names qft_libs] {
    set lib_args [concat $lib_args -L $lib]
  }

  ## Dump the run Makefile
  puts $qautocheck_run_makefile_fh "DUT=$top_module"
  puts $qautocheck_run_makefile_fh "TIMEOUT=$autocheck_verify_timeout"
  puts $qautocheck_run_makefile_fh ""
  puts $qautocheck_run_makefile_fh "clean:"
  puts $qautocheck_run_makefile_fh "\trm -rf $top_lib_dir $autocheck_out_dir"
  puts $qautocheck_run_makefile_fh ""
  puts $qautocheck_run_makefile_fh "autocheck_compile:"
  puts $qautocheck_run_makefile_fh "\t\$(QHOME)/bin/qverify -c -licq -l qautocheck_${top_module}.log -od $autocheck_out_dir -do \"\\"
  puts $qautocheck_run_makefile_fh "\tonerror {exit 1}; \\"
  set autocheck_constraints_do ""
  if {$autocheck_constraints != ""} {
    set autocheck_constraints_do "do $autocheck_constraints;"
  }
  puts $qautocheck_run_makefile_fh "\t$autocheck_constraints_do; \\"
  puts $qautocheck_run_makefile_fh "\tdo $qautocheck_ctrl; \\"
  puts $qautocheck_run_makefile_fh "\tdo $qautocheck_compile_tcl; \\"
  ## Get the constraints file
  if { $use_existing_xdc == 1 } {
    puts "INFO : Using existing XDC files."
    set constr_fileset [current_fileset -constrset]
    set files [get_files -all -of [get_filesets $constr_fileset] *]
    foreach file $files {
      set ft [get_property FILE_TYPE [lindex [get_files -all -of [get_filesets $constr_fileset] $file] 0]]
      if { [string match $ft "VHDL 2008"] }  {
           set ft "VHDL"
           set vhdl_std "-2008"
      }
      if { $ft == "XDC" } {
        puts $qautocheck_run_makefile_fh "\tnetlist create -d $top_module $lib_args -tool autocheck; \\"
        puts $qautocheck_run_makefile_fh "\tsdc load $file; \\"
      }
    }
  } elseif { $generate_sdc == 1 } {
    set sdc_out_file "${top_module}_syn.sdc"
    puts "INFO : Running write_xdc command to generate the XDC file of the synthesized design"
    puts "     : Executing write_xdc -exclude_physical -sdc $userOD/$sdc_out_file -force"
    if { [catch {write_xdc -exclude_physical -sdc $userOD/$sdc_out_file -force} result] } {
      puts "** ERROR : Can't generate SDC file for the design."
      puts "         : Please run the synthesis step, or open the synthesized design then re-run the script."
      puts "         : You can use '-use_existing_xdc' option with the script to ignore generating the SDC file and use the input XDC files."
      set rc 8
      return $rc
    } else {
      puts $qautocheck_run_makefile_fh "\tnetlist create -d $top_module $lib_args -tool autocheck; \\"
      puts $qautocheck_run_makefile_fh "\tsdc load $sdc_out_file; \\"
    }
  }
  puts $qautocheck_run_makefile_fh "\tautocheck disable -type ARITH*; \\"
  puts $qautocheck_run_makefile_fh "\tautocheck compile -d \$(DUT) $lib_args; \\"
  puts $qautocheck_run_makefile_fh "\texit 0\""

  ## Dump commands for the verify run in the run Makefile
  puts $qautocheck_run_makefile_fh ""
  puts $qautocheck_run_makefile_fh "autocheck_verify:"
  puts $qautocheck_run_makefile_fh "\t\$(QHOME)/bin/qverify -c -licq -od $autocheck_out_dir -do \"\\"
  puts $qautocheck_run_makefile_fh "\tonerror {exit 1}; \\"
  puts $qautocheck_run_makefile_fh "\tautocheck load db $autocheck_out_dir/autocheck_compile.db; \\"
  puts $qautocheck_run_makefile_fh "\tautocheck verify -j 4 -rtl_init_values -timeout \$(TIMEOUT); \\"
  puts $qautocheck_run_makefile_fh "\texit 0\""

  close $qautocheck_run_makefile_fh
  puts $qautocheck_run_batfile_fh "@ECHO OFF"
  puts $qautocheck_run_batfile_fh ""
  puts $qautocheck_run_batfile_fh "SET DUT=$top_module"
  puts $qautocheck_run_batfile_fh "SET TIMEOUT=$autocheck_verify_timeout"
  puts $qautocheck_run_batfile_fh ""
  puts $qautocheck_run_batfile_fh "IF \[%1\]==\[\] goto :usage"
  puts $qautocheck_run_batfile_fh "IF %1==clean ("
  puts $qautocheck_run_batfile_fh "    call :clean"
  puts $qautocheck_run_batfile_fh ") ELSE IF %1==compile ("
  puts $qautocheck_run_batfile_fh "    call :compile"
  puts $qautocheck_run_batfile_fh ") ELSE IF %1==autocheck ("
  puts $qautocheck_run_batfile_fh "    call :autocheck"
  puts $qautocheck_run_batfile_fh ") ELSE IF %1==debug_autocheck ("
  puts $qautocheck_run_batfile_fh "    call :debug_autocheck"
  puts $qautocheck_run_batfile_fh ") ELSE IF %1==all ("
  puts $qautocheck_run_batfile_fh "    call :clean"
  puts $qautocheck_run_batfile_fh "    call :compile"
  puts $qautocheck_run_batfile_fh "    call :autocheck"
  puts $qautocheck_run_batfile_fh "    call :debug_autocheck"
  puts $qautocheck_run_batfile_fh ") ELSE ("
  puts $qautocheck_run_batfile_fh "    call :usage"
  puts $qautocheck_run_batfile_fh ")"
  puts $qautocheck_run_batfile_fh "exit /b"
  puts $qautocheck_run_batfile_fh ""
  puts $qautocheck_run_batfile_fh ":clean"
  puts $qautocheck_run_batfile_fh "\tIF EXIST $top_lib_dir RMDIR /S /Q $top_lib_dir"
  puts $qautocheck_run_batfile_fh "\tIF EXIST $autocheck_out_dir RMDIR /S /Q $autocheck_out_dir"
  puts $qautocheck_run_batfile_fh "\texit /b"
  puts $qautocheck_run_batfile_fh ""
  puts $qautocheck_run_batfile_fh ":compile"

  puts $qautocheck_run_batfile_fh "\tqverify -c -licq -l qautocheck_${top_module}.log -od $autocheck_out_dir -do ^\"$autocheck_constraints_do do $qautocheck_ctrl;do $qautocheck_compile_tcl;do $run_sdcfile^\""


  ## Get the constraints file
  if { $use_existing_xdc == 1 } {
    puts "INFO : Using existing XDC files."
    set constr_fileset [current_fileset -constrset]
    set files [get_files -all -of [get_filesets $constr_fileset] *]
    foreach file $files {
      set ft [get_property FILE_TYPE [lindex [get_files -all -of [get_filesets $constr_fileset] $file] 0]]
      if { [string match $ft "VHDL 2008"] }  {
           set ft "VHDL"
           set vhdl_std "-2008"
      }
      if { $ft == "XDC" } {
        puts $qautocheck_run_sdcfile_fh "netlist create -d $top_module $lib_args -tool autocheck"
        puts $qautocheck_run_sdcfile_fh "sdc load $file"
      }
    }
  } elseif { $generate_sdc == 1 } {
    set sdc_out_file "${top_module}_syn.sdc"
    puts "INFO : Running write_xdc command to generate the XDC file of the synthesized design"
    puts "     : Executing write_xdc -exclude_physical -sdc $userOD/$sdc_out_file -force"
    if { [catch {write_xdc -exclude_physical -sdc $userOD/$sdc_out_file -force} result] } {
      puts "** ERROR : Can't generate SDC file for the design."
      puts "         : Please run the synthesis step, or open the synthesized design then re-run the script."
      puts "         : You can use '-use_existing_xdc' option with the script to ignore generating the SDC file and use the input XDC files."
      set rc 8
      return $rc
    } else {
      puts $qautocheck_run_sdcfile_fh "netlist create -d $top_module $lib_args -tool autocheck"
      puts $qautocheck_run_sdcfile_fh "sdc load $sdc_out_file;"
    }
  }
  puts $qautocheck_run_batfile_fh "\texit /b"
  puts $qautocheck_run_batfile_fh ""

  puts $qautocheck_run_batfile_fh ":autocheck"
  puts $qautocheck_run_batfile_fh "\tqverify -c -licq -l qautocheck_${top_module}.log -od $autocheck_out_dir -do ^\"$autocheck_constraints_do do $qautocheck_ctrl; autocheck compile -d %DUT% $lib_args;autocheck verify -j 4 -rtl_init_values -timeout %TIMEOUT%;  ^\""
  puts $qautocheck_run_batfile_fh "\texit /b"
  puts $qautocheck_run_batfile_fh ""
  puts $qautocheck_run_batfile_fh ":debug_autocheck"
  puts $qautocheck_run_batfile_fh "\tqverify  $autocheck_out_dir\/autocheck\.db "
  puts $qautocheck_run_batfile_fh "\texit /b"
  puts $qautocheck_run_batfile_fh ""
  puts $qautocheck_run_batfile_fh ":usage"
  puts $qautocheck_run_batfile_fh "\tECHO \#\#\# run_qac clean \.\.\.\.\.\.\.\.\.\.\.\. Clean all results from directory"
  puts $qautocheck_run_batfile_fh "\tECHO \#\#\# run_qac compile \.\.\.\.\.\.\.\.\.\. Compile source code"
  puts $qautocheck_run_batfile_fh "\tECHO \#\#\# run_qac autocheck \.\.\.\.\.\.\.\. Run autocheck"
  puts $qautocheck_run_batfile_fh "\tECHO \#\#\# run_qac debug_autocheck \.\. Debug autocheck Run"
  puts $qautocheck_run_batfile_fh "\tECHO \#\#\# run_qac all \.\.\.\.\.\.\.\.\.\.\.\.\.\. Run all autocheck Steps on Souce Code and Launch Debug"
  puts $qautocheck_run_batfile_fh "\texit /b"


  close $qautocheck_run_batfile_fh
  ## Dump the run file
  puts $qautocheck_run_fh "#! /bin/sh"
  puts $qautocheck_run_fh ""
  puts $qautocheck_run_fh "rm -rf $top_lib_dir $autocheck_out_dir"
  puts $qautocheck_run_fh "qverify -c -licq -l qautocheck_${top_module}.log -od $autocheck_out_dir -do \"$autocheck_constraints_do; do $qautocheck_ctrl;  do $qautocheck_compile_tcl;  do $run_sdcfile;autocheck disable -type ARITH*;autocheck compile -d ${top_module} $lib_args;autocheck verify -j 4 -rtl_init_values -timeout ${autocheck_verify_timeout};    \""
  close $qautocheck_run_fh


  puts "INFO : Generation of running scripts for Questa AutoCheck is done at [pwd]/$userOD"

  if { $run_questa_autocheck == "autocheck_compile" } {
    puts "INFO : Running Questa AutoCheck (Command: autocheck compile), the UI will be invoked when the run is finished"
    puts "     : Log can be found at $userOD/AUTOCHECK_RESULTS/qverify.log"
    set OS [lindex $::tcl_platform(os) 0]
    if { $OS == "Linux" } {
      exec /bin/sh -c "cd $userOD; make autocheck_compile -f $run_makefile"
    }
    puts "INFO : Questa AutoCheck run is finished"
    puts "INFO : Invoking Questa AutoCheck UI for debugging."
    exec qverify $userOD/AUTOCHECK_RESULTS/autocheck.db &
  } elseif { $run_questa_autocheck == "autocheck_verify" } {
    puts "INFO : Running Questa AutoCheck (Command: autocheck verify), the UI will be invoked when the run is finished"
    puts "     : Log can be found at $userOD/AUTOCHECK_RESULTS/qverify.log"
    set OS [lindex $::tcl_platform(os) 0]
    if { $OS == "Linux" } {
      exec /bin/sh -c "cd $userOD; make autocheck_compile autocheck_verify -f $run_makefile"
    }
    puts "INFO : Questa AutoCheck run is finished"
    puts "INFO : Invoking Questa AutoCheck UI for debugging."
    set OS [lindex $::tcl_platform(os) 0]
    if { $OS == "Linux" } {
      exec /bin/sh -c "cd $userOD; qverify -l qverify_ui.log AUTOCHECK_RESULTS/autocheck.db" &
    }
  }
  return $rc
}

## Keep an environment variable with the path of the script
set env(QUESTA_AUTOCHECK_TCL_SCRIPT_PATH) [file normalize [file dirname [info script]]]

## Auto-import the procs of the Questa AutoCheck script
namespace import tclapp::mentor::questa_cdc::*
