###############################################################################
#
# write_spyglass_script.tcl (Routine for Synopsys SpyGlass App.)
#
# Script created on 05/06/2015 by Satrajit Pal (Synopsys Inc) & 
#                                 Ravi Kurlagunda
#
# 2015.1 - v1.1 (rev 1.1)
#  * Updated Initial Version
#
# rev 1.2 03/11/2016 
#  * Fixed the path for the device libraries (with gateslib option)
#  * Added the option 'set_option read_protected_envelope yes'
#
# rev 1.5 3/17/2016
#  * If the vhdl library is not blk_mem_gen then get ready to 
#  * prepare for precompilation of this library.
#  * If it is blk_mem_gen then do not do anything. Let this be a true
#  * blackbox. Create the corresponding sgdc file for this blackbox.
#  * Remove the use of the 'synth_fileset' variable
#
#  rev 1.6 07/16/2018
#  * Changing lagency name to "Synopsys"
#  * Changing the methodology path to the latest so no manual changes are 
#    required in generated .prj file.
#  * Updated this tcl file to pick the correct library file as per the FPGA
#    device used. 
#  * To supress SDC_257 violation, Parameter force_genclk_for_txv set to 1
#  * Adding missing XPM components
#
#  rev 1.7 a - 03/12/2021
#  * Added support to generate the tcl script for VC-SpyGlass as well.
#  * same command will be required to generate project file for SpyGlass
#    and setup for VC-SpyGlass. 
#  * For VC-SpyGlass setup, a new directory will be created with name 
#    vc_setup and complete VC-SpyGlass setup will be available in that 
#    directory. VC-SpyGlass TCL name is vc_setup.tcl.
# 
#  rev 1.7 b - 05/05/2023
#  * Bug fixes for precompiled library
#  * Added lint goal into the setup
#  * Added waivers for xilinx specific primitive cells
#
###############################################################################
package require Vivado 1.2015.1

namespace eval ::tclapp::synopsys::spyglass {
    # Export procs that should be allowed to import into other namespaces
    namespace export write_spyglass_script
}

proc ::tclapp::synopsys::spyglass::matches_default_libs {lib} {

  # Summary: internally used routine to check if default libs used
  # Argument Usage: 
  # lib: name of lib to check if default lib
  # Return Value: 
  # Categories: xilinxtclstore, Synopsys, spyglass

  regsub ":.*" $lib {} lib
  if {[string match -nocase $lib "xil_defaultlib"]} {
    return 1
  } elseif {[string match -nocase $lib "work"]} {
    return 1
  } else {
    return 0
  }
}

proc ::tclapp::synopsys::spyglass::uniquify_lib {lib lang num} {

  # Summary: internally used routine to uniquify libs
  # Argument Usage:
  # lib: lib name to match
  # num: uniquified lib name
  # Return Value:
  # Categories: xilinxtclstore, synopsys, spyglass

  set new_lib ""
  if {[matches_default_libs $lib]} {
    set new_lib [concat $lib:$lang:$num]
  } else {
    set new_lib [concat $lib:$lang]
  }
  return $new_lib
}

proc ::tclapp::synopsys::spyglass::write_spyglass_script {top_module outfile} {

  # Summary : This proc generates the spyglass project file
  # Argument Usage:
  # top_module: Provide the design top name
  # outfile: Provide the file name to store the SpyGlass Configuration data
  # Return Value: Returns '1' on successful completion
  # Categories: xilinxtclstore, synopsys, spyglass

  puts "Calling ::tclapp::synopsys::spyglass::write_spyglass_script"

  ## Set return code to 0
  set rc 0
  set rcv 0
  set rc1 0
  set rc2 0
  ## Vivado install dir
  set vivado_dir $::env(XILINX_VIVADO)
  set sg_run_dir "sg_results"
  puts "INFO: Using Vivado install directory $vivado_dir"

  ## If set to 1, will strictly respect file order - if lib files appear non-consecutively this order is maintained
  ## otherwise will respect only library order - if lib files appear non-consecutively they will still be merged into one compile command
  set resp_file_order 1

  ## Open output file to write
  if { [catch {open $outfile w} result] } {
    puts stderr "ERROR: Could not open $outfile for writing\n$result"
    set rc 1
    return $rc
  } else {
    set sg_fh $result
    puts "INFO: Writing Spyglass compile script to file $outfile"
  }


  exec rm -rf vc_setup
  exec mkdir vc_setup
  ## Open output file to write tcl file for VC-SpyGlass
  if { [catch {open vc_setup/vc_setup.tcl w} vcresult] } {
    puts stderr "ERROR: Could not open vc_setup.tcl for writing\n$vcresult"
    set rcv 1
    return $rcv
  } else {
    set vcsg_fh $vcresult
    puts "INFO: Writing Spyglass compile script to file $outfile"
  }


## writing vcs options for verilog filelist
 if { [catch {open vc_setup/vcs_opts_vlog.f w} result1] } {
    puts stderr "ERROR: Could not open vcs_opts_vlog.f for writing\n$result1"
    set rc1 1
    return $rc1
  } else {
    set vcsg_fh1 $result1
    puts "INFO: Writing Spyglass compile script to file vcs_opts_vlog.f"
  }

  puts $vcsg_fh1 "-sv=2005 -assert svaext"
  puts $vcsg_fh1 "-error=noMPD"
  puts $vcsg_fh1 "+libext+.v"
  puts $vcsg_fh1 "+libext+.sv"
  puts $vcsg_fh1 "+libext+.vhd"
  puts $vcsg_fh1 "+libext+.vh"
  puts $vcsg_fh1 "-Xspyglass_pragma=synopsys"
  puts $vcsg_fh1 "-Xspyglass_pragma=synthesis"
  puts $vcsg_fh1 "-p1800_macro_expansion -Xspyglass=0x10000"
  close $vcsg_fh1

## writing vcs options for vhdl filelist
if { [catch {open vc_setup/vcs_opts_vhdl.f w} result2] } {
    puts stderr "ERROR: Could not open vcs_opts_vhdl.f for writing\n$result2"
    set rc2 1
    return $rc2
  } else {
    set vcsg_fh2 $result2
    puts "INFO: Writing Spyglass compile script to file vcs_opts_vhdl.f"
  }

  puts $vcsg_fh2 "-skip_translate_body=synopsys -Xspyglass_pragma=synopsys -skip_translate_body=synthesis -Xspyglass_pragma=synthesis"
  close $vcsg_fh2


# ------------------------
# ALOKE: Create a list of sgdc files for each blk_mem_gen blackbox found
# ------------------------
  set sgdc_file_list ""

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

  set arch_name [get_property ARCHITECTURE [get_parts [get_property PART [current_project]]]]
# ------------------------------------------------------------------------
# ALOKE 3/17/2016: In some initial version, synth_fileset variable was used. 
#       Now this is not used any more. Commenting out the following lines
# ------------------------------------------------------------------------
# ## Identify synthesis fileset
# set synth_fileset [lindex [get_filesets * -filter {FILESET_TYPE == "DesignSrcs"}] 0]
# if {[string match $synth_fileset ""]} {
#   puts stderr "ERROR: Could not find any synthesis fileset"
#   set rc 5
#   return $rc
# } else {
#   puts "INFO: Found synthesis fileset $synth_fileset"
# }
# update_compile_order -fileset $synth_fileset
  
  ###### Read in Xilinx lib cells 
  ###### Lists the unisim and unimacro library files related to a Vivado release
  puts $sg_fh "read_file -type verilog $vivado_dir/data/verilog/src/glbl.v\n"
  puts $sg_fh "set_option lib unisim ./unisim"
  puts $sg_fh "set_option lib unimacro ./unimacro"
  puts $sg_fh "set_option y $vivado_dir/data/verilog/src/retarget"
  puts $sg_fh "set_option y $vivado_dir/data/verilog/src/xeclib"
  puts $sg_fh "set_option y $vivado_dir/data/verilog/src/unimacro"

  puts $sg_fh "set_option libhdlfiles unisim   $vivado_dir/data/vhdl/src/unisims/unisim_retarget_VCOMP.vhd"
  puts $sg_fh "set_option libhdlfiles unimacro $vivado_dir/data/vhdl/src/unimacro/unimacro_VCOMP.vhd\n"

  puts $sg_fh "read_file -type verilog $vivado_dir/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" 
  puts $sg_fh "read_file -type verilog $vivado_dir/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" 
  puts $sg_fh "read_file -type verilog $vivado_dir/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv\n" 
  
  puts $sg_fh "set_option lib xpm xpm"
  puts $sg_fh "set_option libhdlfiles xpm $vivado_dir/data/ip/xpm/xpm_VCOMP.vhd\n"

  puts $vcsg_fh "set vivado_path \$env\(XILINX_VIVADO)\n"
  puts $vcsg_fh "#### Common application variables"
  puts $vcsg_fh "#### To run LINT App"
  puts $vcsg_fh "#set_app_var enable_lint true"
  puts $vcsg_fh "#configure_lint_setup -goal lint_rtl\n"
  
  puts $vcsg_fh "#### To run CDC App"
  puts $vcsg_fh "set_app_var enable_cdc true\n"
  
  puts $vcsg_fh "#### To run RDC App"
  puts $vcsg_fh "#set_app_var enable_rdc true\n"
  puts $vcsg_fh "## Enable to treat design const x as 0 "
  puts $vcsg_fh "set_app_var use_design_x_as_0 true \n"
  puts $vcsg_fh "## Disable the below settings to not consider //synopsys translate_off and //synopsys translate_on by default."
  puts $vcsg_fh "set_app_var analyze_skip_translate_body false \n"
  
  puts $vcsg_fh "## Xilinx Library Files -- Common to all Xilinx designs "
  puts $vcsg_fh "define_design_lib unisim -path unisim/VCS "
  puts $vcsg_fh "define_design_lib secureip -path secureip/VCS "
  puts $vcsg_fh "define_design_lib unimacro -path unimacro/VCS"
  puts $vcsg_fh "define_design_lib xpm -path xpm/VCS "
  puts $vcsg_fh "define_design_lib WORK -path WORK/VCS "
 
  set axil $::env(XILINX_VIVADO)
  regsub -all {/} $axil {\/} axil

  exec cp $::env(XILINX_VIVADO)/data/vhdl/src/unisims/primitive/vhdl_analyze_order vc_setup/unisim_primitive.f
  exec cp $::env(XILINX_VIVADO)/data/vhdl/src/unisims/retarget/vhdl_analyze_order vc_setup/unisim_retarget.f
  exec find $::env(XILINX_VIVADO)/data/vhdl/src/unisims/secureip/ -name "*.vhd" > vc_setup/unisim_secureip.f 
  exec cp $::env(XILINX_VIVADO)/data/vhdl/src/unimacro/vhdl_analyze_order vc_setup/unimacro_libs.f
 
  exec rm -rf temp_script_spy.csh
  exec echo "sed -i 's/^/$axil\\/data\\/vhdl\\/src\\/unisims\\/primitive\\//g' vc_setup/unisim_primitive.f " > temp_script_spy.csh
  exec echo "sed -i 's/^/$axil\\/data\\/vhdl\\/src\\/unisims\\/retarget\\//g' vc_setup/unisim_retarget.f " >> temp_script_spy.csh
  exec echo "sed -i 's/^/$axil\\/data\\/vhdl\\/src\\/unimacro\\//g' vc_setup/unimacro_libs.f " >> temp_script_spy.csh
  exec csh temp_script_spy.csh
  exec rm -rf temp_script_spy.csh

  puts $vcsg_fh "analyze -f vhdl \" \$vivado_path/data/vhdl/src/unisims/unisim_retarget_VCOMP.vhd \$vivado_path/data/vhdl/src/unisims/unisim_VPKG.vhd \" -work unisim "
  puts $vcsg_fh "analyze -f vhdl \" -f unisim_primitive.f \" -work unisim -vcs { -f vcs_opts_vhdl.f } "
  puts $vcsg_fh "analyze -f vhdl \" -f unisim_retarget.f \" -work unisim -vcs { -f vcs_opts_vhdl.f } "
  puts $vcsg_fh "analyze -f vhdl \" -f unisim_secureip.f \" -work secureip -vcs { -f vcs_opts_vhdl.f } "
  puts $vcsg_fh "analyze -f vhdl \" -f unimacro_libs.f \" -work unimacro -vcs { -f vcs_opts_vhdl.f } "
  
  puts $vcsg_fh "analyze -f vhdl \" \$vivado_path/data/ip/xpm/xpm_VCOMP.vhd \" -work xpm -vcs {  -f vcs_opts_vhdl.f } "

  puts $vcsg_fh "analyze -format verilog \" \$vivado_path/data/verilog/src/glbl.v \$vivado_path/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv \$vivado_path/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv \$vivado_path/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv \" -vcs { -work WORK -f vcs_opts_vlog.f } \n"
  puts $vcsg_fh "## Design RTL ## "
 
  set part [get_parts -of_objects [get_projects]]
  set lib_dir_path $vivado_dir/data/parts/xilinx/$arch_name/public/liberty
  set arch_name_pt $arch_name\_pt
  puts $part
  puts $lib_dir_path
  puts $arch_name_pt

	if {[regexp $arch_name {[artix7*|kintex7*|virtex7*|zynq*|spartan7*]} ]} {
		puts $sg_fh "read_file -type gateslib $vivado_dir/data/parts/xilinx/$arch_name/public/liberty/$arch_name\_pt.lib\n"

	} elseif {[regexp $arch_name {kintexu*|kintexuplus*|virtexu*|virtexuplus*|virtexuplusHBM*|zynquplus*|zynquplusRFSOC*} ]} {
		set README_path $lib_dir_path\/README
		puts $README_path

		if { [file exists $README_path] == 1} {
			set fh [open "$README_path" r]
			set file_data [read $fh]
			close $fh

			set data [split $file_data "\n"]
		
			foreach line $data {
				if {[regexp ($part)\t[ ](.*) $line key dev_name lib_name]} {
				puts "$dev_name : $lib_name"
				puts "$lib_name"
				}
			} 

			proc remove_blank_using_list s {join [split $s " "] ""}
		
			set lib_name1 [remove_blank_using_list $lib_name]
			set library_path $lib_dir_path/$lib_name1
		
			puts $sg_fh "read_file -type gateslib $library_path\n"

		} else {
			puts "README file does not exists !!!!!"
			puts "Not dumping the library file into the .prj file. Please include it manually by the command mentioned below !!!!!"
			puts "read_file -type gateslib #library_path\n"
		
		}

	} else {
		puts "Spyglass do not have support for the selected device family!!!!"
		puts "Not dumping the library file into the .prj file. Please include it manually by the command mentioned below !!!!!"
		puts "read_file -type gateslib #library_path\n"
	}


	
  ## Blackbox unisims - get_lib_cells appears to work only in certain context so commenting it out
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
  array set black_box_libs {}

  ## Set black-boxes for blk_mem_gen if they are part of the IP
  foreach ip $ips {
    set ip_ref [get_property IPDEF $ip]
    regsub {xilinx.com:ip:} $ip_ref {} ip_name
    regsub {:} $ip_name {_v} ip_name
    regsub {\.} $ip_name {_} ip_name

    if {[regexp {xilinx.com:ip:blk_mem_gen:} $ip_ref]} {
      set black_box_libs($ip_name) 1
    }
  }


  set num_files 0
  set enableSV "no"
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
      set files [get_files  -norecurse -compile_order sources -used_in synthesis]
      puts "INFO: Collecting files for Top level"
    }

    set lib_file_order []
    array set lib_file_array {}
    array set lib_file_lang  {}


    set prev_lib ""
    set num_lib 0
    ## Find all files
    foreach f $files {
      #set f1 [lindex [get_files -of [get_filesets $synth_fileset] $f] 0]
      incr num_files
      set fn [get_property NAME [lindex [get_files -all  $f] 0]]
      set ft [get_property FILE_TYPE [lindex [get_files -all  $f] 0]]
      set fs [get_property FILESET_NAME [lindex [get_files -all $f] 0]]
      set lib [get_property LIBRARY [lindex [get_files -all  $f] 0]]

      puts "INFO: File= $fn Library= $lib File_type= $ft Fileset= $fs"
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
        if {[string match $ft "SystemVerilog"]} {
          set enableSV "yes"
        }
      }

      set lib_file_lang($lib) $ft
      regsub ":.*" $lib {} prev_lib
    }

    # For each library, list the files
    foreach lib $lib_file_order {
      if {![info exists compiled_lib_list($lib)] || [matches_default_libs $lib]} {
        puts "INFO: Obtaining list of files for design= $ip_ref, library= $lib"
        set lang $lib_file_lang($lib)
        set incdirs [list ]
        array set incdir_ar {}
        if {[regexp {Verilog} $lang]} {
          foreach f [split $lib_file_array($lib)] {
            set is_include [get_property IS_GLOBAL_INCLUDE [lindex [get_files -all  $f] 0]]
            set ft [get_property FILE_TYPE [lindex [get_files -all  $f] 0]]
            if {$is_include == 1 || [string match $ft "Verilog Header"]} {
              set file_dir [file dirname $f]
              if {![info exists incdir_ar($file_dir)]} {
                lappend incdirs $file_dir
                puts "INFO: Found include file $f"
                set incdir_ar($file_dir) 1
              }
            }
          }
          if {![string match $incdirs ""]} {
            puts $sg_fh "set_option incdir {$incdirs}"
            exec echo "+incdir+$incdirs" >> vc_setup/vcs_opts_vlog.f
          }
        }
        regsub ":.*" $lib {} lib_no_num

# --------------------------------------------
# ALOKE: Create the sgdc file for blk_mem_gen
# --------------------------------------------
#        if {[regexp {^blk_mem_gen_v\d+_\d+.*$} $lib_no_num] } {
#           set sgdc_file "$lib_no_num.sgdc"
#           if { [catch {open $sgdc_file w} result] } {
#              puts stderr "ERROR: Could not open $sgdc_file for writing\n$result"
#              set rc 1
#              return $rc
#           } else {
#              set sg_sgdc_fh $result
#              puts "INFO: Writing blk_mem_gen constraints to file $sgdc_file"
#              puts $sg_sgdc_fh "current_design $top_module"
#              puts $sg_sgdc_fh "abstract_port -module $lib_no_num -ports douta[0:17] -clock clka"
#              puts $sg_sgdc_fh "abstract_port -module $lib_no_num -ports doutb[0:17] -clock clkb"
#            close $sg_sgdc_fh
#          }
#          lappend sgdc_file_list $sgdc_file
#        }
#
        if {[string match $lang "VHDL"]} {
          if {![regexp {^blk_mem_gen_v\d+_\d+.*$} $lib] } {
            puts $sg_fh "set_option lib $lib_no_num $lib_no_num"
            puts $sg_fh "set_option libhdlfiles $lib_no_num { \\"
          foreach f [split $lib_file_array($lib)] {
            set f_type [get_property FILE_TYPE [lindex [get_files -all  $f] 0]]
            if {[string match $f_type "VHDL"]} {
              if {![regexp {^blk_mem_gen_v\d+_\d+$} $lib] || ([regexp {^blk_mem_gen_v\d+_\d+$} $lib] && [regexp {/blk_mem_gen_v\d+_\d+\.v} $f]) } {
                puts $sg_fh "  $f \\"
                  if {[string match $lib_no_num xil_defaultlib]} {
                     if { ![regexp {^.*blk_mem_gen_\d+_\d+.*$} $f] } {
                        puts $vcsg_fh "analyze -f vhdl \" $f \" -work WORK -vcs {  -f vcs_opts_vhdl.f } "
                     } 
                  } else {
                     puts $vcsg_fh "define_design_lib $lib_no_num -path $lib_no_num/VCS"
                     puts $vcsg_fh "analyze -f vhdl \" $f \" -work $lib_no_num -vcs {  -f vcs_opts_vhdl.f } "
                  } 
              }
            }
          }
            puts $sg_fh "}\n"
            }
        } elseif {[string match $lang "Verilog"] || [string match $lang "SystemVerilog"]} {
#_satrajit          puts $sg_fh "read_file -type verilog { \\"
          foreach f [split $lib_file_array($lib)] {
            set f_type [get_property FILE_TYPE [lindex [get_files -all  $f] 0]]
            if {[string match $f_type "Verilog"] || [string match $f_type "SystemVerilog"]} {
              if {![regexp {^blk_mem_gen_v\d+_\d+$} $lib] || ([regexp {^blk_mem_gen_v\d+_\d+$} $lib] && [regexp {/blk_mem_gen_v\d+_\d+\.v} $f]) } {
                puts $sg_fh "read_file -type verilog $f "
                puts $vcsg_fh "analyze -f verilog \" $f \" -vcs {  -f vcs_opts_vlog.f } "
              }
            }
          }
#_satrajit          puts $sg_fh "}\n"
        }
      } else {
        puts "INFO: Library $lib has already been compiled. Skipping it."
      }
    }

    ## Bookkeeping on which libraries are already compiled
    foreach lib $lib_file_order {
      #if {![matches_default_libs $lib]} {
        set compiled_lib_list($lib) 1
      #}
    }

    ## Set black-boxes for blk_mem_gen if they are sub-cores
    foreach subcore $lib_file_order {
      if {![info exists black_box_libs($subcore)]} {
        if {[regexp {^blk_mem_gen_v\d+_\d+} $subcore]} {
          regsub ":.*" $subcore {} subcore_no_num
          set black_box_libs($subcore_no_num) 1
        }
      }
    }
    puts $sg_fh ""
    puts $vcsg_fh ""

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

  set bb_list [array names black_box_libs]
  if {$bb_list != ""} {
    foreach bb $bb_list {
      puts $sg_fh "set_option stop $bb\*"
      puts $vcsg_fh "set_blackbox -designs { $bb }"
    }
  }

  puts $sg_fh "set_option stop {BRAM_TDP_MACRO}"
  puts $sg_fh "set_option enable_save_restore no"
  puts $sg_fh "set_option enable_pass_exit_codes true"
  puts $sg_fh "set_option projectwdir $sg_run_dir"
  puts $sg_fh "set_option libext { .v .sv .vhd .vh }"
  puts $sg_fh "set_option work WORK"
  puts $sg_fh "set_option enableSV yes"
  puts $sg_fh "set_option language_mode mixed"
  puts $sg_fh "#set_option sort yes"
  puts $sg_fh "set_option pragma { synopsys synthesis }"
  puts $sg_fh "set_option disable_hdllibdu_lexical_checks yes"
  puts $sg_fh "set_option top $top_module"
  puts $sg_fh "#set_option prefer_tech_lib yes"
  puts $sg_fh "set_option enable_auto_infer_bus_pins yes"
  puts $sg_fh "set_option read_protected_envelope yes"
  puts $sg_fh "set_option enable_fpga yes\n\n"
  puts $sg_fh "current_methodology \$SPYGLASS_HOME/GuideWare/latest/block/rtl_handoff\n"
  puts $sg_fh "current_goal cdc/cdc_setup"
  puts $sg_fh "set_goal_option addrules Setup_blackbox01"
  puts $sg_fh "set_parameter  force_genclk_for_txv  1\n"

  puts $sg_fh "current_goal cdc/cdc_verify_struct"
  puts $sg_fh "set_parameter  force_genclk_for_txv  1\n"

  if {[llength $sgdc_file_list] != 0} {
    puts $sg_fh "read_file -type sgdc { \\"
    foreach sgdc_file $sgdc_file_list {
      puts $sg_fh "    $sgdc_file \\"
    }
    puts $sg_fh "}\n"  
  }
  
  puts $vcsg_fh "set_blackbox -designs { BRAM_TDP_MACRO }\n"
  puts $vcsg_fh "## IPs in the design : $ips "
  puts $vcsg_fh "elaborate $top_module -vcs { -liblist_work -liblist_nocelldiff }\n"
  puts $vcsg_fh "#### Reading SDC file"
  puts $vcsg_fh "#read_sdc <sdc_file>\n"
  puts $vcsg_fh "# Example - "
  puts $vcsg_fh "# read_sdc design.sdc\n"
##puts $vcsg_fh "## Define clock and reset constraints"
##puts $vcsg_fh "#create_clock -name <clock_logical_name> -period <period_value> {<design_object>}"
##puts $vcsg_fh "#create_clock -name CLK1 -period 10 {clk1}"
##puts $vcsg_fh "#set_clock_group -async -group { <clock_list> } -group { <clock_list> }"
##puts $vcsg_fh "#create_reset {<design_object>} -sense low -async\n"
  puts $vcsg_fh "#### Read Blackbox modeling constraint file "
  puts $vcsg_fh "#read_sdc InferredCdcAttr_<blackbox-module>.tcl \n"
  puts $vcsg_fh "#### Perform CDC checks"
  puts $vcsg_fh "## To perform the setup checks only for blackbox modeling"
  puts $vcsg_fh "#check_cdc -type setup "
  puts $vcsg_fh "## To perform complete CDC structural checks"
  puts $vcsg_fh "#check_lint"
  puts $vcsg_fh "check_cdc"
  puts $vcsg_fh "#check_rdc\n"
  puts $vcsg_fh "#### Report Generation"
  puts $vcsg_fh "#report_lint -verbose -limit 0 -file report_lint_verbose_limit_0.log"
  puts $vcsg_fh "report_cdc -verbose -limit 0 -file report_cdc_verbose_limit_0.log"
  puts $vcsg_fh "#report_rdc -verbose -limit 0 -file report_rdc_verbose_limit_0.log\n"
  puts $vcsg_fh "waive_violation -app {lint cdc rdc design} -filter \"FileName =~ \*unisims/primitive\* OR FileName =~ \*unisims/secureip\* OR FileName =~ \*data/ip/xpm\* OR FileName =~ \*data/verilog/src\* OR FileName =~ \*data/vhdl/src/unimacro\* \" -add waive_xilinx_primitive_cells_viols"

  close $sg_fh
  close $vcsg_fh
  return $rc
}
