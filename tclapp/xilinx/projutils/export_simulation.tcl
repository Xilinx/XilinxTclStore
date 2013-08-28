####################################################################################################
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# 
# Date Created     :  07/12/2013
# Script name      :  export_simulation.tcl
# Procedures       :  export_simulation
# Tool Version     :  Vivado 2013.3
# Description      :  Export simulation script file for compiling the design for the target simulator
#
# Command help     :  export_simulation -help
#
# Revision History :
#   07/12/2013 1.0  - Initial version (export_simulation)
#
####################################################################################################

# title: Vivado Export Simulation Tcl Script
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::projutils {

  # Generate simulation file(s) for the target simulator
  namespace export export_simulation
}

namespace eval ::tclapp::xilinx::projutils {

    proc export_simulation {args} {

        # Summary:
        # Export a script and associated data files (if any) for driving standalone simulation using the specified simulator 

        # Argument Usage:
        # [-of_objects <name>]: Export simulation file(s) for the specified object
        # [-relative_to <dir>]: Make all file paths relative to the specified directory
        # [-compiled_lib_path <dir>]: Precompiled simulation library directory path. If not specified, then please follow the instructions in the generated script header to manually provide the simulation library mapping information.
        # [-script_name <name>]: Output shell script filename. If not specified, then file with a default name will be created with .sh extension.
        # [-32bit]: Perform 32bit compilation
        # [-force]: Overwrite previous files
        # -dir <name>: Directory where the simulation file(s) are exported
        # -simulator <name>: Simulator for which simulation files will be exported (<name>: ies|vcs_mx)

        # Return Value:
        # true (0) if success, false (1) otherwise

        variable a_xport_sim_vars
        variable l_valid_simulator_types

        reset_global_sim_vars

        set options [split $args " "]
        # these options are must
        if {[lsearch $options {-simulator}] == -1} {
          send_msg_id Vivado-projutils-013 ERROR "Missing option '-simulator', please type 'export_simulation -help' for usage info.\n"
          return 1
        }
        if {[lsearch $options {-dir}] == -1} {
          send_msg_id Vivado-projutils-039 ERROR "Missing option '-dir', please type 'export_simulation -help' for usage info.\n"
          return 1
        }

        # process options
        for {set i 0} {$i < [llength $args]} {incr i} {
          set option [string trim [lindex $args $i]]
          switch -regexp -- $option {
            "-of_objects"               { incr i;set a_xport_sim_vars(sp_tcl_obj) [lindex $args $i] }
            "-32bit"                    { set a_xport_sim_vars(b_32bit) 1 }
            "-relative_to"              { incr i;set a_xport_sim_vars(s_relative_to) [lindex $args $i] }
            "-compiled_lib_path"        { incr i;set a_xport_sim_vars(s_compiled_lib_path) [lindex $args $i] }
            "-script_name"              { incr i;set a_xport_sim_vars(s_script_filename) [lindex $args $i] }
            "-force"                    { set a_xport_sim_vars(b_overwrite) 1 }
            "-simulator"                { incr i;set a_xport_sim_vars(s_simulator) [lindex $args $i] }
            "-dir"                      { incr i;set a_xport_sim_vars(s_out_dir) [lindex $args $i] }
            default {
              # is incorrect switch specified?
              if { [regexp {^-} $option] } {
                send_msg_id Vivado-projutils-014 ERROR "Unknown option '$option', please type 'export_simulation -help' for usage info.\n"
                return 1
              }
            }
          }
        }

        # is project open?
        set a_xport_sim_vars(s_project_name) [get_property name [current_project]]
        set a_xport_sim_vars(s_project_dir) [get_property directory [current_project]]

        # is valid simulator specified?
        if { [lsearch -exact $l_valid_simulator_types $a_xport_sim_vars(s_simulator)] == -1 } {
          send_msg_id Vivado-projutils-015 ERROR \
            "Invalid simulator type specified. Please type 'export_simulation -help' for usage info.\n"
          return 1
        }

        # is valid relative_to set?
        if { [lsearch $options {-relative_to}] != -1} {
          set relative_file_path $a_xport_sim_vars(s_relative_to)
          if { ![file exists $relative_file_path] } {
            send_msg_id Vivado-projutils-037 ERROR \
              "Invalid relative path specified! Path does not exist:$a_xport_sim_vars(s_relative_to)\n"
            return 1
          }
        }

        # is valid tcl obj specified?
        if { ([lsearch $options {-of_objects}] != -1) && ([llength $a_xport_sim_vars(sp_tcl_obj)] == 0) } {
          send_msg_id Vivado-projutils-038 ERROR "Invalid object specified. The object does not exist.\n"
          return 1
        }
 
        # set pretty name
        if { [set_simulator_name] } {
          return 1
        }

        # is managed project?
        set a_xport_sim_vars(b_is_managed) [get_property managed_ip [current_project]]

        # setup run dir
        if { [create_sim_files_dir] } {
          return 1
        }
  
        # set default object if not specified, bail out if no object found
        if { [set_default_tcl_obj] } {
          return 1
        }

        # write script
        if { [write_sim_script] } {
          return 1
        }
      
        # TCL_OK
        return 0
    }
}

namespace eval ::tclapp::xilinx::projutils {

    #
    # export_simulation tcl script argument & file handle vars
    #
    variable a_xport_sim_vars
    variable l_compile_order_files [list]

    variable l_valid_simulator_types [list]
    set l_valid_simulator_types [list ies vcs_mx]

    variable l_valid_ip_extns [list]
    set l_valid_ip_extns [list ".xci" ".bd" ".slx"]

    variable s_data_files_filter
    set s_data_files_filter "FILE_TYPE == \"Data Files\" || FILE_TYPE == \"Memory Initialization Files\" || FILE_TYPE == \"Coefficient Files\""

    proc reset_global_sim_vars {} {

        # Summary: initializes global namespace simulation vars
        # This helper command is used to reset the simulation variables used in the script.

        # Argument Usage:
        # none

        # Return Value:
        # None

        variable a_xport_sim_vars

        set a_xport_sim_vars(s_simulator)         ""
        set a_xport_sim_vars(s_simulator_name)    ""
        set a_xport_sim_vars(s_compiled_lib_path) ""
        set a_xport_sim_vars(s_script_filename)   ""
        set a_xport_sim_vars(s_script_extn)       "sh"
        set a_xport_sim_vars(s_out_dir)           ""
        set a_xport_sim_vars(b_32bit)             0
        set a_xport_sim_vars(s_relative_to)       ""             
        set a_xport_sim_vars(b_overwrite)         0
        set a_xport_sim_vars(sp_tcl_obj)          ""
        set a_xport_sim_vars(s_sim_top)           ""
        set a_xport_sim_vars(s_project_name)      ""
        set a_xport_sim_vars(s_project_dir)       ""
        set a_xport_sim_vars(b_is_managed)        0 

        set l_compile_order_files               [list]

    }

    proc set_default_tcl_obj {} {
 
        # Summary: If -of_objects not specified, then for managed-ip project error out
        #          or set active simulation fileset for an RTL/GateLvl project
 
        # Argument Usage:
        # none
 
        # Return Value:
        # true (0) if success, false (1) otherwise
 
        variable a_xport_sim_vars
        set tcl_obj $a_xport_sim_vars(sp_tcl_obj)
        if { [string length $tcl_obj] == 0 } {
          if { $a_xport_sim_vars(b_is_managed) } {
            set ips [get_ips]
            if {[llength $ips] == 0} {
              send_msg_id Vivado-projutils-016 INFO "No IP's found in the current project.\n"
              return 1
            }
            # object not specified, error
            send_msg_id Vivado-projutils-035 ERROR "No IP source object specified. Please type 'export_simulation -help' for usage info.\n"
            return 1
          } else {
            set curr_simset [current_fileset -simset]
            set sim_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_filesets $curr_simset]]
            if { [llength $sim_files] == 0 } {
              send_msg_id Vivado-projutils-017 INFO "No simulation files found in the current simset.\n"
              return 1
            }
            set a_xport_sim_vars(sp_tcl_obj) $curr_simset
          }
        } else {
          # is valid tcl object?
          if { ![is_ip $tcl_obj] } {
            if { [is_fileset $tcl_obj] } {
              set fs_type [get_property fileset_type [get_filesets $tcl_obj]]
              if { [string equal -nocase $fs_type "Constrs"] } {
                send_msg_id Vivado-projutils-034 ERROR "Invalid object type specified\n"
                return 1
              }
            }
          } else {
            set ip_file ""
            # is ip object? fetch associated file, else just return file
            if {[regexp -nocase {^ip} [get_property [rdi::get_attr_specs CLASS -object $tcl_obj] $tcl_obj]] } {
              set ip_file [get_files -all -quiet [get_property ip_file $tcl_obj]]
            } else {
              set ip_file [get_files -all -quiet $tcl_obj]
            }
            set ip_obj_count [llength $ip_file]
            if { $ip_obj_count == 0 } {
              send_msg_id Vivado-projutils-009 ERROR "The specified object could not be found in the project:$tcl_obj\n"
              return 1
            } elseif { $ip_obj_count > 1 } {
              send_msg_id Vivado-projutils-019 ERROR "The script expects exactly one object got $ip_obj_count\n"
              return 1
            }
            # is IP locked?
            if { [get_property is_locked $ip_file] == 1} {
              send_msg_id Vivado-projutils-041 WARNING "The specified object is locked:$tcl_obj\n"
            }
            set a_xport_sim_vars(sp_tcl_obj) $ip_file
          }
        }
        return 0
    }
 
    proc write_sim_script {} {
 
        # Summary: Get the compiled order for the specified source object and export files
 
        # Argument Usage:
        # none
 
        # Return Value:
        # true (0) if success, false (1) otherwise
 
        variable a_xport_sim_vars
 
        set tcl_obj $a_xport_sim_vars(sp_tcl_obj)
        if { [is_ip $tcl_obj] } {
          set a_xport_sim_vars(s_sim_top) [file tail [file root $tcl_obj]]
          send_msg_id Vivado-projutils-042 INFO "Inspecting IP design source files for '$a_xport_sim_vars(s_sim_top)'...\n"
          if {[export_sim_files_for_ip $tcl_obj]} {
            return 1
          }
        } elseif { [is_fileset $tcl_obj] } {
          set a_xport_sim_vars(s_sim_top) [get_property top [get_filesets $tcl_obj]]
          send_msg_id Vivado-projutils-008 INFO "Inspecting design source files for '$a_xport_sim_vars(s_sim_top)' in fileset '$tcl_obj'...\n"
          if {[string length $a_xport_sim_vars(s_sim_top)] == 0} {
            set a_xport_sim_vars(s_sim_top) "unknown"
          }
          if {[export_sim_files_for_fs $tcl_obj]} {
            return 1
          }
        } else {
          send_msg_id Vivado-projutils-020 INFO "Unsupported object source: $tcl_obj\n"
          return 1
        }
        send_msg_id Vivado-projutils-021 INFO \
          "File '$a_xport_sim_vars(s_script_filename)' exported (file path:$a_xport_sim_vars(s_out_dir)/$a_xport_sim_vars(s_script_filename))\n"
 
        return 0
    }
 
    proc export_sim_files_for_ip { tcl_obj } {
 
        # Summary: 
 
        # Argument Usage:
        # source object
 
        # Return Value:
        # true (0) if success, false (1) otherwise
      
        variable a_xport_sim_vars
        variable s_data_files_filter
        variable l_compile_order_files
  
        set obj_name [file root [file tail $tcl_obj]]
        set ip_filename [file tail $tcl_obj]
        set l_compile_order_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_filename]]
        print_source_info

        if { {} == $a_xport_sim_vars(s_script_filename) } {
          set simulator $a_xport_sim_vars(s_simulator)
          set ip_name [file root $ip_filename]
          set a_xport_sim_vars(s_script_filename) "${ip_name}_sim_${simulator}.$a_xport_sim_vars(s_script_extn)"
        }
 
        if {[export_simulation_for_object $obj_name]} {
          return 1
        }
 
        # fetch ip data files and export to output dir
        set data_files [get_files -all -quiet -of_objects [get_files -quiet *$ip_filename] -filter $s_data_files_filter]
        export_data_files $data_files
 
        return 0
    }
 
    proc export_sim_files_for_fs { tcl_obj } {
 
        # Summary: 
 
        # Argument Usage:
        # source object
 
        # Return Value:
        # true (0) if success, false (1) otherwise
        
        variable a_xport_sim_vars
        variable l_compile_order_files
  
        set obj_name $tcl_obj
        set used_in_val "simulation"
        switch [get_property fileset_type [get_filesets $tcl_obj]] {
          "DesignSrcs"     { set used_in_val "synthesis" }
          "SimulationSrcs" { set used_in_val "simulation"}
          "BlockSrcs"      { set used_in_val "synthesis" }
        }
 
        set l_compile_order_files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $tcl_obj]]
        if { [llength $l_compile_order_files] == 0 } {
          send_msg_id Vivado-projutils-018 INFO "Empty fileset: $obj_name\n"
          return 1
        } else {
          print_source_info
          if { {} == $a_xport_sim_vars(s_script_filename) } {
            set simulator $a_xport_sim_vars(s_simulator)
            set a_xport_sim_vars(s_script_filename) "$a_xport_sim_vars(s_sim_top)_sim_${simulator}.$a_xport_sim_vars(s_script_extn)"
          }

          if {[export_simulation_for_object $obj_name]} {
            return 1
          }
 
          # fetch data files for all IP's in simset and export to output dir
          export_fs_data_files
        }
  
        return 0
    }
 
    proc is_ip { tcl_obj } {
 
        # Summary: Determine if specified source object is IP
 
        # Argument Usage:
        # source object
 
        # Return Value:
        # true (1) if specified object is an IP, false (0) otherwise
       
        variable l_valid_ip_extns 

        # check if ip file extension
        if { [lsearch -exact $l_valid_ip_extns [file extension $tcl_obj]] >= 0 } {
          return 1
        } else {
          # check if IP object
          if {[regexp -nocase {^ip} [get_property [rdi::get_attr_specs CLASS -object $tcl_obj] $tcl_obj]] } {
            return 1
          }
        }
        return 0
    }

    proc is_fileset { tcl_obj } {
 
        # Summary: Determine if specified tcl source object is fileset
 
        # Argument Usage:
        # source object
 
        # Return Value:
        # true (1) if specified object is a fileset, false (0) otherwise

        if {[regexp -nocase {^fileset_type} [rdi::get_attr_specs -quiet -object $tcl_obj -regexp .*FILESET_TYPE.*]]} {
          return 1
        }
 
        return 0
    }

    proc print_source_info {} {

        # Summary: Print sources information on the console
 
        # Argument Usage:
        # none
 
        # Return Value:
        # None
 
        variable l_compile_order_files
 
        set n_total_srcs [llength $l_compile_order_files]
        set n_vhdl_srcs     0
        set n_verilog_srcs  0
        
        foreach file $l_compile_order_files {
          set file_type [get_property file_type [get_files -quiet -all $file]]
          switch -- $file_type {
            {VHDL}    { incr n_vhdl_srcs    }
            {Verilog} { incr n_verilog_srcs }
          }
        }

        send_msg_id Vivado-projutils-4 INFO "Total number of design source files found = $n_total_srcs\n"
        if { $n_vhdl_srcs > 0    } { send_msg_id Vivado-projutils-5 INFO " Number of VHDL files    = $n_vhdl_srcs\n" }
        if { $n_verilog_srcs > 0 } { send_msg_id Vivado-projutils-6 INFO " Number of Verilog files = $n_verilog_srcs\n" }

    }
 
    proc set_simulator_name {} {
 
        # Summary: Set simulator name for the specified simulator type
 
        # Argument Usage:
        # none
 
        # Return Value:
        # True (0) if name set, false (1) otherwise
 
        variable a_xport_sim_vars
        set simulator $a_xport_sim_vars(s_simulator)
        switch -regexp -- $simulator {
          "ies"       { set a_xport_sim_vars(s_simulator_name) "Cadence Incisive Enterprise" }
          "vcs_mx"    { set a_xport_sim_vars(s_simulator_name) "Synopsys VCS MX" }
          default {
            send_msg_id Vivado-projutils-026 ERROR "Invalid simulator ($simulator)\n"
            close $fh
            return 1
          }
        }
        return 0
    }
 
    proc create_sim_files_dir {} {
 
        # Summary: Create output directory where simulation files will be generated. Delete previous
        #          files if overwrite requested (-force)
 
        # Argument Usage:
        # none
 
        # Return Value:
        # true (0) if success, false (1) otherwise
 
        variable a_xport_sim_vars
 
        if { [string length $a_xport_sim_vars(s_out_dir)] == 0 } {
          send_msg_id Vivado-projutils-036 ERROR "Missing directory value. Please specify the output directory path for the exported files.\n"
          return 1
        }
 
        set dir [file normalize [string map {\\ /} $a_xport_sim_vars(s_out_dir)]]
        if { ! [file exists $dir] } {
          if {[catch {file mkdir $dir} error_msg] } {
            send_msg_id Vivado-projutils-023 ERROR "failed to create the directory ($dir): $error_msg\n"
            return 1
          }
        }
        set a_xport_sim_vars(s_out_dir) $dir
        return 0
    }
 
    proc export_simulation_for_object { obj_name } {
 
        # Summary: Open files and write compile order for the target simulator
 
        # Argument Usage:
        # obj_name - source object
 
        # Return Value:
        # true (0) if success, false (1) otherwise
 
        variable a_xport_sim_vars
        
        set file [file normalize [file join $a_xport_sim_vars(s_out_dir) $a_xport_sim_vars(s_script_filename)]]
 
  	    # recommend -force if file exists
  	    if { [file exists $file] && (!$a_xport_sim_vars(b_overwrite)) } {
          send_msg_id Vivado-projutils-032 ERROR "Simulation file '$file' already exist. Use -force option to overwrite."
  	      return 1
  	    }
          
        if { [file exists $file] } {
          if {[catch {file delete -force $file} error_msg] } {
            send_msg_id Vivado-projutils-033 ERROR "failed to delete file ($file): $error_msg\n"
            return 1
          }
        }
 
        set fh 0
        if {[catch {open $file w} fh]} {
          send_msg_id Vivado-projutils-025 ERROR "failed to open file to write ($file)\n"
          return 1
        }
 
        send_msg_id Vivado-projutils-024 INFO \
          "Generating simulation files for the '$a_xport_sim_vars(s_simulator_name)' simulator...\n"
 
        # write header, compiler command/options
        if { [write_driver_script $fh] } {
          return 1
        }
        close $fh
 
        # make filelist executable
        if {[catch {exec chmod a+x $file} error_msg] } {
          send_msg_id Vivado-projutils-040 WARNING "failed to change file permissions to executable ($file): $error_msg\n"
        }
 
        # contains verilog sources? copy glbl to output dir
        if { [contains_verilog] } {
          if {[export_glbl_file]} {
            return 1
          }
        }
 
        return 0
    }
 
    proc write_driver_script { fh } {
 
        # Summary: Write driver script for the target simulator
 
        # Argument Usage:
        # fh   - file handle
 
        # Return Value:
        # true (0) if success, false (1) otherwise
 
        variable a_xport_sim_vars
        variable l_compile_order_files
 
        write_script_header $fh
 
        # setup source dir var
        puts $fh "#"
        puts $fh "# Directory path for design sources and include directories (if any) relative to this path"
        puts $fh "#"
        set relative_to $a_xport_sim_vars(s_relative_to)
        if {[string length $relative_to] > 0 } {
          set relative_to_out_dir [get_relative_file_path $a_xport_sim_vars(s_relative_to) $a_xport_sim_vars(s_out_dir)]
          puts $fh "src_ref_dir=\"$relative_to_out_dir\""
        } else {
          puts $fh "src_ref_dir=\"$a_xport_sim_vars(s_project_dir)\""
        }
        puts $fh ""

        set version_txt [split [version] "\n"]
        set version     [lindex $version_txt 0]
        set copyright   [lindex $version_txt 2]
        set product     [lindex [split $version " "] 0]
        set version_id  [join [lrange $version 1 end] " "]
 
        puts $fh "#"
        puts $fh "# STEP: setup"
        puts $fh "#"
        puts $fh "setup()\n\{"
        puts $fh "echo \"export_simulation: $version-id\""
        puts $fh "#\n# Add any setup/initialization commands here\n#"
        puts $fh "\}\n"

        puts $fh "#"
        puts $fh "# STEP: compile"
        puts $fh "#"
        puts $fh "compile()\n\{"
        if {[llength $l_compile_order_files] == 0} {
          puts $fh "# None (no sources present)"
          return 0
        }
 
        switch -regexp -- $a_xport_sim_vars(s_simulator) {
          "ies" { 
            set tool "ncvhdl"
            set arg_list [list "-V93" "-RELAX" "-logfile" "${tool}.log" "-append_log"]
            if { !$a_xport_sim_vars(b_32bit) } {
              set arg_list [linsert $arg_list 0 "-64bit"]
            }
            puts $fh "${tool}_opts=\"[join $arg_list " "]\""

            set tool "ncvlog"
            set arg_list [list "-messages" "-logfile" "${tool}.log" "-append_log"]
            if { !$a_xport_sim_vars(b_32bit) } {
              set arg_list [linsert $arg_list 0 "-64bit"]
            }
            puts $fh "${tool}_opts=\"[join $arg_list " "]\"\n"
          }
          "vcs_mx"   {
            set tool "vhdlan"
            set arg_list [list "-l" "$tool.log"]
            if { !$a_xport_sim_vars(b_32bit) } {
              set arg_list [linsert $arg_list 0 "-full64"]
            }
            puts $fh "${tool}_opts=\"[join $arg_list " "]\""

            set tool "vlogan"
            set arg_list [list "-l" "$tool.log"]
            if { !$a_xport_sim_vars(b_32bit) } {
              set arg_list [linsert $arg_list 0 "-full64"]
            }
            puts $fh "${tool}_opts=\"[join $arg_list " "]\"\n"
          }
          default {
            send_msg_id Vivado-projutils-056 ERROR "Invalid simulator ($a_xport_sim_vars(s_simulator))\n"
            close $fh
            return 1
          }
        }

        wr_compile_order $fh
 
        # add glbl
        if { [contains_verilog] } {
          set file_str "-work work \"glbl.v\""
          set s64bit ""
          switch -regexp -- $a_xport_sim_vars(s_simulator) {
            "ies"      { 
              if { !$a_xport_sim_vars(b_32bit) } { set s64bit "-64bit" }
              puts $fh "\n# Compile glbl module\nncvlog \$ncvlog_opts $file_str"
            }
            "vcs_mx"   {
              if { !$a_xport_sim_vars(b_32bit) } { set s64bit "-full64" }
              puts $fh "\n# Compile glbl module\nvlogan \$vlogan_opts +v2k $file_str"
            }
            default {
              send_msg_id Vivado-projutils-031 ERROR "Invalid simulator ($a_xport_sim_vars(s_simulator))\n"
              close $fh
              return 1
            }
          }
        }

        puts $fh "\}"
 
        puts $fh ""
        write_elaboration_cmds $fh
 
        puts $fh ""
        write_simulation_cmds $fh

        puts $fh ""
        puts $fh "#\n# main\n#"
        puts $fh "run()\n\{\nsetup\ncompile\nelaborate\nsimulate\n\}"
        puts $fh "\nrun"

        # copy simulator setup files from the compiled library directory path to the export dir and update mappings
        if { [string length $a_xport_sim_vars(s_compiled_lib_path)] > 0 } {
          set a_xport_sim_vars(s_compiled_lib_path) [file normalize $a_xport_sim_vars(s_compiled_lib_path)]
          if { [file exists $a_xport_sim_vars(s_compiled_lib_path)] } {
            generate_setup_files
            if { [update_library_mappings] } {
              return 1
            }
          } else {
            set compiled_lib_dir $a_xport_sim_vars(s_compiled_lib_path)
            send_msg_id Vivado-projutils-052 ERROR "Pre-compiled library directory path does not exist! ($compiled_lib_dir)\n"
          }
        } else {
            send_msg_id Vivado-projutils-055 WARNING \
                "Unable to perform automatic library mapping update because the compiled library directory path was\n\
                 not specified. Please follow the instructions in the generated script header to manually provide the library mapping information.\n\
                 Alternatively, this command can be executed again with the '-compiled_lib_path' switch."
        }

        return 0
    }

    proc generate_setup_files { } {

        # Summary: Generate the simulator setup files in exported dir from the compiled directory path

        # Argument Usage:
        # none

        # Return Value:

        variable a_xport_sim_vars

        switch -regexp -- $a_xport_sim_vars(s_simulator) {
          "ies" {
            set filename "cds.lib"
            create_setup_file $filename

            set filename "hdl.var"
            create_setup_file $filename
          }
          "vcs_mx"  {
            set filename "synopsys_sim.setup"
            create_setup_file $filename
          }
        }
    }

    proc create_setup_file { filename } {
 
        # Summary: Create setup file to the export dir
 
        # Argument Usage:
        # filename : setup filename
 
        # Return Value:
        # true (0) if success, false (1) otherwise
 
        variable a_xport_sim_vars

        set setup_file [file normalize [file join $a_xport_sim_vars(s_compiled_lib_path) $filename]]
        if { ! [file exists $setup_file] } {
          send_msg_id Vivado-projutils-010 WARNING "Setup file does not exist, creating default file '$setup_file'\n"
        }

        # remove existing file if present
        set target_file [file normalize [file join $a_xport_sim_vars(s_out_dir) $filename]]
        if { [file exists $target_file] } {
          if { [catch { file delete -force $target_file } error_msg] } {
            send_msg_id Vivado-projutils-011 ERROR "Failed to remove existing file '$target_file'\n"
            retun 1
          }
        }

        # create setup file
        set fh 0
        if { [catch {open $target_file w} fh] } {
          send_msg_id Vivado-projutils-012 WARNING "failed to open file to write ($file)\n"
          return 0
        }

        switch -regexp -- $a_xport_sim_vars(s_simulator) {
          "ies" {
            if { [string equal $filename "hdl.var"] } {
              # nothing to add
            } else {
              puts $fh "INCLUDE $setup_file"
            }
          }
          "vcs_mx" {
              puts $fh "OTHERS=$setup_file"
          }
        }

        close $fh

        return 0
    }

    proc copy_setup_file { filename } {
 
        # Summary: Copy setup file to the export dir
 
        # Argument Usage:
        # filename : setup filename
 
        # Return Value:
        # true (0) if success, false (1) otherwise
 
        variable a_xport_sim_vars

        set file [file normalize [file join $a_xport_sim_vars(s_compiled_lib_path) $filename]]
        if { ! [file exists $file] } {
          send_msg_id Vivado-projutils-044 WARNING "Setup file does not exist! '$file'\n"
          return 1
        }

        # remove existing file if present
        set target_file [file normalize [file join $a_xport_sim_vars(s_out_dir) $filename]]
        if { [file exists $target_file] } {
          if { [catch { file delete -force $target_file } error_msg] } {
            send_msg_id Vivado-projutils-045 ERROR "Failed to remove existing file '$target_file'\n"
            retun 1
          }
        }

        # copy file
        if { [catch {file copy $file $a_xport_sim_vars(s_out_dir)} error_msg] } {
          send_msg_id Vivado-projutils-046 ERROR "Failed to copy file ($file): $error_msg\n"
          return 1
        } else {
          send_msg_id Vivado-projutils-047 INFO "Copied '$file' to export directory ($a_xport_sim_vars(s_out_dir))\n"
        }
 
        return 0
    }

    proc update_library_mappings { } {
 
        # Summary: Write library mappings the target simulator
 
        # Argument Usage:
 
        # Return Value:
        # true (0) if success, false (1) otherwise
 
        variable a_xport_sim_vars

        set filename "" 
        switch -regexp -- $a_xport_sim_vars(s_simulator) {
          "ies"    { set filename "cds.lib" }
          "vcs_mx" { set filename "synopsys_sim.setup" }
        }
         
        set file [file normalize [file join $a_xport_sim_vars(s_out_dir) $filename]]
        if { ![file exists $file] } {
          send_msg_id Vivado-projutils-048 WARNING "File does not exist ($file)\n"
          return 0
        }

        set fh 0
        if {[catch {open $file a} fh]} {
          send_msg_id Vivado-projutils-049 WARNING "failed to open file for update ($file)\n"
          return 0
        }

        foreach lib [get_compile_order_libs] {
          if {[string length $lib] == 0} { continue; }
          if { ({work} == $lib) && ({vcs_mx} == $a_xport_sim_vars(s_simulator)) } { continue; }

          set dir ""
          switch -regexp -- $a_xport_sim_vars(s_simulator) {
            "ies"    { set dir "ies/[string tolower $lib]" }
            "vcs_mx" { set dir "vcs_mx/[string tolower $lib]" }
          }

          set lib_dir [file join $a_xport_sim_vars(s_out_dir) $dir]
          if { ![file exists $lib_dir] } { file mkdir $lib_dir }

          switch -regexp -- $a_xport_sim_vars(s_simulator) {
            "ies"    { puts $fh "DEFINE [string tolower $lib] $dir" }
            "vcs_mx" { puts $fh "$lib : $dir" }
          }
        }

        send_msg_id Vivado-projutils-053 INFO "Updated library mappings in $filename\n"
        close $fh

        return 0
    }
 
    proc wr_compile_order { fh } {
 
        # Summary: Write compile order for the target simulator
 
        # Argument Usage:
        # fh - file handle
 
        # Return Value:
        # none
 
        variable a_xport_sim_vars
        variable l_compile_order_files
 
        foreach file $l_compile_order_files {
          set cmd_str [list]
          set file_type [get_property file_type [get_files -quiet -all $file]]
          if { [lsearch -exact [list_property [lindex [get_files -quiet -all $file] 0]] {LIBRARY}] == -1} {
            continue;
          }
          set associated_library [get_property library [get_files -quiet -all $file]]
          if {[string length $a_xport_sim_vars(s_relative_to)] > 0 } {
            set file "\$src_ref_dir/[get_relative_file_path $file $a_xport_sim_vars(s_relative_to)]"
          } else {
            set file "\$src_ref_dir/[get_relative_file_path $file $a_xport_sim_vars(s_project_dir)]"
          }

          set compiler [get_compiler_name $file_type]
          if { [string length $compiler] > 0 } {
            set arg_list [list $compiler]
            append_compiler_options $compiler $file_type arg_list
            set arg_list [linsert $arg_list end "-work" "$associated_library" "\"$file\""]
            puts $fh [join $arg_list " "]
          }
        }
    }

    proc write_script_header { fh } {
 
        # Summary: Driver script header info
 
        # Argument Usage:
        # fh - file descriptor
 
        # Return Value:
        # none
 
        variable a_xport_sim_vars
 
        set curr_time   [clock format [clock seconds]]
        set version_txt [split [version] "\n"]
        set version     [lindex $version_txt 0]
        set copyright   [lindex $version_txt 2]
        set product     [lindex [split $version " "] 0]
        set version_id  [join [lrange $version 1 end] " "]
 
        puts $fh "#!/bin/sh -f"
        puts $fh "#\n# $product (TM) $version_id\n#"
        puts $fh "# $a_xport_sim_vars(s_script_filename): Simulation script\n#"
        puts $fh "# Generated by $product on $curr_time"
        puts $fh "# $copyright \n#"
        puts $fh "# This file contains commands for compiling the design in '$a_xport_sim_vars(s_simulator_name)' simulator\n#"
        puts $fh "#************************************************************************************************"
        puts $fh "# NOTE: To compile and run simulation, you must perform following step:-"
        puts $fh "#"
        puts $fh "# - Compile the Xilinx simulation libraries using the 'compile_simlib' TCL command. For more"
        puts $fh "#   information about this command, run 'compile_simlib -help' in $product Tcl Shell."
        puts $fh "#"
        puts $fh "#************************************************************************************************\n#"
        puts $fh "# If '-compiled_lib_path <path>' option is specified then the following steps will be automatically"
        puts $fh "# performed by the export_simulation command:-\n#"
     
        switch -regexp -- $a_xport_sim_vars(s_simulator) {
          "ies" { 
             puts $fh "# 1. Create CDS.LIB file and reference the compiled library CDS.LIB from the path specified"
             puts $fh "#    with the -compiled_lib_path switch"
             puts $fh "# 2. Create HDL.var file"
             puts $fh "# 3. Create sub-directory for each design library* in <output_dir>/ies/<library>"
             puts $fh "# 4. Define library mapping for each library in CDS.lib file\n"
          }
          "vcs_mx" {
             puts $fh "# 1. Create synopsys_sim.setup file and reference the compiled library synopsys_sim.setup"
             puts $fh "#    from the path specified with the -compiled_lib_path switch"
             puts $fh "# 2. Create sub-directory for each design library* in <output_dir>/vcs_mx/<library>"
             puts $fh "# 3. Map libraries to physical directory location in synopsys_sim.setup file\n#"
          }
        }
        puts $fh "# For more information please refer to the following guide:-\n#"
        puts $fh "#  Xilinx Vivado Design Suite User Guide:Logic simulation (UG900)\n#"
        puts $fh "# * List of design libraries:-\n#"
        foreach lib [get_compile_order_libs] {
          if {[string length $lib] == 0} { continue; }
          puts $fh "#  $lib"
        }
        puts $fh "#"
        puts $fh "#************************************************************************************************\n"
 
    }

    proc write_elaboration_cmds { fh } {
 
        # Summary: Driver script header info
 
        # Argument Usage:
        # files - compile order files
        # fh - file descriptor
 
        # Return Value:
        # none
 
        variable a_xport_sim_vars
        variable l_compile_order_files
 
        puts $fh "#"
        puts $fh "# STEP: elaborate"
        puts $fh "#"
        puts $fh "elaborate()\n\{"
        if {[llength $l_compile_order_files] == 0} {
          puts $fh "# None (no sources present)"
          return
        }
 
        switch -regexp -- $a_xport_sim_vars(s_simulator) {
          "ies" { 
            set tool "ncelab"
            set top_lib [get_top_library]
            set arg_list [list "-access +rwc -messages" "-logfile" "$a_xport_sim_vars(s_sim_top)_elab.log"]
            if { !$a_xport_sim_vars(b_32bit) } {
              set arg_list [linsert $arg_list 0 "-64bit"]
            }
            puts $fh "${tool}_opts=\"[join $arg_list " "]\"\n"

            set arg_list [list]
            foreach lib [get_compile_order_libs] {
              if {[string length $lib] == 0} { continue; }
              lappend arg_list "-libname"
              lappend arg_list "[string tolower $lib]"
            }
            set arg_list [linsert $arg_list end "-libname" "unisims_ver" "-libname" "secureip"]
            puts $fh "design_libs_elab=\"[join $arg_list " "]\"\n"

            set arg_list [list $tool "\$${tool}_opts"]
            if { [is_fileset $a_xport_sim_vars(sp_tcl_obj)] } {
              set vhdl_generics [list]
              set vhdl_generics [get_property vhdl_generic [get_filesets $a_xport_sim_vars(sp_tcl_obj)]]
              if { [llength $vhdl_generics] > 0 } {
                append_define_generics $vhdl_generics $tool arg_list
              }
            }
            lappend arg_list "${top_lib}.$a_xport_sim_vars(s_sim_top)"
            if { [contains_verilog] } {
              lappend arg_list "${top_lib}.glbl"
            }
            lappend arg_list "\$design_libs_elab"
            puts $fh [join $arg_list " "]
          }
          "vcs_mx" {
            set tool "vcs"
            set top_lib [get_top_library]
            set arg_list [list "-debug_pp" "-t" "ps" "-licwait" "-60" "-l" "$a_xport_sim_vars(s_sim_top)_comp.log"]
            if { !$a_xport_sim_vars(b_32bit) } {
              set arg_list [linsert $arg_list 0 "-full64"]
            }
            puts $fh "${tool}_opts=\"[join $arg_list " "]\"\n"
 
            set arg_list [list "$tool" "\$${tool}_opts" "${top_lib}.$a_xport_sim_vars(s_sim_top)"]
            if { [contains_verilog] } {
              lappend arg_list "${top_lib}.glbl"
            }
            lappend arg_list "-o"
            lappend arg_list "$a_xport_sim_vars(s_sim_top)_simv"
            puts $fh [join $arg_list " "]
          }
        }
        puts $fh "\}"
    }
 
    proc write_simulation_cmds { fh } {
 
        # Summary: Driver script simulation commands info
 
        # Argument Usage:
        # files - compile order files
        # fh - file descriptor
 
        # Return Value:
 
        variable a_xport_sim_vars
        variable l_compile_order_files
 
        puts $fh "#"
        puts $fh "# STEP: simulate"
        puts $fh "#"
        puts $fh "simulate()\n\{"
        if {[llength $l_compile_order_files] == 0} {
          puts $fh "# None (no sources present)"
          return
        }
 
        set do_filename "$a_xport_sim_vars(s_sim_top).do"
        switch -regexp -- $a_xport_sim_vars(s_simulator) {
          "ies" { 
            set tool "ncsim"
            set top_lib [get_top_library]

            set arg_list [list "-logfile" "$a_xport_sim_vars(s_sim_top)_sim.log"]
            if { !$a_xport_sim_vars(b_32bit) } {
              set arg_list [linsert $arg_list 0 "-64bit"]
            }
            puts $fh "${tool}_opts=\"[join $arg_list " "]\"\n"

            set arg_list [list "$tool" "\$${tool}_opts" "${top_lib}.$a_xport_sim_vars(s_sim_top)" "-input" "$do_filename"]
            puts $fh [join $arg_list " "]
          }
          "vcs_mx" {
            set tool "$a_xport_sim_vars(s_sim_top)_simv"
            set arg_list [list "-ucli" "-licwait" "-60" "-l" "$a_xport_sim_vars(s_sim_top)_sim.log"]
            puts $fh "${tool}_opts=\"[join $arg_list " "]\""
            puts $fh ""

            set arg_list [list "./$a_xport_sim_vars(s_sim_top)_simv" "\$${tool}_opts" "-do" "$do_filename"]
            puts $fh [join $arg_list " "]
          }
        }
        puts $fh "\}"
        write_do_file $do_filename
    }

    proc write_do_file { file } {
 
        # Summary: Write do file for simulation
 
        # Argument Usage:
        # file - do filename
 
        # Return Value:
        # none
       
        variable a_xport_sim_vars
 
        set do_file [file join $a_xport_sim_vars(s_out_dir) $file]
        set fh 0
        if {[catch {open $do_file w} fh]} {
          send_msg_id Vivado-projutils-043 ERROR "failed to open file to write ($do_file)\n"
        } else {
          puts $fh "run"
          switch -regexp -- $a_xport_sim_vars(s_simulator) {
            "ies"    { puts $fh "exit" }
            "vcs_mx" { puts $fh "quit" }
          }
        }
        close $fh
    }

    proc append_define_generics { def_gen_list tool opts_arg } {

        # Summary: Append verilog defines/vhdl generics for the specified tool
 
        # Argument Usage:
        # def_gen_list - list of defines or generics
        # tool - compiler
        # opts_arg - options list to be appended
 
        # Return Value:
        # none

        foreach element $def_gen_list {
          set key_val_pair [split $element "="]
          set name [lindex $key_val_pair 0]
          set val  [lindex $key_val_pair 1]
          if { [string length $val] > 0 } {
            switch -regexp -- $tool {
              "ncvlog" { lappend opts_arg "-define"  ; lappend opts_arg "\"$name=$val\""  }
              "vlogan" { lappend opts_arg "+define+" ; lappend opts_arg "\"$name=$val\""  }
              "ies"    { lappend opts_arg "-g"       ; lappend opts_arg "\"$name=>$val\"" }
            }
          }
        }
    }

    proc get_compiler_name { file_type } {

        # Summary: Return applicable compiler application name based on filetype for the target simulator
 
        # Argument Usage:
        # file_type - file type
 
        # Return Value:
        # compiler name if valid filetype, else empty string

        variable a_xport_sim_vars

        set compiler ""

        if { {VHDL} == $file_type } {
          switch -regexp -- $a_xport_sim_vars(s_simulator) {
            "ies"    { set compiler "ncvhdl" }
            "vcs_mx" { set compiler "vhdlan" }
          }
        } elseif { ({Verilog} == $file_type) || ({SystemVerilog} == $file_type) } {
          switch -regexp -- $a_xport_sim_vars(s_simulator) {
            "ies"    { set compiler "ncvlog" }
            "vcs_mx" { set compiler "vlogan" }
          }
        }
        return $compiler
    }
 
    proc append_compiler_options { tool file_type opts_arg } {
 
        # Summary: Add switches (options) for the target compiler tool
 
        # Argument Usage:
        # tool - compiler name
        # file_type - file type
        # opts_arg - options list to be appended
 
        # Return Value:
        # none

        upvar $opts_arg opts
 
        variable a_xport_sim_vars

        switch $tool {
          "ncvhdl" -
          "vhdlan" {
            lappend opts "\$${tool}_opts"
          }
          "ncvlog" {
            lappend opts "\$${tool}_opts"
            if { [string equal -nocase $file_type "systemverilog"] } {
              lappend opts "-sv"
            }
          }
          "vlogan" {
            lappend opts "\$${tool}_opts"
            if { [string equal -nocase $file_type "verilog"] } {
              lappend opts "+v2k"
            } elseif { [string equal -nocase $file_type "systemverilog"] } {
              lappend opts "-sverilog"
            }
          }
        }

        # append verilog defines, include dirs and include file dirs
        switch $tool {
          "ncvlog" -
          "vlogan" {
            # verilog defines
            if { [is_fileset $a_xport_sim_vars(sp_tcl_obj)] } {
              set verilog_defines [list]
              set verilog_defines [get_property verilog_define [get_filesets $a_xport_sim_vars(sp_tcl_obj)]]
              if { [llength $verilog_defines] > 0 } {
                append_define_generics $verilog_defines $tool opts
              }
            }
 
            # include dirs
            foreach dir [concat [find_verilog_incl_dirs] [find_verilog_incl_file_dirs]] {
              lappend opts "+incdir+\"$dir\""
            }
          }
        }
    }
 
    proc find_verilog_incl_dirs { } {
 
        # Summary: Get the verilog include directory paths
 
        # Argument Usage:
        # none
 
        # Return Value:
        # Sorted unique list of verilog include directories (if any)
  
        variable a_xport_sim_vars
 
        set dir_names [list]
  
        set tcl_obj $a_xport_sim_vars(sp_tcl_obj)
        if { [is_ip $tcl_obj] } {
          set incl_dir_str [find_incl_dirs_from_ip $tcl_obj]
        } else {
          set incl_dir_str [get_property include_dirs [get_filesets $tcl_obj]]
        }

        set incl_dirs [split $incl_dir_str " "]
        foreach vh_dir $incl_dirs {
          set dir [file normalize $vh_dir]
          if {[string length $a_xport_sim_vars(s_relative_to)] > 0 } {
            set dir "\$src_ref_dir/[get_relative_file_path $dir $a_xport_sim_vars(s_relative_to)]"
          } else {
            set dir "\$src_ref_dir/[get_relative_file_path $dir $a_xport_sim_vars(s_project_dir)]"
          }
          lappend dir_names $dir
        }
        return [lsort -unique $dir_names]
    }
 
    proc find_verilog_incl_file_dirs {} {
 
        # Summary: Get the verilog include directory paths for files of type "Verilog Header"
 
        # Argument Usage:
        # none
 
        # Return Value:
        # Sorted unique list of verilog include directory paths for files of type "Verilog Header"
 
        variable a_xport_sim_vars
 
        set dir_names [list]
 
        set tcl_obj $a_xport_sim_vars(sp_tcl_obj)
        if { [is_ip $tcl_obj] } {
          set vh_files [find_incl_files_from_ip $tcl_obj]
        } else {
          set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"Verilog Header\""
          set vh_files [get_files -quiet -filter $filter]
        }

        foreach vh_file $vh_files {
          set dir [file normalize [file dirname $vh_file]]
          if {[string length $a_xport_sim_vars(s_relative_to)] > 0 } {
            set dir "\$src_ref_dir/[get_relative_file_path $dir $a_xport_sim_vars(s_relative_to)]"
          } else {
            set dir "\$src_ref_dir/[get_relative_file_path $dir $a_xport_sim_vars(s_project_dir)]"
          }
          lappend dir_names $dir
        }
        if {[llength $dir_names] > 0} {
          return [lsort -unique $dir_names]
        }
 
        return $dir_names
    }
 
    proc find_incl_dirs_from_ip { tcl_obj } {
 
        # Summary: Get the verilog include directory paths for files of type "Verilog Header" for an IP
 
        # Argument Usage:
        # tcl_obj - source object type
 
        # Return Value:
        # List of verilog include directory paths in an IP for files of type "Verilog Header"
     
        variable a_xport_sim_vars 

        set ip_name [file tail $tcl_obj]
        set incl_dirs [list]
        set filter "FILE_TYPE == \"Verilog Header\""
        set vh_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_name] -filter $filter]
        foreach file $vh_files {
          set dir [file dirname $file]
          if {[string length $a_xport_sim_vars(s_relative_to)] > 0 } {
            set dir "\$src_ref_dir/[get_relative_file_path $dir $a_xport_sim_vars(s_relative_to)]"
          } else {
            set dir "\$src_ref_dir/[get_relative_file_path $dir $a_xport_sim_vars(s_project_dir)]"
          }
          lappend incl_dirs $dir
        }
  
        return $incl_dirs
    }
 
    proc find_incl_files_from_ip { tcl_obj } {
 
        # Summary: Get the verilog include files of type "Verilog Header" for an IP
 
        # Argument Usage:
        # none
 
        # Return Value:
        # List of verilog include directory files in an IP for files of type "Verilog Header"
 
        variable a_xport_sim_vars

        set incl_files [list]
        set ip_name [file tail $tcl_obj]
        set filter "FILE_TYPE == \"Verilog Header\""
        set vh_files [get_files -quiet -of_objects [get_files -quiet *$ip_name] -filter $filter]
        foreach file $vh_files {
          if {[string length $a_xport_sim_vars(s_relative_to)] > 0 } {
            set file "\$src_ref_dir/[get_relative_file_path $file $a_xport_sim_vars(s_relative_to)]"
          } else {
            set file "\$src_ref_dir/[get_relative_file_path $file $a_xport_sim_vars(s_project_dir)]"
          }
          lappend incl_files $file
        }
  
        return $incl_files
    }
 
    proc export_data_files { data_files } {
 
        # Summary: Copy IP data files to output directory
 
        # Argument Usage:
        # data_files - List of data files
 
        # Return Value:
        # none
 
        variable a_xport_sim_vars
  
        set export_dir $a_xport_sim_vars(s_out_dir)
        
        # export now
        foreach file $data_files {
          if {[catch {file copy -force $file $export_dir} error_msg] } {
            send_msg_id Vivado-projutils-027 WARNING "failed to copy file '$file' to '$export_dir' : $error_msg\n"
          } else {
            send_msg_id Vivado-projutils-028 INFO "exported '$file'\n"
          }
        }
    }
 
    proc export_fs_data_files { } {
 
        # Summary: Copy fileset IP data files to output directory
 
        # Argument Usage:
        # none
 
        # Return Value:
        # none
 
        variable a_xport_sim_vars
        variable s_data_files_filter
 
        # export all IP data files 
        set ip_filter "FILE_TYPE == \"IP\""
        set ips [get_files -all -quiet -filter $ip_filter]
        foreach ip $ips {
          set ip_name [file tail $ip]
          set data_files [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $s_data_files_filter]
          export_data_files $data_files
        }
 
        # export fileset data files
        foreach fs_obj [list [current_fileset] [current_fileset -simset]] {
          set fs_data_files [get_files -all -quiet -of_objects [get_filesets -quiet $fs_obj] -filter $s_data_files_filter]
          export_data_files $fs_data_files
        }
    }
 
    proc export_glbl_file {} {
 
        # Summary: Copies glbl.v file from install data dir to output dir
 
        # Argument Usage:
        # none
 
        # Return Value:
        # True (0) if file copied, false (1) otherwise
 
        variable a_xport_sim_vars
 
        set data_dir [rdi::get_data_dir -quiet -datafile verilog/src/glbl.v]
        set file [file normalize [file join $data_dir "verilog/src/glbl.v"]]
        set export_dir $a_xport_sim_vars(s_out_dir)
 
        if {[catch {file copy -force $file $export_dir} error_msg] } {
          send_msg_id Vivado-projutils-029 WARNING "failed to copy file '$file' to '$export_dir' : $error_msg\n"
          return 1
        }
 
        set glbl_file [file normalize [file join $export_dir "glbl.v"]]
        send_msg_id Vivado-projutils-030 INFO "Copied glbl file (glbl.v) to export directory ($export_dir)\n"
 
        return 0
    }
 
    proc get_compile_order_libs { } {
 
        # Summary: Find unique list of design libraries
 
        # Argument Usage:
        # files: list of design files
 
        # Return Value:
        # Unique list of libraries (if any)
     
        variable a_xport_sim_vars
        variable l_compile_order_files
 
        set libs [list]
        foreach file $l_compile_order_files {
          if { [lsearch -exact [list_property [lindex [get_files -all $file] 0]] {LIBRARY}] == -1} {
            continue;
          }
          foreach f [get_files -all $file] {
            set library [get_property library $f]
            if { [lsearch -exact $libs $library] == -1 } {
              lappend libs $library
            }
          }
        }
        return $libs
    }

    proc get_top_library { } {
 
        # Summary: Find the "top" library from the compile order
 
        # Argument Usage:
        # none
 
        # Return Value:
        # Top library name
     
        variable a_xport_sim_vars
        variable l_compile_order_files

        set tcl_obj $a_xport_sim_vars(sp_tcl_obj)
        set top_lib ""
        if { [is_fileset $tcl_obj] } {
          set top_lib [get_property top_lib [get_filesets $tcl_obj]]
        }

        if { [string length $top_lib] == 0 } {
          if { [llength $l_compile_order_files] > 0 } {
            set top_lib [get_property library [get_files -all [lindex $l_compile_order_files end]]]
          }
        }

        if { [string length $top_lib] == 0 } {
          set top_lib "work"
        }

        return $top_lib
    }
 
    proc contains_verilog {} {
 
        # Summary: Check if the input file type is of type verilog or verilog header
 
        # Argument Usage:
        # files: list of files
 
        # Return Value:
        # True (1) if of type verilog, False (0) otherwise
 
        variable l_compile_order_files

        foreach file $l_compile_order_files {
          set file_type [get_property file_type [get_files -quiet -all $file]]
          if {[regexp -nocase {^verilog} $file_type] ||
              [regexp -nocase {^systemverilog} $file_type]} {
            return 1
          }
        }
        return 0
    }
 
    proc get_relative_file_path { file_path_to_convert relative_to } {
 
        # Summary: Get the relative path wrt to path specified
 
        # Argument Usage:
        # file_path_to_convert: input file to make relative to specfied path
 
        # Return Value:
        # Relative path wrt the path specified
   
        variable a_xport_sim_vars
 
        # make sure we are dealing with a valid relative_to directory. If regular file or is not a directory, get directory
        if { [file isfile $relative_to] || ![file isdirectory $relative_to] } {
          set relative_to [file dirname $s_relative_to]
        }
 
        set cwd [file normalize [pwd]]
 
        if { [file pathtype $file_path_to_convert] eq "relative" } {
          # is relative_to path same as cwd?, just return this path, no further processing required
          if { [string equal $relative_to $cwd] } {
            return $file_path_to_convert
          }
          # the specified path is "relative" but something else, so make it absolute wrt current working dir
          set file_path_to_convert [file join $cwd $file_path_to_convert]
        }
 
        # is relative_to "relative"? convert to absolute as well wrt cwd
        if { [file pathtype $relative_to] eq "relative" } {
          set relative_to [file join $cwd $relative_to]
        }
 
        # normalize 
        set file_path_to_convert [file normalize $file_path_to_convert]
        set relative_to          [file normalize $relative_to]
 
        set file_path $file_path_to_convert
        set file_comps        [file split $file_path]
        set relative_to_comps [file split $relative_to]
 
        set found_match false
        set index 0
 
        # compare each dir element of file_to_convert and relative_to, set the flag and
        # get the final index till these sub-dirs matched
        while { [lindex $file_comps $index] == [lindex $relative_to_comps $index] } {
          if { !$found_match } { set found_match true }
          incr index
        }
 
        # any common dirs found? convert path to relative
        if { $found_match } {
          set parent_dir_path ""
          set rel_index $index
          # keep traversing the relative_to dirs and build "../" levels
          while { [lindex $relative_to_comps $rel_index] != "" } {
            set parent_dir_path "../$parent_dir_path"
            incr rel_index
          }
 
          # 
          # at this point we have parent_dir_path setup with exact number of sub-dirs to go up
          #
 
          # now build up part of path which is relative to matched part
          set rel_path ""
          set rel_index $index
 
          while { [lindex $file_comps $rel_index] != "" } {
            set comps [lindex $file_comps $rel_index]
            if { $rel_path == "" } {
              # first dir
              set rel_path $comps
            } else {
              # append remaining dirs
              set rel_path "${rel_path}/$comps"
            }
            incr rel_index
          }
 
          # prepend parent dirs, this is the complete resolved path now
          set resolved_path "${parent_dir_path}${rel_path}"
 
          return $resolved_path
        }
 
        # no common dirs found, just return the normalized path 
        return $file_path
    }
}
