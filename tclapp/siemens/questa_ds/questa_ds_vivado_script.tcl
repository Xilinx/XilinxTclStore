namespace eval ::tclapp::siemens::questa_ds {
  # Export procs that should be allowed to import into other namespaces
  
  namespace export write_questa_cdc_script
  namespace export write_questa_rdc_script
  namespace export write_questa_lint_script
  namespace export write_questa_autocheck_script
}

proc ::tclapp::siemens::questa_ds::matches_default_libs {lib} {
  
  # Summary: internally used routine to check if default libs used
  
  # Argument Usage:
  # lib: name of lib to check if default lib

  # Return Value:
  # 1 is returned when the passed library matches on of the names of the default libraries

  # Categories: xilinxtclstore, siemens, questa_cdc

  regsub ":.*" $lib {} lib
  if {[string match -nocase $lib "xil_defaultlib"]} {
    return 1
  } elseif {[string match -nocase $lib "work"]} {
    return 1
  } else {
    return 0
  }
}
proc ::tclapp::siemens::questa_ds::uniquify_lib {lib lang num} {
  
  # Summary: internally used routine to uniquify libs
  
  # Argument Usage:
  # lib  : lib name to uniquify
  # lang : HDL language
  # num  : uniquified lib name

  # Return Value:
  # The name of the uniquified library is returned 

  # Categories: xilinxtclstore, siemens, questa_cdc


  set new_lib ""
  if {[matches_default_libs $lib]} {
    set new_lib [concat $lib:$lang:$num]
  } else {
    set new_lib [concat $lib:$lang]
  }
  return $new_lib
}
proc ::tclapp::siemens::questa_ds::populate_siemens_publickeys {siemens_public_key_table} {
  set public_keys { "MGC-DVT-MTI" "MGC-VELOCE-RSA" "MGC-VERIF-SIM-RSA-1" "MGC-VERIF-SIM-RSA-2" "MGC-VERIF-SIM-RSA-3" "SIEMENS-VERIF-SIM-RSA-1" "SIEMENS-VERIF-SIM-RSA-2"  }
     foreach pkey $public_keys {
       dict incr siemens_public_key_table $pkey
     }
     return $siemens_public_key_table
}
proc ::tclapp::siemens::questa_ds::populate_rtl_keywords {rtl_keyword_table} {

     set vl_keywords {accept_on alias always always_comb always_ff always_latch and assert assign assume automatic before begin bind bins binsof bit break buf bufif0 bufif1 byte case casex casez cell chandle checker class clocking cmos config const constraint context continue cover covergroup coverpoint cross deassign default defparam design disable dist do edge else end endcase endchecker endclass endclocking endconfig endfunction endgenerate endgroup endinterface endmodule endpackage endprimitive endprogram endproperty endspecify endsequence endtable endtask enum event eventually expect export extends extern final first_match for force foreach forever fork forkjoin function generate genvar global highz0 highz1 if iff ifnone ignore_bins illegal_bins implies import incdir include initial inout input inside instance int integer interface intersect join join_any join_none large let liblist library local localparam logic longint macromodule matches medium modport module nand negedge new nexttime nmos nor noshowcancelled not notif0 notif1 null or output package packed parameter pmos posedge primitive priority program property protected pull0 pull1 pulldown pullup pulsestyle_ondetect pulsestyle_onevent pure rand randc randcase randsequence rcmos real realtime ref reg reject_on release repeat restrict return rnmos rpmos rtran rtranif0 rtranif1 s_always s_eventually s_nexttime s_until s_until_with scalared sequence shortint shortreal showcancelled signed small solve specify specparam static string strong strong0 strong1 struct super supply0 supply1 sync_accept_on sync_reject_on table tagged task this throughout time timeprecision timescale timeunit tran tranif0 tranif1 tri tri0 tri1 triand trior trireg type typedef union unique unique0 unsigned until until_with untyped use uwire var vectored virtual void wait wait_order wand weak weak0 weak1 while wildcard wire with within wor xnor xor}
   
   set vhdl_keywords {accept_on alias always always_comb abs access after all and architecture array assert attribute begin block body buffer bus case component configuration constant disconnect downto else elsif end entity exit file for function generate generic guarded if in inout is label library linkage loop map mod nand new next nor not null of on open or others out package port procedure process range record register rem report return select severity signal subtype then to transport type units until use variable wait when while with xnor xor std_logic std_ulogic std_logic_vector bit bit_vector boolean character conv_std_logic_vector conv_integer conv_unsigned conv_signed integer string signed to_integer to_stdlogicvector unsigned}
   
  set vl_directives {`_FILE_ `_LINE_ `begin_keywords `celldefine `default_nettype `define `else `elsif `end_keywords `endcelldefine `endif `endprotect `endprotected  `ifdef `ifndef `include `line `nounconnected_drive `pragma `protect `protected `resetall `timescale `unconnected_drive `undef `undefineall}


     foreach keyword $vl_keywords {
       dict incr rtl_keyword_table $keyword
     }
     foreach keyword $vhdl_keywords {
       dict incr rtl_keyword_table $keyword
     }
     foreach keyword $vl_directives {
       dict incr rtl_keyword_table $keyword
     }
     return $rtl_keyword_table
}
proc ::tclapp::siemens::questa_ds::is_sv_vhdl_keyword {rtl_keyword_table word} {

 set word  [string tolower $word]
 return [dict exists $rtl_keyword_table $word] 
}
proc ::tclapp::siemens::questa_ds::set_hier_ips {tool userOD} {
    
  set hier_ip_blocks "q${tool}_hier_ip_blocks.tcl"
  if { [catch {open $userOD/$hier_ip_blocks w} result] } {
    puts stderr "ERROR: Could not open $hier_ip_blocks for writing\n$result"
    set rc 2
    return $rc
  } else {
    set hier_ip_blocks_fh $result
    puts "INFO: Writing to set Xilinx IPs as \"hier ip\"  to file $userOD/$hier_ip_blocks"
  }
  set ips [get_ips *]
  foreach ip $ips {
    puts $hier_ip_blocks_fh "hier ip $ip"
  }
  close $hier_ip_blocks_fh

}
proc ::tclapp::siemens::questa_ds::get_vivado_version {} {
   
  set current_version [lindex [version] 1]
  regsub {v} $current_version {} current_version
  set major [lindex [split $current_version .] 0]
  set minor [lindex [split $current_version .] 1]
  set final_vivado_version "$major\.$minor"
  return $final_vivado_version
}

proc ::tclapp::siemens::questa_ds::remove_vivado_GUI_button {tool rc} {

    set vivado_version [get_vivado_version] 
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

    ## does removing questa_cdc cause ambiguoty ??
    set command_found 0
    set command_found_flag 0
    set position 0
    set run_command "Run_Questa_$tool"
    for {set i 0} {$i < [llength $ip_lines]} {incr i} {
      if { $command_found_flag == 0 } {

        if { [regexp {\s\s\<custom_command\>} [lindex $ip_lines $i]]  && [regexp "\\s\\s\\s<name>$run_command</name>" [lindex $ip_lines [expr $i + 2]]] } {
          regexp {<position>([0-9]+)\</position\>} [lindex $ip_lines [expr $i + 1]] m1 m2
          set position $m2
          set command_found 1
          set command_found_flag 1
          continue
        }
      } else {
        if { ! [regexp {\s\s\</custom_command\>} [lindex $ip_lines $i]] } {
          continue
        } else {
          set command_found_flag 0
          continue
        }
      }
      
      if {$command_found_flag == 0 && $command_found == 1 && [regexp {<position>([0-9]+)\</position\>} [lindex $ip_lines $i]]} {
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
    if { $OS == "Linux" } {
       exec rm -rf $commands_file
    } else {
       file delete -force $commands_file
    }
    file rename ${commands_file}.tmp $commands_file
    if { $command_found == 1 } {
      puts "INFO: Vivado GUI button for running Questa $tool is removed from $commands_file"
    } else {
      puts "INFO: Vivado GUI button for running Questa $tool wasn't found in $commands_file."
      puts "    : File has not been changed."
    }
  } else {
    puts "INFO: File $::env(HOME)/.Xilinx/Vivado/$vivado_version/commands/commands.xml not exist, cannot remove from unexisting file"
  }

 return $rc
}

proc ::tclapp::siemens::questa_ds::add_vivado_CDC_RDC_GUI_button {rc tool} {
 ## Example for code of the Vivado GUI button
    ## -----------------------------------------
    ## 0=Run%20Questa%20RDC tclapp::siemens::questa_rdc::write_questa_rdc_script "" /home/iahmed/questa_rdc_logo.PNG "" "" true ^@ "" true 4 Top%20Module "" "" false Output%20Directory "" -output_directory%20OD1 true Use%20Existing%20XDC "" -use_existing_xdc true Invoke%20Questa%20RDC%20Run "" -run true
    ## -----------------------------------------
   ##Set the QHOME path
    set QHOME [exec qverify -install_path]
    set vivado_version [get_vivado_version]
    set tool_lowercase [string tolower $tool]
    set OS [lindex $::tcl_platform(os) 0]
    if { $OS == "Linux" } {
      set commands_file "$::env(HOME)/.Xilinx/Vivado/$vivado_version/commands/commands.xml"
    } else {
      set commands_file "$::env(HOME)\\AppData\\Roaming\\Xilinx\\Vivado\\$vivado_version\\commands\\commands.xml"
    }
    
    set tool_logo "questa_${tool_lowercase}_logo.PNG"
    set questa_tool_logo "$::env(QUESTA_${tool}_TCL_SCRIPT_PATH)/$tool_logo"
    if { ! [file exists $questa_tool_logo] } {
      set questa_tool_logo "\"$questa_tool_logo\""
      puts "INFO: Can't find the Questa $tool logo at $questa_tool_logo"
      if { [file exists "$QHOME/share/fpga_libs/Xilinx/$tool_logo.PNG"] } {
        set questa_tool_logo "$QHOME/share/fpga_libs/Xilinx/$tool_logo.PNG"
        puts "INFO: Found the Questa $tool logo at $questa_tool_logo"
      }
    }
  
    if { [catch {open $commands_file a} result] } {
      puts stderr "ERROR: Could not open commands.xml to add the Questa $tool button, path '$commands_file'\n$result"
      set rc 9
      return $rc
    } else {
      set commands_fh $result
      puts "INFO: Adding Vivado GUI button for running Questa $tool in $commands_file"
    }
    set questa_tool_command_index 0
    set vivado_cmds_version "1.0"
    set encoding_cmds_version "UTF-8"
    set major_cmds_version "1"
    set minor_cmds_version "0"
    set name_cmds_version "USER"
    if { [file size $commands_file] } {
      set file1 [open $commands_file r]
      set file2 [read $file1]
      set commands_file_line [split $file2 "\n"]
      set last_command [lindex $commands_file_line end-2]
      
      foreach line $commands_file_line {
        if {$tool eq "CDC"} {
          if {[regexp {write_questa_cdc_script} $line]} {
            puts "INFO : Vivado GUI button for running Questa $tool is already installed in $commands_file. Exiting ..."
            close $commands_fh
            close $file1
            return $rc
          }
        } else {
          if {[regexp {write_questa_rdc_script} $line]} {
            puts "INFO : Vivado GUI button for running Questa $tool is already installed in $commands_file. Exiting ..."
            close $commands_fh
            close $file1
            return $rc

          }
        }
      }  
      
      if { $last_command == "<custom_commands major=\"$major_cmds_version\" minor=\"$minor_cmds_version\">"} {
        set questa_tool_command_index 0
 
      } else {
        set numbers 0
        foreach line $commands_file_line {
	  if {[regexp {<position>([0-9]+)} $line m1 m2]} {
	    set numbers $m2
	  }
	}
	set last_command_index $numbers
        set questa_tool_command_index [incr last_command_index]
 
      }
	close $file1
    } else {
      puts $commands_fh "<?xml version=\"$vivado_cmds_version\" encoding=\"$encoding_cmds_version\"?>"
      puts $commands_fh "<custom_commands major=\"$major_cmds_version\" minor=\"$minor_cmds_version\">"
      set questa_tool_command_index 0
    }

    puts $commands_fh "  <custom_command>"
    puts $commands_fh "    <position>$questa_tool_command_index</position>"
    puts $commands_fh "    <name>Run_Questa_$tool</name>"
    if {$tool eq "CDC"} {
      puts $commands_fh {  <menu_name><![CDATA[ Run Questa CDC Usage: write_questa_cdc_script &lt; top_module &gt;[-output_directory &lt;out_dir&gt;] [-use_existing_xdc|-generate_sdc] [-cdc_constraints &lt;constraints_file&gt;] [-methodology &lt;SoC|FPGA|IP&gt;] [-goal &lt;start|planning|implementation|release|custom_goal&gt;] [-run &lt;cdc_setup|cdc_run&gt;] [-library_version &lt;lib_version&gt;] [-fpga_libs &lt;fpga_installation_directory&gt;] [-add_button] [-remove_button]]]></menu_name>} 
    } else {
      puts $commands_fh {  <menu_name><![CDATA[ Run Questa RDC Usage: write_questa_rdc_script &lt; top_module &gt;[-output_directory &lt;out_dir&gt;] [-use_existing_xdc|-generate_sdc] [-rdc_constraints &lt;constraints_file&gt;] [-methodology &lt;SoC|FPGA|IP&gt;] [-goal &lt;start|planning|implementation|release|custom_goal&gt;] [-run &lt;report_reset|rdc_run&gt;] [-library_version &lt;lib_version&gt;] [-fpga_libs &lt;fpga_installation_directory&gt;] [-add_button] [-remove_button]]]></menu_name>} 

    }
    puts $commands_fh "    <command>source $QHOME/share/fpga_libs/Xilinx/questa_ds_vivado_script.tcl; tclapp::siemens::questa_ds::write_questa_${tool_lowercase}_script</command>"
    puts $commands_fh "    <toolbar_icon>$questa_tool_logo</toolbar_icon>"
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
    puts $commands_fh "        <default>-output_directory Questa_${tool}</default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>Use_Existing_XDC</name>"
    puts $commands_fh "        <default>-use_existing_xdc</default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>Generate_SDC</name>"
    puts $commands_fh "        <default></default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>${tool}_constraints</name>"
    puts $commands_fh "        <default></default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>Methodology</name>"
    puts $commands_fh "        <default></default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>Goal</name>"
    puts $commands_fh "        <default></default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>Vivado_Library_Version</name>"
    puts $commands_fh "        <default>-library_version $vivado_version</default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>Fpga_Installation_Directory</name>"
    puts $commands_fh "        <default></default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>Invoke_Questa_${tool}_Run</name>"
    puts $commands_fh "        <default>-run ${tool_lowercase}_run</default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "    </args>"
    puts $commands_fh "  </custom_command>"
    puts $commands_fh "</custom_commands>"
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
proc ::tclapp::siemens::questa_ds::add_vivado_LINT_GUI_button {rc} {
 ## Example for code of the Vivado GUI button
    ## -----------------------------------------
    ## 0=Run%20Questa%20Lint tclapp::siemens::questa_lint::write_questa_lint_script "" /home/iahmed/questa_lint_logo.PNG "" "" true ^@ "" true 4 Top%20Module "" "" false Output%20Directory "" -output_directory%20OD1 true Use%20Existing%20XDC "" -use_existing_xdc true Invoke%20Questa%20Lint%20Run "" -run true
    ## -----------------------------------------
   ##Set the QHOME path
    set QHOME [exec qverify -install_path]
    set vivado_version [get_vivado_version]
    set OS [lindex $::tcl_platform(os) 0]
    if { $OS == "Linux" } {
      set commands_file "$::env(HOME)/.Xilinx/Vivado/$vivado_version/commands/commands.xml"
    } else {
      set commands_file "$::env(HOME)\\AppData\\Roaming\\Xilinx\\Vivado\\$vivado_version\\commands\\commands.xml"
    }
    
    set questa_lint_logo "$::env(QUESTA_LINT_TCL_SCRIPT_PATH)/questa_lint_logo.PNG"
    if { ! [file exists $questa_lint_logo] } {
      set questa_lint_logo "\"$questa_lint_logo\""
      puts "INFO: Can't find the Questa Lint logo at $questa_lint_logo"
      if { [file exists "$QHOME/share/fpga_libs/Xilinx/questa_lint_logo.PNG"] } {
        set questa_lint_logo "$QHOME/share/fpga_libs/Xilinx/questa_lint_logo.PNG"
        puts "INFO: Found the Questa Lint logo at $questa_lint_logo"
      }
    }
    
    if { [catch {open $commands_file a} result] } {
      puts stderr "ERROR: Could not open commands.xml to add the Questa Lint button, path '$commands_file'\n$result"
      set rc 9
      return $rc
    } else {
      set commands_fh $result
      puts "INFO: Adding Vivado GUI button for running Questa Lint in $commands_file"
    }
    set questa_lint_command_index 0
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
        if {[regexp {write_questa_lint_script} $line]} {
          puts "INFO : Vivado GUI button for running Questa Lint is already installed in $commands_file. Exiting ..."
            close $commands_fh
            close $file1
            return $rc
        }
      }

      if { $last_command == "<custom_commands major=\"$major_cmds_version\" minor=\"$minor_cmds_version\">"} {
        set questa_lint_command_index 0
 
      } else {
        set numbers 0
        foreach line $commands_file_line {
          if {[regexp {<position>([0-9]+)} $line m1 m2]} {
            set numbers $m2
          }
        }
        set last_command_index $numbers
        set questa_lint_command_index [incr last_command_index]

      }
      close $file1
    } else {
      puts $commands_fh "<?xml version=\"$vivado_cmds_version\" encoding=\"$encoding_cmds_version\"?>"
      puts $commands_fh "<custom_commands major=\"$major_cmds_version\" minor=\"$minor_cmds_version\">"
      set questa_lint_command_index 0
    }
    puts $commands_fh "  <custom_command>"
    puts $commands_fh "    <position>$questa_lint_command_index</position>"
    puts $commands_fh "    <name>Run_Questa_Lint</name>"
    puts $commands_fh {  <menu_name><![CDATA[ Run Questa Lint Usage: write_questa_lint_script &lt; top_module &gt;[-output_directory &lt;out_dir&gt;] [-lint_constraints &lt;constraints_file&gt;] [-methodology &lt;SoC|FPGA|IP&gt;] [-goal &lt;start|planning|implementation|release|custom_goal&gt;] [-run &lt;lint_run&gt;] [-library_version &lt;lib_version&gt;] [-fpga_libs &lt;fpga_installation_directory&gt;] [-add_button] [-remove_button]]]></menu_name>}
    puts $commands_fh "    <command>source $QHOME/share/fpga_libs/Xilinx/questa_ds_vivado_script.tcl; tclapp::siemens::questa_ds::write_questa_lint_script</command>"
    puts $commands_fh "    <toolbar_icon>$questa_lint_logo</toolbar_icon>"
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
    puts $commands_fh "        <default>-output_directory Questa_Lint</default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>Lint_Constraints</name>"
    puts $commands_fh "        <default></default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>Methodology</name>"
    puts $commands_fh "        <default>-methodology FPGA</default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>Goal</name>"
    puts $commands_fh "        <default>-goal start</default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>Vivado_Library_Version</name>"
    puts $commands_fh "        <default>-library_version $vivado_version</default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>" 
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>Fpga_Installation_Directory</name>"
    puts $commands_fh "        <default></default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>" 
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>Invoke_Questa_Lint_Run</name>"
    puts $commands_fh "        <default>-run lint_run</default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "    </args>"
    puts $commands_fh "  </custom_command>"
    puts $commands_fh "</custom_commands>"
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

proc ::tclapp::siemens::questa_ds::add_vivado_AUTOCHECK_GUI_button {rc} {
 
 
 
    ## Example for code of the Vivado GUI button
    ## -----------------------------------------
    ## 0=Run%20Questa%20AutoCheck tclapp::siemens::questa_autocheck::write_questa_autocheck_script "" /home/iahmed/questa_autocheck_logo.PNG "" "" true ^@ "" true 4 Top%20Module "" "" false Output%20Directory "" -output_directory%20OD1 true Use%20Existing%20XDC "" -use_existing_xdc true Invoke%20Questa%20AutoCheck%20Run "" -run true
    ## -----------------------------------------

   ##Set the QHOME path
   set QHOME [exec qverify -install_path]
   set vivado_version [get_vivado_version]
    set OS [lindex $::tcl_platform(os) 0]
    if { $OS == "Linux" } {
      set commands_file "$::env(HOME)/.Xilinx/Vivado/$vivado_version/commands/commands.xml"
    } else {
      set commands_file "$::env(HOME)\\AppData\\Roaming\\Xilinx\\Vivado\\$vivado_version\\commands\\commands.xml"
    }
    set questa_autocheck_logo "$::env(QUESTA_AUTOCHECK_TCL_SCRIPT_PATH)/questa_autocheck_logo.PNG"
    if { ! [file exists $questa_autocheck_logo] } {
      set questa_autocheck_logo "\"$questa_autocheck_logo\""
      puts "INFO: Can't find the Questa AutoCheck logo at $questa_autocheck_logo"
      if { [file exists "$QHOME/share/fpga_libs/Xilinx/questa_autocheck_logo.PNG"] } {
        set questa_autocheck_logo "$QHOME/share/fpga_libs/Xilinx/questa_autocheck_logo.PNG"
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
    puts $commands_fh {  <menu_name><![CDATA[ Run Questa AutoCheck Usage: write_questa_autocheck_script &lt; top_module &gt;[-output_directory &lt;out_dir&gt;] [-use_existing_xdc|-generate_sdc] [-autocheck_constraints &lt;constraints_file&gt;] [-run &lt;autocheck_compile|autocheck_verify&gt;] [-verify_timeout &lt;value&gt;] [-library_version &lt;lib_version&gt;] [-fpga_libs &lt;fpga_installation_directory&gt;] [-add_button] [-remove_button]]]></menu_name>}
    puts $commands_fh "    <command>source $QHOME/share/fpga_libs/Xilinx/questa_ds_vivado_script.tcl; tclapp::siemens::questa_ds::write_questa_autocheck_script</command>"
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
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>Generate_SDC</name>"
    puts $commands_fh "        <default></default>"
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
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>Vivado_Library_Version</name>"
    puts $commands_fh "        <default>-library_version $vivado_version</default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "      <arg>"
    puts $commands_fh "        <name>Fpga_Installation_Directory</name>"
    puts $commands_fh "        <default></default>"
    puts $commands_fh "        <optional>true</optional>"
    puts $commands_fh "      </arg>"
    puts $commands_fh "    </args>"
    puts $commands_fh "  </custom_command>"
    puts $commands_fh "</custom_commands>"
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
proc ::tclapp::siemens::questa_ds::write_compilation_files { compile_file_args tool compiled_lib_list_args compile_lines_args updated_global_incdirs_args verilog_define_options } {
  

  ## Vivado install dir
  set vivado_dir $::env(XILINX_VIVADO)
  puts "INFO: Using Vivado install directory $vivado_dir"

  upvar 1 $compile_file_args compile_file
  upvar 1 ${compiled_lib_list_args} compiled_lib_list
  upvar 1 ${compile_lines_args} compile_lines
  upvar 1 ${updated_global_incdirs_args} updated_global_incdirs

  # Settings
  set top_lib_dir "qft"
  set out_dir $tool
  append out_dir "_RESULTS"
  set modelsimini "modelsim.ini"

  
  puts $compile_file "\n#"
  puts $compile_file "# Create work library"
  puts $compile_file "#"
  puts $compile_file "vlib $top_lib_dir"
  puts $compile_file "vlib $top_lib_dir/xil_defaultlib"
  foreach key [array names compiled_lib_list] {
    puts $compile_file "vlib $top_lib_dir/$key"
  }

  puts $compile_file "\n#"
  puts $compile_file "# Map libraries"
  puts $compile_file "#"
  puts $compile_file "vmap work $top_lib_dir/xil_defaultlib"
  foreach key [array names compiled_lib_list] {
    puts $compile_file "vmap $key $top_lib_dir/$key"
  }

  puts $compile_file "\n#"
  puts $compile_file "# Compile files section \n"
  if { [string length $updated_global_incdirs] > 0 } {
    puts $compile_file "set INCDIR \"$updated_global_incdirs  \" "
  }



  puts $compile_file "#"

  set first_pack "1"
  foreach l $compile_lines {
    if {[regexp {\_pack\.vhd} $l all value] } {
      if {$first_pack == "1"} {
        puts $compile_file "\n$vcom_line\n $l"
        set first_pack "0"
      } else {
        puts $compile_file "$l"
        set first_pack "0"
      }
    }
    if {[regexp {allowProtectedBeforeBody} $l all value] } {
      set vcom_line $l
      set first_pack "1"
    }



  }
  

  puts $compile_file "\n"
  foreach l $compile_lines {
    puts $compile_file $l
  }

  puts $compile_file "\n#"
  puts $compile_file "# Add global set/reset"
  puts $compile_file "#"
  puts $compile_file "vlog  -suppress 13389  $verilog_define_options -work xil_defaultlib $vivado_dir/data/verilog/src/glbl.v"

  close $compile_file
}

proc ::tclapp::siemens::questa_ds::write_ctrl_file { ctrl_file library_version fpga_libs select_methodology methodology select_goal goal black_box_lines tool } {

  upvar 1 ${ctrl_file} ctrl_file_args
  upvar 1 ${black_box_lines} black_box_lines_args
  
  if {$tool eq "cdc" } {
    puts $ctrl_file_args "cdc  preference -internal_sync_resets_on -print_port_domain_template"
  } elseif {$tool eq "rdc"} {
    puts $ctrl_file_args "rdc preference -print_port_domain_template"
    puts $ctrl_file_args "rdc preference tree -sync_internal "
  }
  if { $fpga_libs != "" } {
   puts $ctrl_file_args "netlist fpga directory $fpga_libs"
  }
  puts $ctrl_file_args "netlist fpga -vendor xilinx -version $library_version -library vivado"
  if { $select_methodology == 1 } {
    puts -nonewline $ctrl_file_args "$tool methodology  $methodology"
      if { $select_goal == 1 } {
        puts  $ctrl_file_args " -goal $goal"
      }
  }
  if {$black_box_lines_args != ""} {
    puts $ctrl_file_args "\n#"
      puts $ctrl_file_args "# Black box blk_mem_gen"
      puts $ctrl_file_args "#"
      foreach l $black_box_lines_args {
        puts $ctrl_file_args $l
      }
  }
  close $ctrl_file_args

}

proc ::tclapp::siemens::questa_ds::write_sdc_constraints_file { output_file top_module lib_args userOD is_makefile tool } {

      upvar 1 ${output_file} output_file_args
      set indent ""
      set makefile_check ""
      if { $is_makefile == 1 } {
        set indent "\t"
        set makefile_check "; \\"
      }
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
        puts $output_file_args "${indent}sdc load $sdc_out_file${makefile_check}"
      }

}
proc ::tclapp::siemens::questa_ds::write_xdc_constraints_file { output_file top_module lib_args is_makefile tool } {

      upvar 1 ${output_file} output_file_args
      set indent ""
      set makefile_check ""
      if { $is_makefile == 1 } {
        set indent "\t"
        set makefile_check "; \\"
      }
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
          puts $output_file_args "${indent}sdc load $file${makefile_check}"
        }
      }
}

proc ::tclapp::siemens::questa_ds::write_makefile { output_file top_module lib_args top_lib_dir out_dir userOD constraints compilation_file ctrl_file use_existing_xdc generate_sdc tool autocheck_verify_timeout } {


  upvar 1 ${output_file} output_file_args
  puts $output_file_args "DUT=$top_module"
  if {$tool eq "autocheck" } {
    puts $output_file_args "TIMEOUT=$autocheck_verify_timeout"
  }
  puts $output_file_args ""
  puts $output_file_args "clean:"
  puts $output_file_args "\trm -rf $top_lib_dir $out_dir"
  puts $output_file_args ""
  if { $tool ne "autocheck" } {
    puts $output_file_args  ${tool}_run:
  } else {
    puts $output_file_args "autocheck_compile:"
  }
  puts $output_file_args "\t\$(QHOME)/bin/qverify -c -licq -l q${tool}_${top_module}.log -od $out_dir -do \"\\"
  puts $output_file_args "\tonerror {exit 1}; \\"
  puts $output_file_args "\tdo [pwd]/$userOD/$ctrl_file; \\"
  if {$constraints != ""} {
    puts $output_file_args  "\tdo $constraints; \\"
  }
  puts $output_file_args "\tdo [pwd]/$userOD/$compilation_file; \\"
  ## Get the constraints file
  if { $use_existing_xdc == 1 } {
    write_xdc_constraints_file  output_file_args $top_module $lib_args 1 $tool 
  } 
  if { $generate_sdc == 1 } {
    write_sdc_constraints_file output_file_args $top_module $lib_args $userOD 1 $tool
  }
  if { $tool ne "autocheck" } {
    puts $output_file_args "\t$tool run -d \$(DUT) $lib_args; \\"
  } else {
    puts $output_file_args "\tautocheck disable -type ARITH*; \\"
    puts $output_file_args "\tautocheck compile -d \$(DUT) $lib_args; \\"
  }
  puts $output_file_args "\texit 0\""
  
  if { $tool eq "autocheck" } {
    ## Dump commands for the verify run in the run Makefile
      puts $output_file_args ""
      puts $output_file_args "autocheck_verify:"
      puts $output_file_args "\t\$(QHOME)/bin/qverify -c -licq -od $out_dir -do \"\\"
      puts $output_file_args "\tonerror {exit 1}; \\"
      puts $output_file_args "\tautocheck load db $out_dir/autocheck_compile.db; \\"
      puts $output_file_args "\tautocheck verify -j 4 -rtl_init_values -timeout \$(TIMEOUT); \\"
      puts $output_file_args "\texit 0\""
  }
  close $output_file_args

}
proc ::tclapp::siemens::questa_ds::write_batfile { output_file top_module lib_args top_lib_dir out_dir userOD constraints compilation_file ctrl_file sdc_file tool autocheck_verify_timeout  } {

  upvar 1 ${output_file} output_file_args
  
  set do_sdc ""
  set do_constraints ""
  if {$sdc_file != ""} {
   set do_sdc "do $sdc_file"
  }
  if {$constraints != ""} {
    set do_constraints "do $constraints;"
  }
  puts $output_file_args "@ECHO OFF"
  puts $output_file_args ""
  puts $output_file_args "SET DUT=$top_module"
  if { $tool eq "autocheck" } {
    puts $output_file_args "SET TIMEOUT=$autocheck_verify_timeout"
  }
  puts $output_file_args ""
  puts $output_file_args "IF \[%1\]==\[\] goto :usage"
  puts $output_file_args "IF %1==clean ("
  puts $output_file_args "    call :clean"
  puts $output_file_args ") ELSE IF %1==compile ("
  puts $output_file_args "    call :compile"
  puts $output_file_args ") ELSE IF %1==$tool ("
  puts $output_file_args "    call :$tool"
  puts $output_file_args ") ELSE IF %1==debug_${tool} ("
  puts $output_file_args "    call :debug_${tool}"
  puts $output_file_args ") ELSE IF %1==all ("
  puts $output_file_args "    call :clean"
  puts $output_file_args "    call :compile"
  puts $output_file_args "    call :$tool"
  puts $output_file_args "    call :debug_${tool}"
  puts $output_file_args ") ELSE ("
  puts $output_file_args "    call :usage"
  puts $output_file_args ")"
  puts $output_file_args "exit /b"
  puts $output_file_args ""
  puts $output_file_args ":clean"
  puts $output_file_args "\tIF EXIST $top_lib_dir RMDIR /S /Q $top_lib_dir"
  puts $output_file_args "\tIF EXIST $out_dir RMDIR /S /Q $out_dir"
  puts $output_file_args "\texit /b"
  puts $output_file_args ""
  puts $output_file_args ":compile"
  puts $output_file_args "\tqverify -c -licq -l q${tool}_${top_module}.log -od $out_dir -do ^\"do $ctrl_file;$do_constraints do $compilation_file;$do_sdc^\""


  puts $output_file_args "\texit /b"
  puts $output_file_args ""

  puts $output_file_args ":$tool"
  if {$tool eq "autocheck"} {
    puts $output_file_args "\tqverify -c -licq -l qautocheck_${top_module}.log -od $out_dir -do ^\"do $ctrl_file;$do_constraints autocheck compile -d %DUT% $lib_args;autocheck verify -j 4 -rtl_init_values -timeout %TIMEOUT%;  ^\""
  } else {
    puts $output_file_args "\tqverify -c -licq -l q${tool}_${top_module}.log -od $out_dir -do ^\"do $ctrl_file;$do_constraints $tool run -d %DUT% $lib_args; ^\""
  }
  puts $output_file_args "\texit /b"
  puts $output_file_args ""
  puts $output_file_args ":debug_$tool"
  puts $output_file_args "\tqverify  $out_dir\/$tool\.db "
  puts $output_file_args "\texit /b"
  puts $output_file_args ""
  puts $output_file_args ":usage"
  puts $output_file_args "\tECHO \#\#\# run_q${tool} clean \.\.\.\.\.\. Clean all results from directory"
  puts $output_file_args "\tECHO \#\#\# run_q${tool} compile \.\.\.\. Compile source code"
  puts $output_file_args "\tECHO \#\#\# run_q${tool} $tool \.\.\.\.\.\.\.\. Run [string toupper $tool]"
  puts $output_file_args "\tECHO \#\#\# run_q${tool} debug_${tool} \.\. Debug [string toupper $tool] Run"
  puts $output_file_args "\tECHO \#\#\# run_q${tool} all \.\.\.\.\.\.\.\. Run all [string toupper $tool] Steps on Souce Code and Launch Debug"
  puts $output_file_args "\texit /b"


  close $output_file_args
}
  
proc ::tclapp::siemens::questa_ds::write_tcl_file { output_file top_module lib_args  userOD constraints compilation_file ctrl_file use_existing_xdc generate_sdc run_questa_cmd autocheck_verify_timeout tool } {
  
  upvar 1 ${output_file} output_file_args
  
  set do_constraints ""
  if {$constraints != ""} {
    set do_constraints "do $constraints;"
  }

  puts $output_file_args "onerror {exit 1}"
  puts $output_file_args "do [pwd]/$userOD/$ctrl_file"
  puts $output_file_args  "$do_constraints"

  
  puts $output_file_args "do [pwd]/$userOD/$compilation_file"

  ## Get the constraints file
  if { $use_existing_xdc == 1 } {
    write_xdc_constraints_file  output_file_args $top_module $lib_args 0 $tool
  } 
  if { $generate_sdc == 1 } {
    write_sdc_constraints_file output_file_args $top_module $lib_args $userOD 0 $tool
  }

  if { $tool ne "autocheck"} {
     if { $run_questa_cmd == "cdc_setup" } { 
       puts $output_file_args "cdc setup -d $top_module"
     } elseif { $run_questa_cmd == "report_reset" } { 
       puts $output_file_args "rdc run -d $top_module $lib_args -report_reset"
     } else {
       puts $output_file_args "$tool run -d $top_module $lib_args"
       puts $output_file_args "$tool generate report ${top_module}_detailed.rpt"
     }
  } else {
    puts $output_file_args "autocheck disable -type ARITH*"
    puts $output_file_args "autocheck compile -d ${top_module} $lib_args"
    puts $output_file_args "autocheck verify -j 4 -rtl_init_values -timeout ${autocheck_verify_timeout}"
  
  }
  puts $output_file_args "exit 0"
  close $output_file_args
}

proc ::tclapp::siemens::questa_ds::write_sh_file { output_file top_module top_lib_dir out_dir  userOD tcl_script tool } {

  upvar 1 ${output_file} output_file_args
  puts $output_file_args "#! /bin/sh"
  puts $output_file_args ""
  puts $output_file_args "rm -rf $top_lib_dir $out_dir"
  puts $output_file_args "\$QHOME/bin/qverify -c -licq -l q${tool}_${top_module}.log -od $out_dir -do [pwd]/$userOD/${tcl_script}"
  close $output_file_args
}

proc ::tclapp::siemens::questa_ds::run_questa_tool_analysis { run_questa_cmd top_module userOD tool } {

   
   
    if { $tool eq "cdc"} {
       set tool_name "CDC"
       set command_name [expr {$run_questa_cmd == "cdc_setup" ? "cdc setup" : "cdc run"}]
    } elseif { $tool eq "rdc"} {
       set tool_name "RDC"
       set command_name [expr {$run_questa_cmd == "report_reset" ? "rdc run -report_reset" : "rdc run"}]
    } elseif { $tool eq "lint"} {
       set tool_name "Lint"
       set command_name "lint run" 
    } else {
       set tool_name "AUTOCHECK"
       set command_name [expr {$run_questa_cmd == "autocheck_compile" ? "autocheck compile" : "autocheck verify"}]
    } 
    puts "INFO : Running Questa $tool_name (Command: $command_name), the UI will be invoked when the run is finished"
    puts "     : Log can be found at $userOD/${tool_name}_RESULTS/q${tool}_${top_module}.log"

    set OS [lindex $::tcl_platform(os) 0]
    cd $userOD
    
    if { $tool eq "autocheck" } {
       if {$run_questa_cmd eq "autocheck_compile" } {
         if { $OS == "Linux" } {
           exec /bin/sh -c "make autocheck_compile -f Makefile.qautocheck"
         } else {
           exec cmd /c  "run_qautocheck clean compile"
         }
       } elseif { $run_questa_cmd eq "autocheck_verify"} {
       
          if { $OS == "Linux" } {
            exec /bin/sh -c "make autocheck_compile autocheck_verify -f Makefile.qautocheck"
          } else {
            exec cmd /c  "run_qautocheck autocheck"
          }
       
       }
    
    } else {
    
      if { $OS == "Linux" } {
        exec /bin/sh -c "sh q${tool}_run.sh"
      } else {
        exec cmd /c  "run_q$tool clean $tool"
      }
    
    }

  
    puts "INFO : Questa $tool_name run is finished"
    puts "INFO : Invoking Questa $tool_name UI for debugging."
    exec /bin/sh -c "qverify -version"
    
    if { $OS == "Linux" } {
      exec /bin/sh -c "qverify  ${tool_name}_RESULTS/${tool}.db" &
    } else {
      exec cmd /c "run_q${tool} debug_${tool}"
    }

}
proc ::tclapp::siemens::questa_ds::extract_rtl_constraint_files {compile_lib_list_args compile_lines_args black_box_lines_args updated_global_incdirs_args num_files_args top_module } {
  
  upvar 1 ${compile_lib_list_args}     compiled_lib_list
  upvar 1 ${compile_lines_args}     compile_lines
  upvar 1 ${black_box_lines_args}   black_box_lines
  upvar 1 ${updated_global_incdirs_args} updated_global_incdirs
  upvar 1 ${num_files_args} num_files

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
  
  set encrypted_lib "dummmmmy_lib"
  ## If set to 1, will strictly respect file order - if lib files appear non-consecutively this order is maintained
  #  ## otherwise will respect only library order - if lib files appear non-consecutively they will still be merged into one compile command
  set resp_file_order 1
##creating Verilog and VHDL keywords table
    set rtl_keyword_table [dict create]
    set siemens_public_key_table [dict create]
    set rtl_keyword_table [populate_rtl_keywords $rtl_keyword_table]
    set siemens_public_key_table [populate_siemens_publickeys $siemens_public_key_table]

## Does VHDL file for default lib exist
    set vhdl_default_lib_exists 0
## Does Verilog file for default lib exist
    set vlog_default_lib_exists 0

    set vhdl_std "-93"
    set timescale "1ps"

#set proj_name [get_property NAME [current_project]]
## Get list of IPs being used
    set ips [get_ips *]
    set num_ip [llength $ips]
    puts "INFO: Found $num_ip IPs in design"

## Keep track of libraries to avoid duplicat compilation
  array set lib_incdirs_list {}
  array set black_box_libs {}
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
  set updated_global_incdirs ""

  #Get filelist for each IP
  for {set i 0} {$i <= $num_ip} {incr i} {
    if {$i < $num_ip} {
      set ip [lindex $ips $i]
        if {[catch {  set ip_container [get_property IP_CORE_CONTAINER $ip] } errmsg]} {
          puts "ErrorMsg: $errmsg"
          set ip_container "dummy"
        }

#support for CDC-25506 - "write_questa_cdc_script" needs to be enhanced to automatically extract source code for compressed Xilinx IP Containers (.xcix files).
      if {[regexp {xcix} $ip_container all value] && [file exists $ip_container]}  {
              set is_xcix "1"
              set ip_name [get_property NAME $ip]
              set xcix_ip_name [get_property NAME $ip]
              set ip_ref [get_property IPDEF $ip]
              set extracted_files [list]
              set wrong_files [list]
              if {[file exists $ip_name.xcix]} {
                set extracted_files [extract_files -base_dir $userOD/ip [get_files $ip_name.xcix]]
                set wrong_files [get_files -compile_order sources -used_in synthesis -of_objects $ip]
              }
              set files ""
              foreach wrong_file $wrong_files {
                set hdl_file [file tail $wrong_file]
                  foreach extract_file $extracted_files { 
                    if {[regexp $hdl_file $extract_file]}  {
                      if {[regexp {vho} $extract_file all value]  || [regexp {veo} $extract_file all value] || [regexp {txt} $extract_file all value] || [regexp {tb_} $extract_file all value]   }	{ 
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
          if {[file exists $include_file]} {
            lappend files $include_file
          }
        }
      }
    } else {
      set is_xcix "0"
      set ip $top_module
      set ip_name $top_module
      set ip_ref  $top_module
      set files ""
      set files_tmp [get_files -norecurse -compile_order sources -used_in synthesis ]
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
   puts "\nINFO: File= $fn Library= $lib File_type= $ft"
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

           set found_encrypted 0 
           set found_rtlkeyword 0
           set found_publickey 0
           while {[gets $file_h line] >= 0} {
             
            foreach word [split $line] {
               if { [ is_sv_vhdl_keyword $rtl_keyword_table $word ]} {
                 set found_rtlkeyword 1
                 break
               } elseif { [dict exists $siemens_public_key_table $word] } {
                 set found_publickey 1
                 break
               }

            }
            if { $found_rtlkeyword != 0} {
             break
            } elseif {$found_publickey != 0} {
             set found_encrypted 1
             break
            } 

	        }
	       close $file_h
	       if {$found_encrypted == "0"} {
           set lib_file_array($lib) [concat $lib_file_array($lib) " " $fn]
         }
      } else {
          
           set file_h [open $fn]

           set found_encrypted 0 
           set found_rtlkeyword 0
           set found_publickey 0
           while {[gets $file_h line] >= 0} {
             
            foreach word [split $line] {
               if { [ is_sv_vhdl_keyword $rtl_keyword_table $word ]} {
                 set found_rtlkeyword 1
                 break
               } elseif { [dict exists $siemens_public_key_table $word] } {
                 set found_publickey 1
                 break
               }

            }
            if { $found_rtlkeyword != 0} {
             break
            } elseif {$found_publickey != 0} {
             set found_encrypted 1
             break
            } 

	        }
	       close $file_h
          if {$found_encrypted == "0" } {
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
              lappend global_incdirs [concat +incdir+$file_dir  "\\"]
              puts "INFO: Found include file $f"
              set incdir_ar($file_dir) 1
              set lib_incdirs_list($lib_no_num) $incdirs
             }
           }
         }
        }

        set global_incdirs_list [lsort -unique $global_incdirs]
        set updated_global_incdirs [join $global_incdirs_list "\n"]

        ## Print files to compile script
        set debug_num [llength lib_file_array($lib)]
        puts "DEBUG: Found $debug_num of files in library= $lib, IP= $ip_ref IPINST= $ip_name"

        if {[string match $lang "VHDL"]} {
          set line "vcom -autoorder -allowProtectedBeforeBody $vhdl_std -work $lib_no_num \\"
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
          if { [info exists lib_incdirs_list($lib_no_num)] && $lib_incdirs_list($lib_no_num) != "" && [string length $updated_global_incdirs] > 0} {
            set line "  \$INCDIR \\"
            lappend compile_lines $line

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
              } else {
                set f_type [get_property FILE_TYPE [lindex [get_files -all $f] 0]]
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


 }


proc ::tclapp::siemens::questa_ds::write_questa_cdc_script {args} {
# Summary : This proc generates the Questa CDC script file

  # Argument Usage:
  # top_module : Provide the design top name
  # [-output_directory <arg>]: Specify the output directory to generate the scripts in
  # [-use_existing_xdc]: To  use the input constraints file instead of generating SDC file
  # [-generate_sdc]: To generate the SDC file of the synthesized design
  # [-run <arg>]: Run Questa CDC and invoke the UI of Questa CDC debug after generating the running scripts, default behavior is to stop after the generation of the scripts
  # [-cdc_constraints]:Directives in the form of tcl File
  # [-methodology] : To enable methodology for the CDC Flow
  # [-goal] : To select goal for the respective methodology
  # [-library_version] : add an option for the user to specify the target Vivado library version for "netlist fpga"
  # [-fpga_libs] : Specify fpga installation directory
  # [-add_button]: Add a button to run Questa CDC in Vivado UI.
  # [-remove_button]: Remove the Questa CDC button from Vivado UI.

  # Return Value: Returns '0' on successful completion

  # Categories: xilinxtclstore, siemens, questa_cdc
   

  set args [subst [regsub -all \{ $args ""]]
  set args [subst [regsub -all \} $args ""]]
  set userOD "."
  set top_module ""
  set use_existing_xdc 0
  set generate_sdc 0
  set run_questa_cdc ""
  set cdc_constraints ""
  set add_button 0
  set remove_button 0
  set select_methodology 0
  set methodology ""
  set select_goal 0
  set goal ""
  set library_version ""
  set fpga_libs ""
  set is_set_hier_ips 0
  set usage_msg "Usage     : write_questa_cdc_script <top_module> \[-output_directory <out_dir>\] \[-use_existing_xdc|-generate_sdc\] \[-cdc_constraints <constraints_file>\] \[-methodology <SoC|FPGA|IP>\] \[-goal <start|planning|implementation|release|custom_goal>\] \[-run   <cdc_setup|cdc_run>\] \[-library_version <lib_version>\] \[-fpga_libs <fpga_installation_directory>\] \[-hier_ips\] \[-add_button\] \[-remove_button\]"
  # Parse the arguments
  if { [llength $args] > 19 } {
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
    } elseif { [lindex $args $i] == "-run" } {
      incr i
      set run_questa_cdc "[lindex $args $i]"
      if { ($run_questa_cdc != "cdc_run") && ($run_questa_cdc != "cdc_setup") } {
        puts "** ERROR : Invalid argument value for -run '$run_questa_cdc'"
        puts $usage_msg
        return 1
      }
    } elseif { [lindex $args $i] == "-cdc_constraints" } {
        incr i
        set cdc_constraints "[lindex $args $i]" 
        if { ($cdc_constraints == "") } {
          puts "** ERROR : Missing argument value for -cdc_constraints"
            puts $usage_msg
            return 1
        }    
      set cdc_constraints [file normalize $cdc_constraints]
    } elseif { [lindex $args $i] == "-fpga_libs" } {
        incr i
        set fpga_libs "[lindex $args $i]" 
    } elseif { [lindex $args $i] == "-add_button" } {
      set add_button 1
    } elseif { [lindex $args $i] == "-remove_button" } {
      set remove_button 1
    } elseif { [lindex $args $i] == "-methodology" } {
      set select_methodology 1
      incr i
      set methodology "[lindex $args $i]" 
      set methodology [string tolower $methodology]
      if { ($methodology != "soc") && ($methodology != "fpga") && ($methodology != "ip")  } {
        puts "** ERROR : Invalid argument value for -methodology '$methodology'"
        puts $usage_msg
        return 1
      } 
    } elseif { [lindex $args $i] == "-goal" } {
      if {$select_methodology != 1} {
        puts "** ERROR : Missing Methodology Value"
        puts $usage_msg
        return 1
      }
      incr i
      set select_goal 1
      set goal "[lindex $args $i]"
    } elseif { [lindex $args $i] == "-library_version" } {
      incr i
      set library_version [lindex $args $i]
      if {![regexp {^\d+\.\d+$} $library_version]} {
        puts "** ERROR : Invalid argument value for -library_version '$library_version'"
        puts $usage_msg
        return 1
      }
    } elseif { [lindex $args $i] == "-hier_ips" } {
      set is_set_hier_ips 1
    } else {
      set top_module [lindex $args $i]
    }
  }
  
 
  
  ## Set return code to 0
  set rc 0

  # Getting the current vivado version and remove 'v' from the version string
  set vivado_version [get_vivado_version]
  ## Add Vivado GUI button for Questa CDC
   if { $add_button == 1 } {
      return [add_vivado_CDC_RDC_GUI_button $rc "CDC"]
   }
   
   ## Remove Vivado GUI button for Questa CDC
  if { $remove_button == 1 } {
     return [remove_vivado_GUI_button "CDC" $rc]
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
  # Open output files to write
  set qcdc_ctrl "qcdc_ctrl.tcl"
  set run_makefile "Makefile.qcdc"
  set run_batfile "run_qcdc.bat"
  set run_sdcfile "qcdc_sdc.tcl"
  set qcdc_compile_tcl "qcdc_compile.tcl"
  set run_script "qcdc_run.sh"
  set tcl_script "qcdc_run.tcl"
  set encrypted_lib [list]
  if { [catch {open $userOD/$run_makefile w} result] } {
    puts stderr "ERROR: Could not open $run_makefile for writing\n$result"
    set rc 2
    return $rc
  } else {
    set qcdc_run_makefile_fh $result
    puts "INFO: Writing Questa CDC run Makefile to file $userOD/$run_makefile"
  }
  if { [catch {open $userOD/$run_batfile w} result] } {
    puts stderr "ERROR: Could not open $run_batfile for writing\n$result"
    set rc 2
    return $rc
  } else {
    set qcdc_run_batfile_fh $result
    puts "INFO: Writing Questa CDC run batfile to file $userOD/$run_batfile"
  }
  if { [catch {open $userOD/$run_sdcfile w} result] } {
    puts stderr "ERROR: Could not open $run_sdcfile for writing\n$result"
    set rc 2
    return $rc
  } else {
    set qcdc_run_sdcfile_fh $result
    puts "INFO: Writing Questa CDC run SDC file to file $userOD/$run_sdcfile"
  }
  if { [catch {open $userOD/$run_script w} result] } {
    puts stderr "ERROR: Could not open $run_script for writing\n$result"
    set rc 2
    return $rc
  } else {
    set qcdc_run_fh $result
    puts "INFO: Writing Questa CDC run script to file $userOD/$run_script"
  }

  if { [catch {open $userOD/$tcl_script w} result] } {
    puts stderr "ERROR: Could not open $tcl_script for writing\n$result"
    set rc 10
    return $rc
  } else {
    set qcdc_tcl_fh $result
    puts "INFO: Writing Questa CDC tcl script to file $userOD/$tcl_script"
  }

  if { [catch {open $userOD/$qcdc_ctrl w} result] } {
    puts stderr "ERROR: Could not open $qcdc_ctrl for writing\n$result"
    set rc 3
    return $rc
  } else {
    set qcdc_ctrl_fh $result
    puts "INFO: Writing Questa CDC control directives script to file $userOD/$qcdc_ctrl"
  }

  if { [catch {open $userOD/$qcdc_compile_tcl w} result] } {
    puts stderr "ERROR: Could not open $qcdc_compile_tcl for writing\n$result"
    set rc 4
    return $rc
  } else {
    set qcdc_compile_tcl_fh $result
    puts "INFO: Writing Questa CDC Tcl script to file $userOD/$qcdc_compile_tcl"
  }

  ## Keep track of libraries to avoid duplicat compilation

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

  array set compiled_lib_list {}
  set compile_lines [list ]
  set num_files 0
  set updated_global_incdirs ""
  set black_box_lines [list ]
  
######CDC-25493- Extraction of +define options########
  set verilog_define_options [ get_property verilog_define [current_fileset] ]
  if { [string match $verilog_define_options ""]  } {
  } else {
    set modified_verilog_define_options [regsub -all " " $verilog_define_options "+"]
      set prefix_verilog_define_options "+define+"
      set verilog_define_options "${prefix_verilog_define_options}${modified_verilog_define_options}"
  }
  
  
  extract_rtl_constraint_files compiled_lib_list compile_lines black_box_lines  updated_global_incdirs num_files  $top_module 
  if {$is_set_hier_ips } {
    set_hier_ips "cdc" $userOD
  }
  if {$num_files == 0} {
    puts stderr "ERROR: Could not find any files in synthesis fileset"
    set rc 7
    return $rc
  }
  
     write_compilation_files qcdc_compile_tcl_fh "CDC" compiled_lib_list compile_lines updated_global_incdirs $verilog_define_options

  # Settings
  set top_lib_dir "qft"
  set cdc_out_dir "CDC_RESULTS" 
  set modelsimini "modelsim.ini"
  ## Print compile information
  if {$library_version eq "" } {
    set library_version $vivado_version
  }
  write_ctrl_file qcdc_ctrl_fh $library_version $fpga_libs $select_methodology $methodology $select_goal $goal black_box_lines "cdc" 

  ## Get the library names and append a '-L' to the library name
  array set qft_libs {}
  foreach lib [array names compiled_lib_list] {
    set qft_libs($lib) 1
  }
  set lib_args ""
  foreach lib [array names qft_libs] {
    set lib_args [concat $lib_args -L $lib]
  }

  ## Get the constraints file
  if { $use_existing_xdc == 1 } {
    write_xdc_constraints_file  qcdc_run_sdcfile_fh $top_module $lib_args 0 "cdc"
  } 
  if { $generate_sdc == 1 } {
    write_sdc_constraints_file qcdc_run_sdcfile_fh $top_module $lib_args $userOD 0 "cdc"
  }
## Dump the run Makefile
  write_makefile  qcdc_run_makefile_fh $top_module $lib_args $top_lib_dir $cdc_out_dir $userOD $cdc_constraints $qcdc_compile_tcl $qcdc_ctrl $use_existing_xdc $generate_sdc "cdc" "" 

  write_batfile qcdc_run_batfile_fh $top_module $lib_args $top_lib_dir $cdc_out_dir $userOD $cdc_constraints $qcdc_compile_tcl $qcdc_ctrl $run_sdcfile "cdc" ""

 # ## Dump the run file
  write_sh_file qcdc_run_fh $top_module $top_lib_dir $cdc_out_dir $userOD $tcl_script "cdc" 

  write_tcl_file  qcdc_tcl_fh $top_module $lib_args $userOD $cdc_constraints $qcdc_compile_tcl $qcdc_ctrl $use_existing_xdc $generate_sdc $run_questa_cdc "" "cdc" 
  
  puts "INFO : Generation of running scripts for Questa CDC is done at [pwd]/$userOD"

  ## Change permissions of the generated running script
  set OS [lindex $::tcl_platform(os) 0]
  if { $OS == "Linux" } {
    exec chmod u+x $userOD/$run_script
  }
  if {$run_questa_cdc ne ""} {
    run_questa_tool_analysis $run_questa_cdc $top_module $userOD "cdc"
  }
  return $rc  
  
  
  
 
}
proc ::tclapp::siemens::questa_ds::write_questa_rdc_script {args} {
# Summary : This proc generates the Questa RDC script file

  # Argument Usage:
  # top_module : Provide the design top name
  # [-output_directory <arg>]: Specify the output directory to generate the scripts in
  # [-use_existing_xdc]: Ignore running write_xdc command to generate the SDC file of the synthesized design, and use the input constraints file instead
  # [-generate_sdc]: To generate the SDC file of the synthesized design
  # [-rdc_constraints]:Directives in the form of tcl File
  # [-run <arg>]: Run Questa RDC and invoke the UI of Questa RDC debug after generating the running scripts, default behavior is to stop after the generation of the scripts
  # [-library_version] : add an option for the user to specify the target Vivado library version for "netlist fpga"
  # [-fpga_libs] : Specify fpga installation directory
  # [-methodology] : To enable methodology for the RDC Flow
  # [-goal] : To select goal for the respective methodology
  # [-add_button]: Add a button to run Questa RDC in Vivado UI.
  # [-remove_button]: Remove the Questa RDC button from Vivado UI.

  # Return Value: Returns '0' on successful completion

  # Categories: xilinxtclstore, siemens, questa_rdc

  set args [subst [regsub -all \{ $args ""]]
  set args [subst [regsub -all \} $args ""]]
 


  set userOD "."
  set top_module ""
  set use_existing_xdc 0
  set generate_sdc 0
  set rdc_constraints ""
  set run_questa_rdc ""
  set add_button 0
  set remove_button 0
  set select_methodology 0
  set methodology ""
  set select_goal 0
  set goal ""
  set library_version ""
  set fpga_libs ""
  set is_set_hier_ips 0

  set usage_msg "Usage    : write_questa_rdc_script <top_module> \[-output_directory <out_dir>\] \[-use_existing_xdc|-generate_sdc\] \[-rdc_constraints <constraints_file>\] \[-run <report_reset|rdc_run>\] \[-methodology <SoC|FPGA|IP>\] \[-goal <start|planning|implementation|release|custom_goal>\] \[-library_version <lib_version>\] \[-fpga_libs <fpga_installation_directory>\] \[-hier_ips\] \[-add_button\] \[-remove_button\]"
  # Parse the arguments
  if { [llength $args] > 17 } {
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
    } elseif { [lindex $args $i] == "-rdc_constraints" } { 
      incr i
        set rdc_constraints "[lindex $args $i]" 
        if { ($rdc_constraints == "") } { 
          puts "** ERROR : Missing argument value for -rdc_constraints"
            puts $usage_msg
            return 1
        }     
      set rdc_constraints [file normalize $rdc_constraints]
    } elseif { [lindex $args $i] == "-run" } {
      incr i
      set run_questa_rdc "[lindex $args $i]"
      if { ($run_questa_rdc != "rdc_run") && ($run_questa_rdc != "report_reset") } {
        puts "** ERROR : Invalid argument value for -run '$run_questa_rdc'"
        puts $usage_msg
        return 1
      }
    } elseif { [lindex $args $i] == "-add_button" } {
      set add_button 1
    } elseif { [lindex $args $i] == "-remove_button" } {
      set remove_button 1
    } elseif { [lindex $args $i] == "-methodology" } {
      set select_methodology 1
        incr i
        set methodology "[lindex $args $i]" 
        set methodology [string tolower $methodology]
        if { ($methodology != "soc") && ($methodology != "fpga") && ($methodology != "ip")  } {  
          puts "** ERROR : Invalid argument value for -methodology '$methodology'"
            puts $usage_msg
            return 1
        }    
    } elseif { [lindex $args $i] == "-goal" } {
      if {$select_methodology != 1} { 
        puts "** ERROR : Missing Methodology Value"
          puts $usage_msg
          return 1
      }    
     incr i
     set select_goal 1
     set goal "[lindex $args $i]" 
    } elseif { [lindex $args $i] == "-library_version" } {
      incr i
      set library_version [lindex $args $i]
      if {![regexp {^\d+\.\d+$} $library_version]} {
        puts "** ERROR : Invalid argument value for -library_version '$library_version'"
        puts $usage_msg
        return 1
      }
    } elseif { [lindex $args $i] == "-fpga_libs" } {
      incr i
      set fpga_libs "[lindex $args $i]"
    } elseif { [lindex $args $i] == "-hier_ips" } {
      set is_set_hier_ips 1
    } else {
      set top_module [lindex $args $i]
    }
  }
  
  
   ## -add_button and -remove_button can't be specified together
  if { ($remove_button == 1) && ($add_button == 1) } {
    puts "** ERROR : '-add_button' and '-remove_button' can't be specified together."
    return 1
  }
  ## Set return code to 0
  set rc 0
  

  # Getting the current vivado version and remove 'v' from the version string
  set vivado_version [get_vivado_version]
  ## Add Vivado GUI button for Questa RDC
  if { $add_button == 1 } {
    return [add_vivado_CDC_RDC_GUI_button $rc "RDC"]
  }

  ## Remove Vivado GUI button for Questa RDC
  if { $remove_button == 1 } {
     return [remove_vivado_GUI_button "RDC" $rc]
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
  
  set qrdc_ctrl "qrdc_ctrl.tcl"
  set run_makefile "Makefile.qrdc"
  set run_batfile "run_qrdc.bat"
  set run_sdcfile "qrdc_sdc.tcl"
  set qrdc_ctrl "qrdc_ctrl.tcl"
  set qrdc_compile_tcl "qrdc_compile.tcl"
  set run_script "qrdc_run.sh"
  set tcl_script "qrdc_run.tcl"
  set encrypted_lib "dummmmmy_lib"
  
  # Open output files to write
  if { [catch {open $userOD/$run_makefile w} result] } {
    puts stderr "ERROR: Could not open $run_makefile for writing\n$result"
    set rc 2
    return $rc
  } else {
    set qrdc_run_makefile_fh $result
    puts "INFO: Writing Questa rdc run Makefile to file $userOD/$run_makefile"
  }
  if { [catch {open $userOD/$run_batfile w} result] } {
    puts stderr "ERROR: Could not open $run_batfile for writing\n$result"
    set rc 2
    return $rc
  } else {
    set qrdc_run_batfile_fh $result
    puts "INFO: Writing Questa rdc run batfile to file $userOD/$run_batfile"
  }
  if { [catch {open $userOD/$run_sdcfile w} result] } {
    puts stderr "ERROR: Could not open $run_sdcfile for writing\n$result"
    set rc 2
    return $rc
  } else {
    set qrdc_run_sdcfile_fh $result
    puts "INFO: Writing Questa rdc run batfile to file $userOD/$run_sdcfile"
  }
  if { [catch {open $userOD/$run_script w} result] } {
    puts stderr "ERROR: Could not open $run_script for writing\n$result"
    set rc 2
    return $rc
  } else {
    set qrdc_run_fh $result
    puts "INFO: Writing Questa RDC run script to file $run_script"
  }

  if { [catch {open $userOD/$tcl_script w} result] } {
    puts stderr "ERROR: Could not open $tcl_script for writing\n$result"
    set rc 10
    return $rc
  } else {
    set qrdc_tcl_fh $result
    puts "INFO: Writing Questa RDC tcl script to file $tcl_script"
  }

  if { [catch {open $userOD/$qrdc_ctrl w} result] } {
    puts stderr "ERROR: Could not open $qrdc_ctrl for writing\n$result"
    set rc 3
    return $rc
  } else {
    set qrdc_ctrl_fh $result
    puts "INFO: Writing Questa RDC control directives script to file $qrdc_ctrl"
  }

  if { [catch {open $userOD/$qrdc_compile_tcl w} result] } {
    puts stderr "ERROR: Could not open $qrdc_compile_tcl for writing\n$result"
    set rc 4
    return $rc
  } else {
    set qrdc_compile_tcl_fh $result
    puts "INFO: Writing Questa RDC Tcl script to file $qrdc_compile_tcl"
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

  ## Keep track of libraries to avoid duplicat compilation
  array set compiled_lib_list {}
  set compile_lines [list ]
  set num_files 0
  set updated_global_incdirs ""
  set black_box_lines [list ]
  
######CDC-25493- Extraction of +define options########
  set verilog_define_options [ get_property verilog_define [current_fileset] ]
  if { [string match $verilog_define_options ""]  } {
  } else {
    set modified_verilog_define_options [regsub -all " " $verilog_define_options "+"]
      set prefix_verilog_define_options "+define+"
      set verilog_define_options "${prefix_verilog_define_options}${modified_verilog_define_options}"
  }
  
  extract_rtl_constraint_files compiled_lib_list compile_lines black_box_lines  updated_global_incdirs num_files  $top_module  
  
  if {$is_set_hier_ips } {
    set_hier_ips "rdc" $userOD
  }
  if {$num_files == 0} {
    puts stderr "ERROR: Could not find any files in synthesis fileset"
    set rc 7
    return $rc
  }

  # Print compile information
   write_compilation_files qrdc_compile_tcl_fh "RDC" compiled_lib_list compile_lines updated_global_incdirs $verilog_define_options
  # Settings
   set top_lib_dir "qft"
   set rdc_out_dir "RDC_RESULTS" 
   set modelsimini "modelsim.ini"

  if {$library_version eq "" } {
    set library_version $vivado_version
  }

  write_ctrl_file qrdc_ctrl_fh $library_version $fpga_libs $select_methodology $methodology $select_goal $goal black_box_lines "rdc" 

  ## Get the library names and append a '-L' to the library name
  array set qft_libs {}
  foreach lib [array names compiled_lib_list] {
    set qft_libs($lib) 1
  }
  set lib_args ""
  foreach lib [array names qft_libs] {
    set lib_args [concat $lib_args -L $lib]
  }


  ## Get the constraints file
  if { $use_existing_xdc == 1 } {
    write_xdc_constraints_file qrdc_run_sdcfile_fh $top_module $lib_args 0 "rdc"
  } 
  if { $generate_sdc == 1 } {
    write_sdc_constraints_file qrdc_run_sdcfile_fh $top_module $lib_args $userOD 0 "rdc"
  }
  ## Dump the run file
## Dump the run Makefile
  write_makefile  qrdc_run_makefile_fh $top_module $lib_args $top_lib_dir $rdc_out_dir $userOD $rdc_constraints $qrdc_compile_tcl $qrdc_ctrl $use_existing_xdc $generate_sdc "rdc" "" 

  write_batfile qrdc_run_batfile_fh $top_module $lib_args $top_lib_dir $rdc_out_dir $userOD $rdc_constraints $qrdc_compile_tcl $qrdc_ctrl $run_sdcfile "rdc" ""
  
  write_sh_file qrdc_run_fh $top_module $top_lib_dir $rdc_out_dir $userOD $tcl_script "rdc" 
  
  write_tcl_file  qrdc_tcl_fh $top_module $lib_args $userOD $rdc_constraints $qrdc_compile_tcl $qrdc_ctrl $use_existing_xdc $generate_sdc $run_questa_rdc "" "rdc" 
  
  puts "INFO : Generation of running scripts for Questa RDC is done at [pwd]/$userOD"

  ## Change permissions of the generated running script
  set OS [lindex $::tcl_platform(os) 0]
  if { $OS == "Linux" } {
    exec chmod u+x $userOD/$run_script
  }
  if {$run_questa_rdc ne ""} {
    run_questa_tool_analysis $run_questa_rdc $top_module $userOD "rdc"
  }
  return $rc



}
proc ::tclapp::siemens::questa_ds::write_questa_lint_script {args} {

  # Summary : This proc generates the Questa Lint script file

  # Argument Usage:
  # top_module : Provide the design top name
  # [-output_directory <arg>]: Specify the output directory to generate the scripts in
  # [-run <arg>]: Run Questa Lint and invoke the UI of Questa Lint debug after generating the running scripts, default behavior is to stop after the generation of the scripts
  # [-lint_constraints]:Directives in the form of tcl File
  # [-library_version] : add an option for the user to specify the target Vivado library version for "netlist fpga"
  # [-fpga_libs] : Specify fpga installation directory
  # [-methodology] : To enable methodology for the CDC Flow
  # [-goal] : To select goal for the respective methodology
  # [-add_button]: Add a button to run Questa Lint in Vivado UI.
  # [-remove_button]: Remove the Questa Lint button from Vivado UI.

  # Return Value: Returns '0' on successful completion

  # Categories: xilinxtclstore, siemens, questa_lint

  set args [subst [regsub -all \{ $args ""]]
  set args [subst [regsub -all \} $args ""]]


  set userOD "."
  set top_module ""
  set no_sdc 0
  set lint_constraints ""
  set run_questa_lint ""
  set add_button 0
  set remove_button 0
  set select_methodology 1
  set methodology "fpga"
  set select_goal 1
  set goal "start"
  set library_version ""
  set fpga_libs ""
  set is_set_hier_ips 0

  set usage_msg "Usage    : write_questa_lint_script <top_module> \[-output_directory <out_dir>\]  \[-lint_constraints <constraints_file>\] \[-run <lint_run>\] \[-methodology <SoC|FPGA|IP>\] \[-goal <start|planning|implementation|release|custom_goal>\] \[-add_button\] \[-library_version <lib_version>\] \[-fpga_libs <fpga_installation_directory>\] \[-hier_ips\] \[-remove_button\]"
  # Parse the arguments
  if { [llength $args] > 18} {
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
    } elseif { [lindex $args $i] == "-no_sdc" } {
      set no_sdc 1
    } elseif { [lindex $args $i] == "-run" } {
      incr i
      set run_questa_lint "[lindex $args $i]"
      if { ($run_questa_lint != "lint_run")  } {
        puts "** ERROR : Invalid argument value for -run '$run_questa_lint'"
        puts $usage_msg
        return 1
      }
    } elseif { [lindex $args $i] == "-lint_constraints" } {
      incr i
      set lint_constraints "[lindex $args $i]" 
      if { ($lint_constraints == "") } {
        puts "** ERROR : Missing argument value for -lint_constraints"
          puts $usage_msg
          return 1
      }
      set lint_constraints [file normalize $lint_constraints]
    } elseif { [lindex $args $i] == "-methodology" } {
        incr i
        set methodology "[lindex $args $i]"
        set methodology [string tolower $methodology]
        if { ($methodology != "soc") && ($methodology != "fpga") && ($methodology != "ip")  } {
          puts "** ERROR : Invalid argument value for -methodology '$methodology'"
          puts $usage_msg
          return 1
        }
    } elseif { [lindex $args $i] == "-goal" } {
      incr i
      set goal "[lindex $args $i]"
    } elseif { [lindex $args $i] == "-hier_ips" } {
      set is_set_hier_ips 1
   } elseif { [lindex $args $i] == "-library_version" } {
     incr i
     set library_version [lindex $args $i]
     if {![regexp {^\d+\.\d+$} $library_version]} {
       puts "** ERROR : Invalid argument value for -library_version '$library_version'"
       puts $usage_msg
       return 1
     } 
   } elseif { [lindex $args $i] == "-fpga_libs" } {
     incr i
     set fpga_libs "[lindex $args $i]"
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
  set vivado_version [get_vivado_version]
  
  ## Add Vivado GUI button for Questa LINT
  if { $add_button == 1 } {
      return [add_vivado_LINT_GUI_button $rc]
  }

  ## Remove Vivado GUI button for Questa RDC
  if { $remove_button == 1 } {
     return [remove_vivado_GUI_button "Lint" $rc]
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

  set run_makefile "Makefile.qlint"
  set run_batfile "run_qlint.bat"
  set qlint_ctrl "qlint_ctrl.tcl"
  set qlint_compile_tcl "qlint_compile.tcl"
  set run_script "qlint_run.sh"
  set tcl_script "qlint_run.tcl"
  set encrypted_lib "dummmmmy_lib"
  
  # Open output files to write
  if { [catch {open $userOD/$run_makefile w} result] } {
    puts stderr "ERROR: Could not open $run_makefile for writing\n$result"
    set rc 2
    return $rc
  } else {
    set qlint_run_makefile_fh $result
    puts "INFO: Writing Questa lint run Makefile to file $userOD/$run_makefile"
  }
  if { [catch {open $userOD/$run_batfile w} result] } {
    puts stderr "ERROR: Could not open $run_batfile for writing\n$result"
    set rc 2
    return $rc
  } else {
    set qlint_run_batfile_fh $result
    puts "INFO: Writing Questa lint run batfile to file $userOD/$run_batfile"
  }
  if { [catch {open $userOD/$run_script w} result] } {
    puts stderr "ERROR: Could not open $run_script for writing\n$result"
    set rc 2
    return $rc
  } else {
    set qlint_run_fh $result
    puts "INFO: Writing Questa Lint run script to file $run_script"
  }

  if { [catch {open $userOD/$tcl_script w} result] } {
    puts stderr "ERROR: Could not open $tcl_script for writing\n$result"
    set rc 10
    return $rc
  } else {
    set qlint_tcl_fh $result
    puts "INFO: Writing Questa Lint tcl script to file $tcl_script"
  }

  if { [catch {open $userOD/$qlint_ctrl w} result] } {
    puts stderr "ERROR: Could not open $qlint_ctrl for writing\n$result"
    set rc 3
    return $rc
  } else {
    set qlint_ctrl_fh $result
    puts "INFO: Writing Questa Lint control directives script to file $qlint_ctrl"
  }

  if { [catch {open $userOD/$qlint_compile_tcl w} result] } {
    puts stderr "ERROR: Could not open $qlint_compile_tcl for writing\n$result"
    set rc 4
    return $rc
  } else {
    set qlint_compile_tcl_fh $result
    puts "INFO: Writing Questa Lint Tcl script to file $qlint_compile_tcl"
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

  array set compiled_lib_list {}
  set compile_lines [list ]
  set num_files 0
  set updated_global_incdirs ""
  set black_box_lines [list ]
  
  ######CDC-25493- Extraction of +define options########
  set verilog_define_options [ get_property verilog_define [current_fileset] ]
  if { [string match $verilog_define_options ""]  } {
  } else {
    set modified_verilog_define_options [regsub -all " " $verilog_define_options "+"]
      set prefix_verilog_define_options "+define+"
      set verilog_define_options "${prefix_verilog_define_options}${modified_verilog_define_options}"
  }
  
  extract_rtl_constraint_files compiled_lib_list compile_lines black_box_lines  updated_global_incdirs num_files  $top_module  
  
  if {$is_set_hier_ips } {
    set_hier_ips "lint" $userOD
  }
  if {$num_files == 0} {
    puts stderr "ERROR: Could not find any files in synthesis fileset"
    set rc 7
    return $rc
  }
  
   ## Print compile information
   write_compilation_files qlint_compile_tcl_fh "LINT" compiled_lib_list compile_lines updated_global_incdirs $verilog_define_options

  # Settings
  set top_lib_dir "qft"
  set lint_out_dir "Lint_RESULTS"
  set modelsimini "modelsim.ini"

  if {$library_version eq "" } {
    set library_version $vivado_version
  }
 
  write_ctrl_file qlint_ctrl_fh $library_version $fpga_libs $select_methodology $methodology $select_goal $goal black_box_lines "lint" 

  ## Get the library names and append a '-L' to the library name
  array set qft_libs {}
  foreach lib [array names compiled_lib_list] {
    set qft_libs($lib) 1
  }
  set lib_args ""
  foreach lib [array names qft_libs] {
    set lib_args [concat $lib_args -L $lib]
  }
  
  set lint_constraints_do ""
  if {$lint_constraints != ""} {
    set lint_constraints_do "do $lint_constraints;"
  }


  ## Dump the run file
  write_makefile  qlint_run_makefile_fh $top_module $lib_args $top_lib_dir $lint_out_dir $userOD $lint_constraints $qlint_compile_tcl $qlint_ctrl 0 0 "lint" "" 
  
  write_batfile qlint_run_batfile_fh $top_module $lib_args $top_lib_dir $lint_out_dir $userOD $lint_constraints $qlint_compile_tcl $qlint_ctrl "" "lint" ""
  
  write_sh_file qlint_run_fh $top_module $top_lib_dir $lint_out_dir $userOD $tcl_script "lint" 

  write_tcl_file  qlint_tcl_fh $top_module $lib_args $userOD "" $qlint_compile_tcl $qlint_ctrl "" "" $run_questa_lint "" "lint"
  puts "INFO : Generation of running scripts for Questa Lint is done at [pwd]/$userOD"
	  set OS [lindex $::tcl_platform(os) 0]
	  if { $OS == "Linux" } {
	    exec chmod u+x $userOD/$run_script
	  }
  if {$run_questa_lint ne ""} {  
    run_questa_tool_analysis $run_questa_lint $top_module $userOD "lint"
  }
  return $rc
	  

}
proc ::tclapp::siemens::questa_ds::write_questa_autocheck_script {args} {



# Summary : This proc generates the Questa AutoCheck script file

  # Argument Usage:
  # top_module : Provide the design top name
  # [-output_directory <arg>]: Specify the output directory to generate the scripts in
  # [-use_existing_xdc]: Ignore running write_xdc command to generate the SDC file of the synthesized design, and use the input constraints file instead
  # [-generate_sdc]: To generate the SDC file of the synthesized design
  # [-autocheck_constraints]:Directives in the form of tcl File
  # [-run <arg>]: Run Questa AutoCheck and invoke the UI of Questa AutoCheck debug after generating the running scripts, default behavior is to stop after the generation of the scripts
  # [-verify_timeout <arg>]: Specify the timeout for Questa AutoCheck Verify run. By default the value specified is in seconds, use 'm' or 'h' suffix to interpret the value as minutes or hours 
  # [-library_version] : add an option for the user to specify the target Vivado library version for "netlist fpga"
  # [-fpga_libs] : Specify fpga installation directory
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
  set run_questa_autocheck ""
  set autocheck_verify_timeout "10m"
  set autocheck_constraints ""
  set add_button 0
  set library_version ""
  set fpga_libs ""
  set remove_button 0
  set is_set_hier_ips 0
  set usage_msg "Usage : write_questa_autocheck_script <top_module> \[-output_directory <out_dir>\] \[-use_existing_xdc|-generate_sdc\] \[-run <autocheck_compile|autocheck_verify>\] \[-verify_timeout <value>\] \[-autocheck_constraints <constraints_file>\] \[-library_version <lib_version>\] \[-fpga_libs <fpga_installation_directory>\] \[-hier_ips\] \[-add_button\] \[-remove_button\]"
  # Parse the arguments
  if { [llength $args] > 17 } {
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
    } elseif { [lindex $args $i] == "-library_version" } {
      incr i
      set library_version [lindex $args $i]
      if {![regexp {^\d+\.\d+$} $library_version]} {
        puts "** ERROR : Invalid argument value for -library_version '$library_version'"
        puts $usage_msg
        return 1
      }
    } elseif { [lindex $args $i] == "-fpga_libs" } {
      incr i
      set fpga_libs "[lindex $args $i]"
    } elseif { [lindex $args $i] == "-add_button" } {
      set add_button 1
    } elseif { [lindex $args $i] == "-hier_ips" } {
      set is_set_hier_ips 1
    } elseif { [lindex $args $i] == "-remove_button" } {
      set remove_button 1
    } else {
      set top_module [lindex $args $i]
    }
  }
  ## Set return code to 0
  set rc 0

  # Getting the current vivado version and remove 'v' from the version string
  set vivado_version [get_vivado_version]
  
  ## Add Vivado GUI button for Questa Autocheck
  if { $add_button == 1 } {
      return [add_vivado_AUTOCHECK_GUI_button $rc]
  }

  ## Remove Vivado GUI button for Questa Autocheck
  if { $remove_button == 1 } {
     return [remove_vivado_GUI_button "AutoCheck" $rc]
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
  set run_batfile "run_qautocheck.bat"
  set run_sdcfile "qautocheck_sdc.tcl"
  set run_script "qautocheck_run.sh"
  set encrypted_lib "dummmmmy_lib"
  set tcl_script "qautocheck_run.tcl"
  
  # Open output files to write
  if { [catch {open $userOD/$tcl_script w} result] } {
    puts stderr "ERROR: Could not open $tcl_script for writing\n$result"
    set rc 10
    return $rc
  } else {
    set qautocheck_tcl_fh $result
    puts "INFO: Writing Questa CDC tcl script to file $userOD/$tcl_script"
  }
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
  
  array set compiled_lib_list {}
  set compile_lines [list ]
  set num_files 0
  set updated_global_incdirs ""
  set black_box_lines [list ]
  
######CDC-25493- Extraction of +define options########
  set verilog_define_options [ get_property verilog_define [current_fileset] ]
  if { [string match $verilog_define_options ""]  } {
  } else {
    set modified_verilog_define_options [regsub -all " " $verilog_define_options "+"]
      set prefix_verilog_define_options "+define+"
      set verilog_define_options "${prefix_verilog_define_options}${modified_verilog_define_options}"
  }
  
 extract_rtl_constraint_files compiled_lib_list compile_lines black_box_lines  updated_global_incdirs num_files  $top_module 
  if {$is_set_hier_ips } {
    set_hier_ips "autocheck" $userOD
  }

  if {$num_files == 0} {
    puts stderr "ERROR: Could not find any files in synthesis fileset"
    set rc 7
    return $rc
  }
 
  
   ## Print compile information
  write_compilation_files qautocheck_compile_tcl_fh "Autocheck" compiled_lib_list compile_lines updated_global_incdirs $verilog_define_options

  # Settings
  set top_lib_dir "qft"
  set autocheck_out_dir "AUTOCHECK_RESULTS"
  set modelsimini "modelsim.ini"
  if {$library_version eq "" } {
    set library_version $vivado_version
  }
  write_ctrl_file qautocheck_ctrl_fh $library_version $fpga_libs 0 "" 0 "" black_box_lines "autocheck" 

  ## Get the library names and append a '-L' to the library name
  array set qft_libs {}
  foreach lib [array names compiled_lib_list] {
    set qft_libs($lib) 1
  }
  set lib_args ""
  foreach lib [array names qft_libs] {
    set lib_args [concat $lib_args -L $lib]
  }

  set autocheck_constraints_do ""
  if {$autocheck_constraints != ""} {
    set autocheck_constraints_do "do $autocheck_constraints;"
  }
  ## Get the constraints file
  if { $use_existing_xdc == 1 } {
    write_xdc_constraints_file qautocheck_run_sdcfile_fh $top_module $lib_args 0 "autocheck"
  } 
  if { $generate_sdc == 1 } {
    write_sdc_constraints_file qautocheck_run_sdcfile_fh $top_module $lib_args $userOD 0 "autocheck"
  }
  ## Dump the run Makefile
  write_makefile  qautocheck_run_makefile_fh $top_module $lib_args $top_lib_dir $autocheck_out_dir $userOD $autocheck_constraints $qautocheck_compile_tcl $qautocheck_ctrl $use_existing_xdc $generate_sdc "autocheck" $autocheck_verify_timeout
  
  write_batfile qautocheck_run_batfile_fh $top_module $lib_args $top_lib_dir $autocheck_out_dir $userOD $autocheck_constraints $qautocheck_compile_tcl $qautocheck_ctrl $run_sdcfile "autocheck" $autocheck_verify_timeout 
  
  write_tcl_file  qautocheck_tcl_fh $top_module $lib_args $userOD $autocheck_constraints $qautocheck_compile_tcl $qautocheck_ctrl $use_existing_xdc $generate_sdc $run_questa_autocheck $autocheck_verify_timeout "autocheck" 
  ## Dump the run file
  puts $qautocheck_run_fh "#! /bin/sh"
  puts $qautocheck_run_fh ""
  puts $qautocheck_run_fh "rm -rf $top_lib_dir $autocheck_out_dir"
  puts $qautocheck_run_fh "qverify -c -licq -l qautocheck_${top_module}.log -od $autocheck_out_dir -do \"$autocheck_constraints_do; do $qautocheck_ctrl;  do $qautocheck_compile_tcl;  do $run_sdcfile;autocheck disable -type ARITH*;autocheck compile -d ${top_module} $lib_args;autocheck verify -j 4 -rtl_init_values -timeout ${autocheck_verify_timeout};    \""
  close $qautocheck_run_fh


  puts "INFO : Generation of running scripts for Questa AutoCheck is done at [pwd]/$userOD"
  if {$run_questa_autocheck ne ""} {
    run_questa_tool_analysis $run_questa_autocheck $top_module $userOD "autocheck"
  }

}
## Keep an environment variable with the path of the script
set env(QUESTA_CDC_TCL_SCRIPT_PATH) [file normalize [file dirname [info script]]]
set env(QUESTA_RDC_TCL_SCRIPT_PATH) [file normalize [file dirname [info script]]]
set env(QUESTA_LINT_TCL_SCRIPT_PATH) [file normalize [file dirname [info script]]]
set env(QUESTA_AUTOCHECK_TCL_SCRIPT_PATH) [file normalize [file dirname [info script]]]
## Auto-import the procs of the Questa CDC script
namespace import -force tclapp::siemens::questa_ds::*
