# Usage: write_questa_cdc_script <top_module> [-od <output_directory>]
###############################################################################
#
# write_questa_cdc_script.tcl (Routine for Mentor Graphics Questa CDC Application)
#
# Script created on 12/20/2016 by Islam Ahmed (Mentor Graphics Inc) &
#                                 Ravi Kurlagunda
#
###############################################################################

namespace eval ::tclapp::mentor::questa_cdc {
  # Export procs that should be allowed to import into other namespaces
  namespace export write_questa_cdc_script
}

proc ::tclapp::mentor::questa_cdc::matches_default_libs {lib} {
  
  # Summary: internally used routine to check if default libs used
  
  # Argument Usage:
  # lib: name of lib to check if default lib

  # Return Value:
  # 1 is returned when the passed library matches on of the names of the default libraries

  # Categories: xilinxtclstore, mentor, questa_cdc

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

  # Categories: xilinxtclstore, mentor, questa_cdc


  set new_lib ""
  if {[matches_default_libs $lib]} {
    set new_lib [concat $lib:$lang:$num]
  } else {
    set new_lib [concat $lib:$lang]
  }
  return $new_lib
}

proc ::tclapp::mentor::questa_cdc::write_questa_cdc_script {top_module args} {

  # Summary : This proc generates the Questa CDC script file

  # Argument Usage:
  # top_module : Provide the design top name
  # [-od <arg>]: Specify the output directory to generate the scripts in

  # Return Value: Returns '0' on successful completion

  # Categories: xilinxtclstore, mentor, questa_cdc

  set userOD "."
  # Parse the arguments
  for {set i 0} {$i < [llength $args]} {incr i} {
    if { [lindex $args $i] == "-od" } {
      incr i
      set userOD "[lindex $args $i]"
      if { $userOD == "" } {
        puts "** ERROR : Specified output directory can't be null."
        return 1
      } else {
      }
    } else {
      puts "** ERROR : Unknow option [lindex $args $i]."
      return 1
    }
  }
  if { $userOD == "." } {
    puts "INFO: Output files will be generated at [file join [pwd] $userOD]"
  } else {
    puts "INFO: Output files will be generated at $userOD"
    file mkdir $userOD
  }

  set qcdc_ctrl "qcdc_ctrl.tcl"
  set qcdc_compile_tcl "qcdc_compile.tcl"
  set run_script "qcdc_run.sh"

  ## Set return code to 0
  set rc 0
  ## Vivado install dir
  set vivado_dir $::env(XILINX_VIVADO)
  puts "INFO: Using Vivado install directory $vivado_dir"

  ## If set to 1, will strictly respect file order - if lib files appear non-consecutively this order is maintained
  ## otherwise will respect only library order - if lib files appear non-consecutively they will still be merged into one compile command
  set resp_file_order 1

  ## Does VHDL file for default lib exist
  set vhdl_default_lib_exists 0
  ## Does Verilog file for default lib exist
  set vlog_default_lib_exists 0

  set vhdl_std "-93"
  set timescale "1ps"

  # Settings
  set top_lib_dir "qft"
  set cdc_out_dir "CDC_RESULTS"
  set modelsimini "modelsim.ini"

  # Open output files to write
  if { [catch {open $userOD/$run_script w} result] } {
    puts stderr "ERROR: Could not open $run_script for writing\n$result"
    set rc 2
    return $rc
  } else {
    set qcdc_run_fh $result
    puts "INFO: Writing Questa CDC run script to file $run_script"
  }

  if { [catch {open $userOD/$qcdc_ctrl w} result] } {
    puts stderr "ERROR: Could not open $qcdc_ctrl for writing\n$result"
    set rc 3
    return $rc
  } else {
    set qcdc_ctrl_fh $result
    puts "INFO: Writing Questa CDC control directives script to file $qcdc_ctrl"
  }

  if { [catch {open $userOD/$qcdc_compile_tcl w} result] } {
    puts stderr "ERROR: Could not open $qcdc_compile_tcl for writing\n$result"
    set rc 4
    return $rc
  } else {
    set qcdc_compile_tcl_fh $result
    puts "INFO: Writing Questa CDC Tcl script to file $qcdc_compile_tcl"
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
  
  # Remove 'v' from the version string
  set vivado_version [lindex [version] 1]
  regsub {v} $vivado_version {} vivado_version 

  set load_lib_line ""
  if {[regexp {virtexu|kintexu} $arch_name]} {
    if {[file exists $vivado_dir/data/parts/xilinx/$arch_name/$arch_name/devint/$arch_name.lib]} {
      set load_lib_line "netlist load lib $vivado_dir/data/parts/xilinx/$arch_name/$arch_name/devint/$arch_name.lib"
    } elseif {[file exists $vivado_dir/data/parts/xilinx/$arch_name/$arch_name/$arch_name.lib]} {
      set load_lib_line "netlist load lib $vivado_dir/data/parts/xilinx/$arch_name/$arch_name/devint/$arch_name.lib"
    } else {
      puts "INFO: No liberty files found for architecture: $arch_name."
      set load_lib_line ""
    }
  } else {
    if {[file exists $vivado_dir/data/parts/xilinx/$arch_name/devint/$arch_name.lib]} {
      set load_lib_line "netlist load lib $vivado_dir/data/parts/xilinx/$arch_name/devint/$arch_name.lib"
    } elseif {[file exists $vivado_dir/data/parts/xilinx/$arch_name/$arch_name.lib]} {
      set load_lib_line "netlist load lib $vivado_dir/data/parts/xilinx/$arch_name/$arch_name.lib"
    } else {
      puts "INFO: No liberty files found for architecture: $arch_name."
      set load_lib_line ""
    }
  }

puts "$load_lib_line"

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
      set line "cdc blackbox memory ${ip_name}_synth"
      lappend black_box_lines $line
      set black_box_libs($ip_name) 1
    }
  }

  set num_files 0
  #Get filelist for each IP
  for {set i 0} {$i <= $num_ip} {incr i} {
    if {$i < $num_ip} {
      set ip [lindex $ips $i]
      set ip_name [get_property NAME $ip]
      set ip_ref [get_property IPDEF $ip]
      puts "INFO: Collecting files for IP $ip_ref ($ip_name)"
      set files [get_files -compile_order sources -used_in synthesis -of_objects $ip]
    } else {
      set ip_name $top_module
      set ip_ref  $top_module
      set files [get_files -norecurse -compile_order sources -used_in synthesis]
      puts "INFO: Collecting files for Top level"
    }

    # Keep a list of all the include files, this is added to handle an issue in the 'wavegen' Xilinx example in which clog2b.vh wasn't added into compilation file
    set all_include_files [get_files -filter {USED_IN_SYNTHESIS && FILE_TYPE =="Verilog Header"}]
    foreach include_file $all_include_files {
      if { [lsearch -exact $files $include_file] == "-1" } {
        lappend files $include_file
      }
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
      if { [get_files -all -of [get_filesets $synth_fileset] $f] != "" } {
        set fn [get_property NAME [lindex [get_files -all -of [get_filesets $synth_fileset] $f] 0]]
        set ft [get_property FILE_TYPE [lindex [get_files -all -of [get_filesets $synth_fileset] $f] 0]]
        set fs [get_property FILESET_NAME [lindex [get_files -all -of [get_filesets $synth_fileset] $f] 0]]
        set lib [get_property LIBRARY [lindex [get_files -all -of [get_filesets $synth_fileset] $f] 0]]
      } else {
        set fn [get_property NAME [lindex [get_files -all $f] 0]]
        set ft [get_property FILE_TYPE [lindex [get_files -all $f] 0]]
        set fs [get_property FILESET_NAME [lindex [get_files -all $f] 0]]
        set lib [get_property LIBRARY [lindex [get_files -all $f] 0]]
      }

      puts "\nINFO: File= $fn Library= $lib File_type= $ft Fileset= $fs"
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
      if {[string match $ft "Verilog"] || [string match $ft "Verilog Header"] || [string match $ft "SystemVerilog"] || [string match $ft "VHDL"]} {
        if {[info exists lib_file_array($lib)]} {
          set lib_file_array($lib) [concat $lib_file_array($lib) " " $fn]
        } else {
          set lib_file_array($lib) $fn
          lappend lib_file_order $lib
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

    puts "DEBUG: IP= $ip_ref IPINST = $ip_name has following libraries $lib_file_order" 

    # For each library, list the files
    foreach lib $lib_file_order {
      if {![info exists compiled_lib_list($lib)] || [matches_default_libs $lib]} {
        regsub ":.*" $lib {} lib_no_num
        puts "INFO: Obtaining list of files for design= $ip_ref, library= $lib"
        set lang $lib_file_lang($lib)
        set incdirs [list ]
        array set incdir_ar {}
        ## Create list of include files
        if {[regexp {Verilog} $lang]} {
          foreach f [split $lib_file_array($lib)] {
            if { [get_files -all -of [get_filesets $synth_fileset] $f] != "" } {
              set is_include [get_property IS_GLOBAL_INCLUDE [lindex [get_files -all -of [get_filesets $synth_fileset] $f] 0]]
              set f_type [get_property FILE_TYPE [lindex [get_files -all -of [get_filesets $synth_fileset] $f] 0]]
            } else {
              set is_include [get_property IS_GLOBAL_INCLUDE [lindex [get_files -all $f] 0]]
              set f_type [get_property FILE_TYPE [lindex [get_files -all $f] 0]]
            }
            if {$is_include == 1 || [string match $f_type "Verilog Header"]} {
              set file_dir [file dirname $f]
              if {![info exists incdir_ar($file_dir)]} {
                lappend incdirs [concat +incdir+$file_dir]
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
          set line "vcom $vhdl_std -work $lib_no_num \\"
          lappend compile_lines $line
          foreach f [split $lib_file_array($lib)] {
            if { [get_files -all -of [get_filesets $synth_fileset] $f] != "" } {
              set f_type [get_property FILE_TYPE [lindex [get_files -all -of [get_filesets $synth_fileset] $f] 0]]
            } else {
              set f_type [get_property FILE_TYPE [lindex [get_files -all $f] 0]]
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

          set line "vlog $sv_switch -incr -work $lib_no_num \\"
          lappend compile_lines $line
          if { [info exists lib_incdirs_list($lib_no_num)] && $lib_incdirs_list($lib_no_num) != ""} {
            foreach idir $lib_incdirs_list($lib_no_num) {
              set line "  $idir \\"
              lappend compile_lines $line
            }
          }
          foreach f [split $lib_file_array($lib)] {
            if { [get_files -all -of [get_filesets $synth_fileset] $f] != "" } {
              set f_type [get_property FILE_TYPE [lindex [get_files -all -of [get_filesets $synth_fileset] $f] 0]]
            } else {
              set f_type [get_property FILE_TYPE [lindex [get_files -all $f] 0]]
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
      } else {
        puts "INFO: Library $lib has already been compiled. Skipping it."
      }
    }

    ## Bookkeeping on which libraries are already compiled
    foreach lib $lib_file_order {
      set compiled_lib_list($lib) 1
    }

    ## Set black-boxes for blk_mem_gen and fifo_gen if they are sub-cores
    foreach subcore $lib_file_order {
      if {![info exists black_box_libs($subcore)]} {
        if {[regexp {^blk_mem_gen_v\d+_\d+} $subcore]} {
          set line "#cdc blackbox memory ${subcore}_synth"
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

  puts $qcdc_compile_tcl_fh "\n#"
  puts $qcdc_compile_tcl_fh "# Create work library"
  puts $qcdc_compile_tcl_fh "#"
  puts $qcdc_compile_tcl_fh "vlib $top_lib_dir"
  foreach key [array names compiled_lib_list] {
    regsub ":.*" $key {} key
    puts $qcdc_compile_tcl_fh "vlib $top_lib_dir/$key"
  }

  puts $qcdc_compile_tcl_fh "\n#"
  puts $qcdc_compile_tcl_fh "# Map libraries"
  puts $qcdc_compile_tcl_fh "#"
  puts $qcdc_compile_tcl_fh "vmap work $top_lib_dir/xil_defaultlib"
  foreach key [array names compiled_lib_list] {
    regsub ":.*" $key {} key
    puts $qcdc_compile_tcl_fh "vmap $key $top_lib_dir/$key"
  }

  puts $qcdc_compile_tcl_fh "\n#"
  puts $qcdc_compile_tcl_fh "# Compile files section"
  puts $qcdc_compile_tcl_fh "#"
  foreach l $compile_lines {
    puts $qcdc_compile_tcl_fh $l
  }

  puts $qcdc_compile_tcl_fh "\n#"
  puts $qcdc_compile_tcl_fh "# Add global set/reset"
  puts $qcdc_compile_tcl_fh "#"
  puts $qcdc_compile_tcl_fh "vlog -work xil_defaultlib $vivado_dir/data/verilog/src/glbl.v"

  close $qcdc_compile_tcl_fh

  ## Print compile information
  puts $qcdc_ctrl_fh "cdc preference -enable_internal_resets -print_port_domain_template"
  puts $qcdc_ctrl_fh "netlist fpga -vendor xilinx -version $vivado_version -library vivado"

  if {$black_box_lines != ""} {
    puts $qcdc_ctrl_fh "\n#"
    puts $qcdc_ctrl_fh "# Black box blk_mem_gen"
    puts $qcdc_ctrl_fh "#"
    foreach l $black_box_lines {
      puts $qcdc_ctrl_fh $l
    }
  }
  close $qcdc_ctrl_fh

  ## Get the library names and append a '-L' to the library name
  array set qft_libs {}
  foreach lib [array names compiled_lib_list] {
    regsub ":.*" $lib {} lib
    set qft_libs($lib) 1
  }
  set lib_args ""
  foreach lib [array names qft_libs] {
    set lib_args [concat $lib_args -L $lib]
  }


  ## Dump the run file
  puts $qcdc_run_fh "#! /bin/sh"
  puts $qcdc_run_fh ""
  puts $qcdc_run_fh "rm -rf $top_lib_dir $cdc_out_dir"
  puts $qcdc_run_fh "\$QFT_HOME/bin/qverify -c -licq -l qcdc_${top_module}.log -od $cdc_out_dir -do \"\\"
  puts $qcdc_run_fh "\tonerror {exit 1}; \\"
  puts $qcdc_run_fh "\tdo $qcdc_ctrl; \\"
  ## Get the constraints file
  set constr_fileset [current_fileset -constrset]
  set files [get_files -all -of [get_filesets $constr_fileset] *]
  foreach file $files {
    set ft [get_property FILE_TYPE [lindex [get_files -all -of [get_filesets $constr_fileset] $file] 0]]
    if { $ft == "XDC" } {
      puts $qcdc_run_fh "\tsdc load $file; \\"
    }
  }
  puts $qcdc_run_fh "\t$load_lib_line; \\"
  puts $qcdc_run_fh "\tdo $qcdc_compile_tcl; \\"
  puts $qcdc_run_fh "\tcdc run -d $top_module $lib_args -formal -formal_effort high; \\"
  puts $qcdc_run_fh "\tcdc generate report ${top_module}_detailed.rpt; \\"
  puts $qcdc_run_fh "\texit 0\""

#  $load_lib_line
#  puts $qcdc_tcl_fh "sdc load $top_module.sdc; \\"
#  puts $qcdc_tcl_fh "do $qcdc_ctrl; \\"

  close $qcdc_run_fh

  return $rc
}
