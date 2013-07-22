####################################################################################################
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# 
# Created Date:   01/25/2013
# Script name:    helpers.tcl
# Procedures:     write_project_tcl, export_simulation_files
# Tool Version:   Vivado 2013.3
# Description:    This helpers.tcl script is used for following purposes:-
#   1. To write a Tcl script for the current project in order to re-build the project, based on the current project settings.
#   2. Export simulation design files (compile order, simulator commands) for the specified object in the project in order to
#      simulate the design for the target simulator.
#
# Structure:      The script contains following 3 sections:-
#
# SECTION (A): Exported app procedure from 
#              ::tclapp::xilinx::projutils namespace (write_project_tcl)
#              ::tclapp::xilinx::projutils namespace (export_simulation_files)
# SECTION (B): Main app procedure implementation
#              write_project_tcl
#              export_simulation_files
# SECTION (C): App helpers for the exported procedures
# 
# Command help:
#     % write_project_tcl -help
#     % export_simulation_files -help
#
# Revision History:
#
#   02/08/2013 1.0  - Initial version (write_project_tcl)
#   07/12/2013 2.0  - Initial version (export_simulation_files)
#
#
####################################################################################################

# title: Vivado Project Re-Build Tcl Script
package require Vivado 2013.1

#
# SECTION (A): Exported app procedures
#
namespace eval ::tclapp::xilinx::projutils {

  # Export procs that should be allowed to import into other namespaces
  namespace export write_project_tcl

  namespace export export_simulation_files
}

#
# SECTION (B): Main app procedures
#
namespace eval ::tclapp::xilinx::projutils {

    proc write_project_tcl {args} {

 	    # Summary: 
        # Export Tcl script for re-creating the current project

 	    # Argument Usage: 
        # [-force]: Overwrite existing tcl script file
        # [-all_properties]: write all properties (default & non-default) for the project object(s)
        # [-no_copy_sources]: Do not import sources even if they were local in the original project
        # [-dump_project_info]: Write object values
 	    # file: Name of the tcl script file to generate

 	    # Return Value:
        # true

 	    # reset global variables
        variable a_global_vars
 
 	    reset_global_vars
 
 	    # process options
 	    for {set i 0} {$i < [llength $args]} {incr i} {
 	      set option [string trim [lindex $args $i]]
 	      switch -regexp -- $option {
 		    "-force"                { set a_global_vars(b_arg_force) 1 }
 		    "-all_properties"       { set a_global_vars(b_arg_all_props) 1 }
 		    "-no_copy_sources"      { set a_global_vars(b_arg_no_copy_srcs) 1 }
 		    "-dump_project_info"    { set a_global_vars(b_arg_dump_proj_info) 1 }
 		    default {
 		      # is incorrect switch specified?
 		      if { [regexp {^-} $option] } {
                send_msg_id Vivado-projutils-001 ERROR "Unknown option '$option', please type 'write_project_tcl -help' for usage info.\n"
 			    return 0
 		      }
 		      set a_global_vars(script_file) $option
 		    }
 	      }
 	    }
 
 	    # script file is a must
 	    if { [string equal $a_global_vars(script_file) ""] } {
          send_msg_id Vivado-projutils-002 ERROR "Missing value for option 'file', please type 'write_project_tcl -help' for usage info.\n"
 	      return 0
 	    }
      
 	    # should not be a directory
 	    if { [file isdirectory $a_global_vars(script_file)] } {
          send_msg_id Vivado-projutils-003 ERROR "The specified filename is a directory ($a_global_vars(script_file)), please type 'write_project_tcl -help' for usage info.\n"
 	      return 0
 	    }
 
 	    # check extension
 	    if { [file extension $a_global_vars(script_file)] != ".tcl" } {
 	      set a_global_vars(script_file) $a_global_vars(script_file).tcl
 	    }
 	    set a_global_vars(script_file [file normalize $a_global_vars(script_file)]
  
 	    # recommend -force if file exists
 	    if { [file exists $a_global_vars(script_file)] && !$a_global_vars(b_arg_force) } {
          send_msg_id Vivado-projutils-004 ERROR "Tcl Script '$a_global_vars(script_file)' already exist. Use -force option to overwrite."
 	      return false
 	    }

 	    # now write
 	    write_project_tcl_script
    
 	    return 1
    }

    proc export_simulation_files {args} {

        # Summary:
        # Write simulation files and scripts for the specified simulator

        # Argument Usage:
        # [-of_objects <args>]: Export simulation file(s) for the specified object (IP file or fileset) 
        # [-relative_to <dir>]: Make all file paths relative to the specified directory
        # [-include_compile_commands]: Prefix RTL design files with compiler switches
        # [-force]: Overwrite previous files
        # -simulator <name>: Simulator for which simulation files will be exported (<name>: modelsim|ies|vcs_mx|xsim)
        # dir: Directory where the simulation files is saved

        # Return Value:
        # true (1) if success, false (0) otherwise

        variable a_global_sim_vars

        variable l_valid_simulator_types

        reset_global_sim_vars

        set options [split $args " "]
        # these options are must
        if {[lsearch $options {-simulator}] == -1} {
          send_msg_id Vivado-projutils-013 ERROR "Missing option '-simulator', please type 'export_simulation_files -help' for usage info.\n"
          return 0
        }

        # process options
        for {set i 0} {$i < [llength $args]} {incr i} {
          set option [string trim [lindex $args $i]]
          switch -regexp -- $option {
            "-of_objects"               { incr i;set a_global_sim_vars(s_of_objects) [lindex $args $i] }
            "-include_compile_commands" { set a_global_sim_vars(b_incl_compile_commmands) 1 }
            "-relative_to"              { incr i;set a_global_sim_vars(s_relative_to) [lindex $args $i] }
            "-force"                    { set a_global_sim_vars(b_overwrite_sim_files_dir) 1 }
            "-simulator"                { incr i;set a_global_sim_vars(s_simulator) [lindex $args $i] }
            default {
              # is incorrect switch specified?
              if { [regexp {^-} $option] } {
                send_msg_id Vivado-projutils-014 ERROR "Unknown option '$option', please type 'export_simulation_files -help' for usage info.\n"
                return 0
              }
              set a_global_sim_vars(s_sim_files_dir) $option
            }
          }
        }

        # is project open?
        set a_global_sim_vars(s_project_name) [get_property name [current_project]]
        set a_global_sim_vars(s_project_dir) [get_property directory [current_project]]

        # is valid simulator specified?
        if { [lsearch -exact $l_valid_simulator_types $a_global_sim_vars(s_simulator)] == -1 } {
          send_msg_id Vivado-projutils-015 ERROR \
            "Invalid simulator type specified. Please type 'export_simulation_files -help' for usage info.\n"
          return 0
        }

        # is valid relative_to set?
        if { [lsearch $options {-relative_to}] != -1} {
          set relative_file_path $a_global_sim_vars(s_relative_to)
          if { ![file exists $relative_file_path] } {
            send_msg_id Vivado-projutils-040 ERROR \
              "Invalid relative path specified! Path does not exist:$a_global_sim_vars(s_relative_to)\n"
            return 0
          }
        }
 
        # set pretty name
        if { ![set_simulator_name] } {
          return 0
        }

        # is managed project?
        set a_global_sim_vars(b_is_managed) [get_property managed_ip [current_project]]

        # setup run dir
        if { ! [create_sim_files_dir] } {
          return 0
        }
  
        # set default object if not specified, bail out if no object found
        if { ! [set_default_source_object] } {
          return 0
        }

        # write script
        if { ! [write_sim_script] } {
          return 0
        }

        return 1
    }
}


#
# SECTION (C): App helpers
#
namespace eval ::tclapp::xilinx::projutils {

    #
    # write_project_tcl tcl script argument & file handle vars
    #
    variable a_global_vars
    variable l_script_data [list]
    variable l_local_files [list]
    variable l_remote_files [list]
    variable b_project_board_set 0

    # set file types to filter
    variable l_filetype_filter [list]
    set l_filetype_filter [list "ip" "embedded design sources" "elf" "coefficient files" \
                                "block diagrams" "block designs" "dsp design sources" \
                                "design checkpoint" "waveform configuration file" "data files"]

    # set fileset types
    variable a_fileset_types
    set a_fileset_types {
      {{DesignSrcs}     {srcset}}
      {{BlockSrcs}      {blockset}}
      {{Constrs}        {constrset}}
      {{SimulationSrcs} {simset}}
    }

    proc reset_global_vars {} {

        # Summary: initializes global namespace vars 
        # This helper command is used to reset the variables used in the script.
    
        # Argument Usage: 
        # none
        
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        variable a_global_vars

        set a_global_vars(b_arg_force)          0
        set a_global_vars(b_arg_no_copy_srcs)   0
        set a_global_vars(b_arg_all_props)      0
        set a_global_vars(b_arg_dump_proj_info) 0
        set a_global_vars(b_local_sources)      0
        set a_global_vars(fh)                   0
        set a_global_vars(dp_fh)                0
        set a_global_vars(def_val_fh)           0
        set a_global_vars(script_file)          ""

        set l_script_data                       [list]
        set l_local_files                       [list]
        set l_remote_files                      [list]
    
        return 0
    }

    #
    # export_simulation_files tcl script argument & file handle vars
    #
    variable a_global_sim_vars

    variable l_valid_simulator_types [list]
    set l_valid_simulator_types [list "modelsim" "ies" "vcs_mx" "xsim"]

    variable l_valid_ip_extns [list]
    set l_valid_ip_extns [list ".xci" ".bd" ".slx"]

    proc reset_global_sim_vars {} {

        # Summary: initializes global namespace simulation vars
        # This helper command is used to reset the simulation variables used in the script.

        # Argument Usage:
        # none

        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        variable a_global_sim_vars

        set a_global_sim_vars(s_simulator)               ""
        set a_global_sim_vars(s_simulator_name)          ""
        set a_global_sim_vars(s_sim_files_dir)           ""
        set a_global_sim_vars(b_incl_compile_commmands)  0
        set a_global_sim_vars(s_relative_to)             ""             
        set a_global_sim_vars(b_overwrite_sim_files_dir) 0
        set a_global_sim_vars(s_filelist)                ""
        set a_global_sim_vars(s_of_objects)              ""
        set a_global_sim_vars(s_project_name)            ""
        set a_global_sim_vars(s_project_dir)             ""
        set a_global_sim_vars(b_is_managed)              0 

    }


    proc write_project_tcl_script {} {

        # Summary: write project script 
        # This helper command is used to script help.
    
        # Argument Usage: 
        # none
    
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        variable a_global_vars
        variable l_script_data
        variable l_remote_files
        variable l_local_files

        set l_script_data [list]
        set l_local_files [list]
        set l_remote_files [list]

        # get the project name
        set tcl_obj [current_project]
        set proj_name [file tail [get_property name $tcl_obj]]
        set proj_dir [get_property directory $tcl_obj]
        set part_name [get_property part $tcl_obj]

        # output file script handle
        set file $a_global_vars(script_file)
        if {[catch {open $file w} a_global_vars(fh)]} {
          send_msg_id Vivado-projutils-005 ERROR "failed to open file for write ($file)\n"
          return false
        }
  
        # dump project in canonical form
        if { $a_global_vars(b_arg_dump_proj_info) } {
          set dump_file "${proj_name}_dump.txt"
          if {[catch {open $dump_file w} a_global_vars(dp_fh)]} {
            send_msg_id Vivado-projutils-006 ERROR "failed to open file for write ($dump_file)\n"
            return false
          }
  
          # default value output file script handle
          set def_val_file "${proj_name}_def_val.txt"
          if {[catch {open $def_val_file w} a_global_vars(def_val_fh)]} {
            send_msg_id Vivado-projutils-007 ERROR "failed to open file for write ($file)\n"
            return false
          }
        }

        # writer helpers
        wr_create_project $proj_dir $proj_name
        wr_project_properties $proj_name
        wr_filesets $proj_name
        wr_runs $proj_name
        wr_proj_info $proj_name

        # write header
        write_header $proj_dir $proj_name $file

        # write script data
        foreach line $l_script_data {
          puts $a_global_vars(fh) $line
        }
  
        close $a_global_vars(fh)
  
        if { $a_global_vars(b_arg_dump_proj_info) } {
          close $a_global_vars(def_val_fh)
          close $a_global_vars(dp_fh)
        }

        set file [file normalize $file]
        send_msg_id Vivado-projutils-008 INFO "Tcl script generated ($file)\n"

        if { $a_global_vars(b_local_sources) } {
          print_local_file_msg "warning"
        } else {
          print_local_file_msg "info"
        }

        reset_global_vars

        return 1
    }

    proc wr_create_project { proj_dir name } {

        # Summary: write create project command 
        # This helper command is used to script help.
    
        # Argument Usage: 
        # proj_dir: project directory path
        # name: project name
    
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        variable a_global_vars
        variable l_script_data

        lappend l_script_data "# Set the original project directory path for adding/importing sources in the new project"
        lappend l_script_data "set orig_proj_dir \"$proj_dir\""
        lappend l_script_data ""
  
        # create project
        lappend l_script_data "# Create project"
        set tcl_cmd "create_project $name ./$name"
        if { [get_property managed_ip [current_project]] } {
          set tcl_cmd "$tcl_cmd -ip"
        }
        lappend l_script_data $tcl_cmd
  
        if { $a_global_vars(b_arg_dump_proj_info) } {
          puts $a_global_vars(dp_fh) "project_name=$name"
        }

        lappend l_script_data ""
        lappend l_script_data "# Set the directory path for the new project"
        lappend l_script_data "set proj_dir \[get_property directory \[current_project\]\]"
        lappend l_script_data ""

        return 0
    }

    proc wr_project_properties { proj_name } {

        # Summary: write project properties
        # This helper command is used to script help.
    
        # Argument Usage: 
        # proj_name: project name
        
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.
    
        variable l_script_data
        variable b_project_board_set

        # write project properties
        set tcl_obj [current_project]
        set get_what "get_projects"
    

        lappend l_script_data "# Set project properties"
        lappend l_script_data "set obj \[$get_what $tcl_obj\]"

        # is project "board" set already?
        if { [string length [get_property "board" $tcl_obj]] > 0 } {
          set b_project_board_set 1
        }

        write_props $proj_name $get_what $tcl_obj "project"

        return 0
    }

    proc wr_filesets { proj_name } {

        # Summary: write fileset object properties 
        # This helper command is used to script help.
    
        # Argument Usage: 
        # proj_name: project name
    
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        variable a_fileset_types

        # write fileset data
        foreach {fs_data} $a_fileset_types {
          set filesets [get_filesets -filter FILESET_TYPE==[lindex $fs_data 0]]
          write_specified_fileset $proj_name $filesets
        }
    
        return 0
    }

    proc write_specified_fileset { proj_name filesets } {

        # Summary: write fileset properties and sources 
        # This helper command is used to script help.
    
        # Argument Usage: 
        # proj_name: project name
        # filesets: list of filesets
    
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        variable a_global_vars
        variable l_script_data
        variable a_fileset_types

        # write filesets
        set type "file"
        foreach tcl_obj $filesets {

          set fs_type [get_property fileset_type [get_filesets $tcl_obj]]
  
          lappend l_script_data "# Create '$tcl_obj' fileset (if not found)"
          lappend l_script_data "if \{\[string equal \[get_filesets $tcl_obj\] \"\"\]\} \{"

          set fs_sw_type [get_fileset_type_switch $fs_type]
          lappend l_script_data "  create_fileset $fs_sw_type $tcl_obj"
          lappend l_script_data "\}\n"

          set get_what_fs "get_filesets"

          lappend l_script_data "# Add files to '$tcl_obj' fileset"
          lappend l_script_data "set obj \[$get_what_fs $tcl_obj\]"
          write_files $proj_name $tcl_obj $type

          lappend l_script_data "# Set '$tcl_obj' fileset properties"
          lappend l_script_data "set obj \[$get_what_fs $tcl_obj\]"
          write_props $proj_name $get_what_fs $tcl_obj "fileset"
    
          if { [string equal [get_property fileset_type [$get_what_fs $tcl_obj]] "Constrs"] } { continue }
        }

        return 0
    }

    proc wr_runs { proj_name } {

        # Summary: write runs and properties 
        # This helper command is used to script help.
    
        # Argument Usage: 
        # proj_name: project name
    
        # Return Value:
        # true - success.
        # TCL_OK is returned if the procedure completed successfully.

        # write runs (synthesis, Implementation)
        set runs [get_runs -filter {IS_SYNTHESIS == 1}]
        write_specified_run $proj_name $runs
      
        set runs [get_runs -filter {IS_IMPLEMENTATION == 1}]
        write_specified_run $proj_name $runs
    
        return 0
    }

    proc wr_proj_info { proj_name } {

        # Summary: write generated project status message 
        # This helper command is used to script help.
    
        # Argument Usage: 
        # proj_name: project name
    
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        variable l_script_data

        lappend l_script_data "\nputs \"INFO: Project created:$proj_name\""

        return 0
    }

    proc write_header { proj_dir proj_name file } {
    
        # Summary: write script header 
        # This helper command is used to script help.
    
        # Argument Usage: 
    
        # Return Value:
        # true - success.
        # TCL_OK is returned if the procedure completed successfully.

        variable a_global_vars
        variable l_local_files
        variable l_remote_files

        set curr_time   [clock format [clock seconds]]
        set version_txt [split [version] "\n"]
        set version     [lindex $version_txt 0]
        set copyright   [lindex $version_txt 2]
        set product     [lindex [split $version " "] 0]
        set version_id  [join [lrange $version 1 end] " "]

        set tcl_file [file tail $file]
        puts $a_global_vars(fh) "#\n# $product (TM) $version_id"
        puts $a_global_vars(fh) "#\n# $tcl_file: Tcl script for re-creating project '$proj_name'\n#"
        puts $a_global_vars(fh) "# Generated by $product on $curr_time"
        puts $a_global_vars(fh) "# $copyright"
        puts $a_global_vars(fh) "#\n# This file contains the $product Tcl commands for re-creating the project to the state*"
        puts $a_global_vars(fh) "# when this script was generated. In order to re-create the project, please source this"
        puts $a_global_vars(fh) "# file in the $product Tcl Shell."
        puts $a_global_vars(fh) "#"
        puts $a_global_vars(fh) "# * Note that the runs in the created project will be configured the same way as the"
        puts $a_global_vars(fh) "#   original project, however they will not be launched automatically. To regenerate the"
        puts $a_global_vars(fh) "#   run results please launch the synthesis/implementation runs as needed.\n#"
        puts $a_global_vars(fh) "#*****************************************************************************************"
        puts $a_global_vars(fh) "# NOTE: In order to use this script for source control purposes, please make sure that the"
        puts $a_global_vars(fh) "#       following files are added to the source control system:-"
        puts $a_global_vars(fh) "#"
        puts $a_global_vars(fh) "# 1. This project restoration tcl script (${tcl_file}) that was generated."
        puts $a_global_vars(fh) "#"
        puts $a_global_vars(fh) "# 2. The following source(s) files that were local or imported into the original project."
        puts $a_global_vars(fh) "#    (Please see the '\$orig_proj_dir' variable setting below at the start of the script)\n#"

        if {[llength $l_local_files] == 0} {
          puts $a_global_vars(fh) "#    <none>"
        } else {
          foreach line $l_local_files {
            puts $a_global_vars(fh) "#    $line"
          }
        }
        puts $a_global_vars(fh) "#"
        puts $a_global_vars(fh) "# 3. The following remote source files that were added to the original project:-\n#"
        if {[llength $l_remote_files] == 0} {
          puts $a_global_vars(fh) "#    <none>"
        } else {
          foreach line $l_remote_files {
            puts $a_global_vars(fh) "#    $line"
          }
        }
        puts $a_global_vars(fh) "#"
        puts $a_global_vars(fh) "#*****************************************************************************************\n"
      
        return 0
    }

    proc print_local_file_msg { msg_type } {

        # Summary: print warning on finding local sources 
        # This helper command is used to script help.
    
        # Argument Usage: 
        
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        puts ""
        if { [string equal $msg_type "warning"] } {
          send_msg_id Vivado-projutils-010 WARNING "Found source(s) that were local or imported into the project. If this project is being source controlled, then
                        please ensure that the project source(s) are also part of this source controlled data. The list of these local
                        source(s) can be found in the generated script under the header section."
        } else {
          send_msg_id Vivado-projutils-011 INFO "If this project is being source controlled, then please ensure that the project source(s) are also part of this source
                        controlled data. The list of these local source(s) can be found in the generated script under the header section."
        }
        puts ""
    
        return 0
    }

    proc filter { prop val } {

        # Summary: filter special properties
        # This helper command is used to script help.
    
        # Argument Usage: 
    
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        variable l_filetype_filter

        set prop [string toupper $prop]
        if { [expr { $prop == "IS_HD" } || \
                   { $prop == "IS_PARTIAL_RECONFIG" } || \
                   { $prop == "ADD_STEP" }]} {
          return true
        }

        #
        if { [string equal type "project"] } {
          if { [expr { $prop == "DIRECTORY" }] } {
            return true
          }
        }
      

        # error reported if file_type is set
        # e.g ERROR: [Vivado 12-563] The file type 'IP' is not user settable.
        set val  [string tolower $val]
        if { [string equal $prop "FILE_TYPE"] } {
          if { [lsearch $l_filetype_filter $val] != -1 } {
            return true
          }
        }
    
        return 0
    }

    proc is_local_to_project { file } {

        # Summary: check if file is local to the project directory structure 
        # This helper command is used to script help.
    
        # Argument Usage: 
    
        # Return Value:
        # true, if file is local to the project (inside project directory structure)
        # false, if file is outside the project directory structure

        set dir [get_property directory [current_project]]
        set proj_comps [split [string trim [file normalize [string map {\\ /} $dir]]] "/"]
        set file_comps [split [string trim [file normalize [string map {\\ /} $file]]] "/"]
        set is_local 1
        for {set i 1} {$i < [llength $proj_comps]} {incr i} {
          if { [lindex $proj_comps $i] != [lindex $file_comps $i] } {
            set is_local 0;break
          }
        }
    
        return $is_local
    }

    proc write_properties { prop_info_list get_what tcl_obj } {

        # Summary: write object properties
        # This helper command is used to script help.
        
        # Argument Usage: 
        
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        variable a_global_vars
        variable l_script_data

        if {[llength $prop_info_list] > 0} {
          foreach x $prop_info_list {
            set elem [split $x "#"]
            set name [lindex $elem 0]
            set value [lindex $elem 1]
            set cmd_str "set_property \"$name\" \"$value\""

            if { [string equal $get_what "get_files"] } {
              lappend l_script_data "$cmd_str \$file_obj"
            } else {
              # comment "is_readonly" project property
              if { [string equal $get_what "get_projects"] && [string equal "$name" "is_readonly"] } {
                if { ! $a_global_vars(b_arg_all_props) } {
                  send_msg_id Vivado-projutils-012 INFO "The current project is in 'read_only' state. The generated script will create a writable project."
                }
                continue
              }
              lappend l_script_data "$cmd_str \$obj"
            }
          }
        } 
        lappend l_script_data ""
    
        return true
    }

    proc write_props { proj_name get_what tcl_obj type } {

        # Summary: write first class object properties
        # This helper command is used to script help.
    
        # Argument Usage: 
    
        # Return Value:
        # none

        variable a_global_vars
        variable l_script_data
        variable b_project_board_set

        set obj_name [get_property name [$get_what $tcl_obj]]
        set read_only_props [rdi::get_attr_specs -class [get_property class $tcl_obj] -filter {is_readonly}]
        set prop_info_list [list]
        set properties [list_property [$get_what $tcl_obj]]

        foreach prop $properties {
          # skip read-only properties
          if { [lsearch $read_only_props $prop] != -1 } { continue }
      
          set prop_type "unknown"
          if { [string equal $type "run"] } {
            if { [regexp "STEPS" $prop] } {
              # skip step properties
            } else {
              set attr_names [rdi::get_attr_specs -class [get_property class [get_runs $tcl_obj] ]]
              set prop_type [get_property type [lindex $attr_names [lsearch $attr_names $prop]]]
            }
          } else {
            set prop_type [get_property type [rdi::get_attr_specs $prop -object [$get_what $tcl_obj]]]
          }
          set def_val [list_property_value -default $prop $tcl_obj]
          set dump_prop_name [string tolower ${obj_name}_${type}_$prop]
          set cur_val [get_property $prop $tcl_obj]

          # filter special properties
          if { [filter $prop $cur_val] } { continue }

          # do not set "runs" or "project" part, if "board" is set
          if { ([string equal $type "project"] || [string equal $type "run"]) && 
               [string equal -nocase $prop "part"] &&
               $b_project_board_set } {
            continue
          }

          # do not set "fileset" target_part, if "board" is set
          if { [string equal $type "fileset"] &&
               [string equal -nocase $prop "target_part"] &&
               $b_project_board_set } {
            continue
          }
      
          # re-align values
          set cur_val [get_target_bool_val $def_val $cur_val]

          set prop_entry "[string tolower $prop]#[get_property $prop [$get_what $tcl_obj]]"
      
          # fix paths wrt the original project dir
          if {([string equal -nocase $prop "top_file"]) && ($cur_val != "") } {
            set file $cur_val

            set srcs_dir "${proj_name}.srcs"
            set file_dirs [split [string trim [file normalize [string map {\\ /} $file]]] "/"]
            set src_file [join [lrange $file_dirs [lsearch -exact $file_dirs "$srcs_dir"] end] "/"]
      
            if { [is_local_to_project $file] } {
              set proj_file_path "\$proj_dir/$src_file"
            } else {
              set proj_file_path "\$orig_proj_dir/$src_file"
            }
            set prop_entry "[string tolower $prop]#$proj_file_path"

          } elseif {([string equal -nocase $prop "target_constrs_file"] ||
                     [string equal -nocase $prop "target_ucf"]) &&
                     ($cur_val != "") } {
       
            set file $cur_val
            set fs_name $tcl_obj

            set path_dirs [split [string trim [file normalize [string map {\\ /} $file]]] "/"]
            set src_file [join [lrange $path_dirs [lsearch -exact $path_dirs "$fs_name"] end] "/"]
            set file_object [lindex [get_files -of_objects $fs_name [list $file]] 0]
            set file_props [list_property $file_object]

            if { [lsearch $file_props "IMPORTED_FROM"] != -1 } {
              set proj_file_path "\$proj_dir/${proj_name}.srcs/$src_file"
            } else {
              # is file new inside project?
              if { [is_local_to_project $file] } {
                # is file inside fileset dir?
                if { [regexp "^${fs_name}/" $src_file] } {
                  set proj_file_path "\$orig_proj_dir/${proj_name}.srcs/$src_file"
                } else {
                  set proj_file_path "$file"
                }
              } else {
                set proj_file_path "$file"
              }
            }

            set prop_entry "[string tolower $prop]#$proj_file_path"
          }
 
          # re-align compiled_library_dir
          if {[string equal -nocase $prop "compxlib.compiled_library_dir"]} {
            set compile_lib_dir_path $cur_val
            set cache_dir "${proj_name}.cache"
            set path_dirs [split [string trim [file normalize [string map {\\ /} $cur_val]]] "/"]
            if {[lsearch -exact $path_dirs "$cache_dir"] > 0} {
              set dir_path [join [lrange $path_dirs [lsearch -exact $path_dirs "$cache_dir"] end] "/"]
              set compile_lib_dir_path "\$proj_dir/$dir_path"
            }
            set prop_entry "[string tolower $prop]#$compile_lib_dir_path"
          }
     
          if { $a_global_vars(b_arg_all_props) } {
            lappend prop_info_list $prop_entry
          } else {
            if { $def_val != $cur_val } {
              lappend prop_info_list $prop_entry
            }
          }

          if { $a_global_vars(b_arg_dump_proj_info) } {
            if { ([string equal -nocase $prop "top_file"] ||
                  [string equal -nocase $prop "target_constrs_file"] ||
                  [string equal -nocase $prop "target_ucf"] ) && [string equal $type "fileset"] } {

              # fix path
              set file $cur_val

              set srcs_dir "${proj_name}.srcs"
              set file_dirs [split [string trim [file normalize [string map {\\ /} $file]]] "/"]
              set src_file [join [lrange $file_dirs [lsearch -exact $file_dirs "$srcs_dir"] end] "/"]
              set cur_val "\$PSRCDIR/$src_file"
            }
            puts $a_global_vars(def_val_fh) "$prop:($prop_type) DEFAULT_VALUE ($def_val)==CURRENT_VALUE ($cur_val)"
            puts $a_global_vars(dp_fh) "${dump_prop_name}=$cur_val"
          }
        }
      
        # write properties now
        write_properties $prop_info_list $get_what $tcl_obj
    
    }

    proc write_files { proj_name tcl_obj type } {

        # Summary: write file and file properties 
        # This helper command is used to script help.
    
        # Argument Usage: 
    
        # Return Value:
        # none

        variable a_global_vars
        variable l_script_data

        set l_local_file_list [list]
        set l_remote_file_list [list]

        # return if empty fileset
        if {[llength [get_files -quiet -of_objects $tcl_obj]] == 0 } {
          lappend l_script_data "# Empty (no sources present)\n"
          return
        }

        set fs_name [get_filesets $tcl_obj]

        set import_coln [list]
        set file_coln [list]

        foreach file [lsort [get_files -norecurse -of_objects $tcl_obj]] {
          set path_dirs [split [string trim [file normalize [string map {\\ /} $file]]] "/"]
          set src_file [join [lrange $path_dirs [lsearch -exact $path_dirs "$fs_name"] end] "/"]

          # fetch first object
          set file_object [lindex [get_files -of_objects $fs_name [list $file]] 0]
          set file_props [list_property $file_object]
      
          if { [lsearch $file_props "IMPORTED_FROM"] != -1 } {

            # import files
            set imported_path [get_property "imported_from" $file]
            set proj_file_path "\$orig_proj_dir/${proj_name}.srcs/$src_file"
            set file "\"$proj_file_path\""
            lappend l_local_file_list $file

            # add to the import collection
            lappend import_coln "\"$proj_file_path\""

          } else {
            set file "\"$file\""

            # is local? add to local project, add to collection and then import this collection by default unless -no_copy_sources is specified
            if { [is_local_to_project $file] } {
              if { $a_global_vars(b_arg_dump_proj_info) } {
                set src_file "\$PSRCDIR/$src_file"
              }

              # add to the import collection
              lappend import_coln $file
              lappend l_local_file_list $file
            } else {
              lappend l_remote_file_list $file
            }
      
            # add file to collection
            lappend file_coln "$file"

            # set flag that local sources were found and print warning at the end
            if { !$a_global_vars(b_local_sources) } {
              set a_global_vars(b_local_sources) 1
            }
          }
        }
         
        if {[llength $file_coln]>0} { 
          lappend l_script_data "set files \[list \\"
          foreach file $file_coln {
            lappend l_script_data " $file\\"
          }
          lappend l_script_data "\]"
          lappend l_script_data "add_files -norecurse -fileset \$obj \$files"
          lappend l_script_data ""
        }

        # now import local files if -no_copy_sources is not specified
        if { ! $a_global_vars(b_arg_no_copy_srcs)} {
          if { [llength $import_coln] > 0 } {
            lappend l_script_data "# Import local files from the original project"
            lappend l_script_data "set files \[list \\"
            foreach ifile $import_coln {
              lappend l_script_data " $ifile\\"
            }
            lappend l_script_data "\]"
            lappend l_script_data "set imported_files \[import_files -fileset $tcl_obj \$files\]"
            lappend l_script_data ""
          }
        }

        # write fileset file properties for remote files (added sources)
        write_fileset_file_properties $tcl_obj $fs_name $l_remote_file_list "remote"

        # write fileset file properties for local files (imported sources)
        write_fileset_file_properties $tcl_obj $fs_name $l_local_file_list "local"

    }

    proc write_specified_run { proj_name runs } {

        # Summary: write the specified run information 
        # This helper command is used to script help.
        
        # Argument Usage: 
        
        # Return Value:
        # none 

        variable a_global_vars
        variable l_script_data

        set get_what "get_runs"
        foreach tcl_obj $runs {
          # fetch run attributes
          set part         [get_property part [$get_what $tcl_obj]]
          set parent_run   [get_property parent [$get_what $tcl_obj]]
          set src_set      [get_property srcset [$get_what $tcl_obj]]
          set constrs_set  [get_property constrset [$get_what $tcl_obj]]
          set strategy     [get_property strategy [$get_what $tcl_obj]]
          set parent_run_str ""
          if  { $parent_run != "" } {
            set parent_run_str " -parent_run $parent_run"
          }

          set def_flow_type_val  [list_property_value -default flow [$get_what $tcl_obj]]
          set cur_flow_type_val  [get_property flow [$get_what $tcl_obj]]
          set def_strat_type_val [list_property_value -default strategy [$get_what $tcl_obj]]
          set cur_strat_type_val [get_property strategy [$get_what $tcl_obj]]

          lappend l_script_data "# Create '$tcl_obj' run (if not found)"
          lappend l_script_data "if \{\[string equal \[get_runs $tcl_obj\] \"\"\]\} \{"
          set cmd_str "  create_run -name $tcl_obj -part $part -flow {$cur_flow_type_val} -strategy \"$cur_strat_type_val\""
          lappend l_script_data "$cmd_str -constrset $constrs_set$parent_run_str"
          lappend l_script_data "\}"
  
          lappend l_script_data "set obj \[$get_what $tcl_obj\]"
          write_props $proj_name $get_what $tcl_obj "run"
        }
    }

    proc get_fileset_type_switch { fileset_type } {

       # Summary: Return the fileset type switch for a given fileset
        
       # Argument Usage: 
        
       # Return Value:
       # Fileset type switch name

       variable a_fileset_types
       
       set fs_switch ""
       foreach {fs_data} $a_fileset_types {
         set fs_type [lindex $fs_data 0]
         if { [string equal -nocase $fileset_type $fs_type] } {
           set fs_switch [lindex $fs_data 1]
           set fs_switch "-$fs_switch"
           break
         }
       }
       return $fs_switch
    }

    proc get_target_bool_val { def_val cur_val } {

       # Summary: Resolve current boolean property value wrt its default value
        
       # Argument Usage: 
        
       # Return Value:
       # Resolved boolean value
  
       set target_val $cur_val 

       if { [string equal $def_val "false"] && [string equal $cur_val "0"] } { set target_val "false" } \
       elseif { [string equal $def_val "true"]  && [string equal $cur_val "1"] } { set target_val "true"  } \
       elseif { [string equal $def_val "false"] && [string equal $cur_val "1"] } { set target_val "true"  } \
       elseif { [string equal $def_val "true"]  && [string equal $cur_val "0"] } { set target_val "false" } \
       elseif { [string equal $def_val "{}"]    && [string equal $cur_val ""]  } { set target_val "{}" }

       return $target_val
   }

   proc write_fileset_file_properties { tcl_obj fs_name l_file_list file_category } {

       # Summary: 
       # Write fileset file properties for local and remote files
        
       # Argument Usage: 
       # tcl_obj: object to inspect
       # fs_name: fileset name
       # l_file_list: list of files (local or remote)
       # file_category: file catwgory (local or remote)
        
       # Return Value:
       # none

       variable a_global_vars
       variable l_script_data
       variable l_local_files
       variable l_remote_files

       lappend l_script_data "# Set '$tcl_obj' fileset file properties for $file_category files"
       set file_prop_count 0

       # collect local/remote files
       foreach file $l_file_list {
         if { [string equal $file_category "local"] } {
           lappend l_local_files $file
         } elseif { [string equal $file_category "remote"] } {
           lappend l_remote_files $file
         } else {}
       }
        
       foreach file $l_file_list {
         set file [string trim $file "\""]
       
         # fix file path for local files
         if { [string equal $file_category "local"] } {
           set path_dirs [split [string trim [file normalize [string map {\\ /} $file]]] "/"]
           set src_file [join [lrange $path_dirs end-1 end] "/"]
           set src_file [string trimleft $src_file "/"]
           set src_file [string trimleft $src_file "\\"]
           set file $src_file
         }

         set file_object ""
         if { [string equal $file_category "local"] } {
           set file_object [lindex [get_files -of_objects $fs_name [list "*$file"]] 0]
         } elseif { [string equal $file_category "remote"] } {
           set file_object [lindex [get_files -of_objects $fs_name [list $file]] 0]
         }

         set file_props [list_property $file_object]
         set prop_info_list [list]
         set prop_count 0

         foreach file_prop $file_props {
           set is_readonly [get_property is_readonly [rdi::get_attr_specs $file_prop -object $file_object]]
           if { [string equal $is_readonly "1"] } {
             continue
           }

           set prop_type [get_property type [rdi::get_attr_specs $file_prop -object $file_object]]
           set def_val [list_property_value -default $file_prop $file_object]
           set cur_val [get_property $file_prop $file_object]

           # filter special properties
           if { [filter $file_prop $cur_val] } { continue }

           # re-align values
           set cur_val [get_target_bool_val $def_val $cur_val]

           set dump_prop_name [string tolower ${fs_name}_file_${file_prop}]
           set prop_entry ""
           if { [string equal $file_category "local"] } {
             set prop_entry "[string tolower $file_prop]#[get_property $file_prop $file_object]"
           } elseif { [string equal $file_category "remote"] } {
             set prop_value_entry [get_property $file_prop $file_object]
             set prop_entry "[string tolower $file_prop]#$prop_value_entry"
           } else {}

           if { $a_global_vars(b_arg_all_props) } {
             lappend prop_info_list $prop_entry
             incr prop_count
           } else {
             if { $def_val != $cur_val } {
               lappend prop_info_list $prop_entry
               incr prop_count
             }
           }

           if { $a_global_vars(b_arg_dump_proj_info) } {
             puts $a_global_vars(def_val_fh) "[file tail $file]=$file_prop ($prop_type) :DEFAULT_VALUE ($def_val)==CURRENT_VALUE ($cur_val)"
             puts $a_global_vars(dp_fh) "$dump_prop_name=$cur_val"
           }
         }

         # write properties now
         if { $prop_count>0 } {
           lappend l_script_data "set file \"$file\""
           lappend l_script_data "set file_obj \[get_files -of_objects $tcl_obj \[list \"*\$file\"\]\]"
           set get_what "get_files"
           write_properties $prop_info_list $get_what $tcl_obj
           incr file_prop_count
         }
       }

       if { $file_prop_count == 0 } {
         lappend l_script_data "# None"
       }
       lappend l_script_data ""
   }

   #
   # Export simulation files helpers
   #
   proc set_default_source_object {} {

       # Summary: If -of_objects not specified, then for managed-ip project error out
       #          or set active simulation fileset for an RTL/GateLvl project

       # Argument Usage:
       # none

       # Return Value:
       # true (1) if success, false (0) otherwise

       variable a_global_sim_vars
       set tcl_obj $a_global_sim_vars(s_of_objects)
       if { [string length $tcl_obj] == 0 } {
         if { $a_global_sim_vars(b_is_managed) } {
           set ips [get_ips]
           if {[llength $ips] == 0} {
             send_msg_id Vivado-projutils-016 INFO "No IP's found in the current project.\n"
             return 0
           }
           # object not specified, error
           send_msg_id Vivado-projutils-038 ERROR "Missing source IP object. Please type 'export_simulation_files -help' for usage info.\n"
           return 0
         } else {
           set curr_simset [current_fileset -simset]
           set sim_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_filesets $curr_simset]]
           if { [llength $sim_files] == 0 } {
             send_msg_id Vivado-projutils-017 INFO "No simulation files found in the current simset.\n"
             return 0
           }
           set a_global_sim_vars(s_of_objects) $curr_simset
         }
       } else {
         # is valid tcl object?
         if { ![is_ip $tcl_obj] } {
           if { [is_fileset $tcl_obj] } {
             set fs_type [get_property fileset_type [get_filesets $tcl_obj]]
             if { [string equal -nocase $fs_type "Constrs"] } {
               send_msg_id Vivado-projutils-037 ERROR "Invalid object type specified\n"
               return 0
             }
           }
         }
       }
       return 1
   }

   proc write_sim_script {} {

       # Summary: Get the compiled order for the specified source object and export files

       # Argument Usage:
       # none

       # Return Value:
       # true (1) if success, false (0) otherwise

       variable a_global_sim_vars

       set tcl_obj $a_global_sim_vars(s_of_objects)

       if { [is_ip $tcl_obj] } {
         export_sim_files_for_ip $tcl_obj
       } elseif { [is_fileset $tcl_obj] } {
         export_sim_files_for_fs $tcl_obj
       } else {
         send_msg_id Vivado-projutils-020 INFO "Unsupported object source: $tcl_obj\n"
         return 0
       }

       send_msg_id Vivado-projutils-021 INFO "Simulation file generated:$a_global_sim_vars(s_sim_files_dir)/$a_global_sim_vars(s_filelist)\n"

       return 1
   }

   proc export_sim_files_for_ip { tcl_obj } {

       # Summary: 

       # Argument Usage:
       # source object

       # Return Value:
       # true (1) if success, false (0) otherwise
     
       variable a_global_sim_vars
 
       set obj_name [file root [file tail $tcl_obj]]
       set ip_filename [file tail $tcl_obj]
       set compile_order_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_filename]]

       set ip_name [file root $ip_filename]
       set a_global_sim_vars(s_filelist) "filelist_${ip_name}.f"
       export_simulation_files_for_object $obj_name $compile_order_files

       # fetch ip data files and export to output dir
       export_ip_data_files $ip_filename
   }

   proc export_sim_files_for_fs { tcl_obj } {

       # Summary: 

       # Argument Usage:
       # source object

       # Return Value:
       # true (1) if success, false (0) otherwise
       
       variable a_global_sim_vars
 
       set obj_name $tcl_obj
       set used_in_val "simulation"
       switch [get_property fileset_type [get_filesets $tcl_obj]] {
         "DesignSrcs"     { set used_in_val "synthesis" }
         "SimulationSrcs" { set used_in_val "simulation"}
         "BlockSrcs"      { set used_in_val "synthesis" }
       }

       set compile_order_files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $tcl_obj]]

       if { [llength $compile_order_files] == 0 } {
         send_msg_id Vivado-projutils-018 INFO "Empty fileset: $obj_name\n"
         return 0
       } else {
         set a_global_sim_vars(s_filelist) "filelist_${obj_name}.f"
         export_simulation_files_for_object $obj_name $compile_order_files

         # fetch data files for all IP's in simset and export to output dir
         export_fileset_ip_data_files
       }
   }

   proc is_ip { obj } {

       # Summary: Determine if specified source object is IP

       # Argument Usage:
       # source object

       # Return Value:
       # true (1) if success, false (0) otherwise
      
       variable l_valid_ip_extns 

       if { [lsearch -exact $l_valid_ip_extns [file extension $obj]] >= 0 } {
         return 1
       }
       return 0
   }

   proc is_fileset { obj } {

       # Summary: Determine if specified source object is fileset

       # Argument Usage:
       # source object

       # Return Value:
       # true (1) if success, false (0) otherwise

       if {[string equal [rdi::get_attr_specs FILESET_TYPE -object $obj] "FILESET_TYPE"]} {
         return 1
       }

       return 0
   }

   proc set_simulator_name {} {

       # Summary: Set simulator name for the specified simulator type

       # Argument Usage:
       # none

       # Return Value:
       # True (1) if name set, false (0) otherwise

       variable a_global_sim_vars
       set simulator $a_global_sim_vars(s_simulator)
       switch -regexp -- $simulator {
         "modelsim" { set a_global_sim_vars(s_simulator_name) "Mentor Graphics ModelSim" }
         "ies"      { set a_global_sim_vars(s_simulator_name) "Cadence Incisive Enterprise" }
         "vcs_mx"   { set a_global_sim_vars(s_simulator_name) "Synopsys VCS MX" }
         "xsim"     { set a_global_sim_vars(s_simulator_name) "Xilinx Vivado Simulator" }
         default {
           send_msg_id Vivado-projutils-026 ERROR "Invalid simulator ($simulator)\n"
           close $fh
           return 0
         }
       }
       return 1
   }

   proc create_sim_files_dir {} {

       # Summary: Create output directory where simulation files will be generated. Delete previous
       #          files if overwrite requested (-force)

       # Argument Usage:
       # none

       # Return Value:
       # true (1) if success, false (0) otherwise

       variable a_global_sim_vars

       if { [string length $a_global_sim_vars(s_sim_files_dir)] == 0 } {
         send_msg_id Vivado-projutils-039 ERROR "Missing directory value. Please specify the output directory path for the exported files.\n"
         return 0
       }

       set dir [file normalize [string map {\\ /} $a_global_sim_vars(s_sim_files_dir)]]

       if { ! [file exists $dir] } {
         if {[catch {file mkdir $dir} error_msg] } {
           send_msg_id Vivado-projutils-023 ERROR "failed to create the directory ($dir): $error_msg\n"
           return 0
         }
       }
       set a_global_sim_vars(s_sim_files_dir) $dir
       return 1
   }

   proc export_simulation_files_for_object { obj_name compile_order_files } {

       # Summary: Open files and write compile order for the target simulator

       # Argument Usage:
       # obj_name - source object
       # compile_order_files - list of compile order files

       # Return Value:
       # true (1) if success, false (0) otherwise

       variable a_global_sim_vars
       
       set file [file normalize [file join $a_global_sim_vars(s_sim_files_dir) $a_global_sim_vars(s_filelist)]]

 	   # recommend -force if file exists
 	   if { [file exists $file] && (!$a_global_sim_vars(b_overwrite_sim_files_dir)) } {
         send_msg_id Vivado-projutils-034 ERROR "Simulation file '$file' already exist. Use -force option to overwrite."
 	     return 0
 	   }
         
       if { [file exists $file] } {
         if {[catch {file delete -force $file} error_msg] } {
           send_msg_id Vivado-projutils-035 ERROR "failed to delete file ($file): $error_msg\n"
           return 0
         }
       }

       set fh 0
       if {[catch {open $file w} fh]} {
         send_msg_id Vivado-projutils-025 ERROR "failed to open file to write ($file)\n"
         return 0
       }

       send_msg_id Vivado-projutils-024 INFO \
         "Generating simulation files for $a_global_sim_vars(s_simulator_name) simulator (design object=$obj_name)...\n"

       if { $a_global_sim_vars(b_incl_compile_commmands) } {
         # include compiler command/options
         if { ! [write_compile_commands $compile_order_files $fh] } {
           return 0
         }
       } else {
         # plain filelist
         if { ! [write_filelist $compile_order_files $fh] } {
           return 0
         }
       }
       close $fh

       # contains verilog sources? copy glbl to output dir
       if { [is_verilog $compile_order_files] } {
         export_glbl_file
       }

       return 1
   }

   proc write_compile_commands { compile_order_files fh } {

       # Summary: Add compilation switches for simulator

       # Argument Usage:
       # compile_order_files - compile order 
       # fh   - file handle

       # Return Value:
       # none

       variable a_global_sim_vars

       send_msg_id Vivado-projutils-041 INFO "Writing filelist with compilation options...\n"

       # write vlib/vmap commands for ModelSim
       switch -regexp -- $a_global_sim_vars(s_simulator) {
         "modelsim" { write_lib_map_commands_for_modelsim $compile_order_files $fh }
       }

       foreach file $compile_order_files {
         switch -regexp -- $a_global_sim_vars(s_simulator) {
           "modelsim" { wr_compile_cmds_modelsim $file $fh }
           "ies"      { wr_compile_cmds_ies $file $fh }
           "vcs_mx"   { wr_compile_cmds_vcs_mx $file $fh }
           "xsim"     { wr_compile_cmds_xsim $file $fh }
           default {
             send_msg_id Vivado-projutils-026 ERROR "Invalid simulator ($a_global_sim_vars(s_simulator))\n"
             close $fh
             return 0
           }
         }
       }

       # add glbl
       if { [is_verilog $compile_order_files] } {
         set file_str "-work work ./glbl.v"
         switch -regexp -- $a_global_sim_vars(s_simulator) {
           "modelsim" { puts $fh "vlog $file_str" }
           "ies"      { puts $fh "ncvlog $file_str" }
           "vcs_mx"   { puts $fh "vlogan $file_str" }
           "xsim"     { puts $fh "verilog $file_str" }
           default {
             send_msg_id Vivado-projutils-026 ERROR "Invalid simulator ($a_global_sim_vars(s_simulator))\n"
             close $fh
             return 0
           }
         }
       }

       return 1
   }

   proc write_filelist { compile_order_files fh } {

       # Summary: Add compilation switches for simulator

       # Argument Usage:
       # compile_order_files - compile order 
       # fh   - file handle

       # Return Value:
       # none

       variable a_global_sim_vars

       send_msg_id Vivado-projutils-042 INFO "Writing filelist...\n"

       switch -regexp -- $a_global_sim_vars(s_simulator) {
         "modelsim" { wr_filelist_modelsim $compile_order_files $fh }
         "ies"      { wr_filelist_ies $compile_order_files $fh }
         "vcs_mx"   { wr_filelist_vcs_mx $compile_order_files $fh }
         "xsim"     { wr_filelist_xsim $compile_order_files $fh }
         default {
           send_msg_id Vivado-projutils-027 ERROR "Invalid simulator ($a_global_sim_vars(s_simulator))\n"
           close $fh
           return 0
         }
       }

       # add glbl
       if { [is_verilog $compile_order_files] } {
         set file_str "\"./glbl.v\""
         switch -regexp -- $a_global_sim_vars(s_simulator) {
           "modelsim" { puts $fh "$file_str" }
           "ies"      { puts $fh "$file_str" }
           "vcs_mx"   { puts $fh "$file_str" }
           "xsim"     { puts $fh "$file_str" }
           default {
             send_msg_id Vivado-projutils-026 ERROR "Invalid simulator ($a_global_sim_vars(s_simulator))\n"
             close $fh
             return 0
           }
         }
       }
       return 1
   }

   proc write_lib_map_commands_for_modelsim { compile_order_files fh } {

       # Summary: Add library mapping commands for the ModelSim simulator

       # Argument Usage:
       # file - compile order RTL file
       # fh   - file handle

       # Return Value:
       # none

       variable a_global_sim_vars

       set compile_order_libs [get_compile_order_libs $compile_order_files]

       set num_libs [llength $compile_order_libs]

       # create/map library's
       puts $fh "vlib work"
       foreach library $compile_order_libs {
         if { [string equal $library "work"] } {continue; }
         puts $fh "vlib msim/$library"
       }
       if {[llength $num_libs] > 1} {
         puts $fh ""
       }

       # map libraries
       foreach library $compile_order_libs {
         if { [string equal $library "work"] } { continue; }
         puts $fh "vmap $library msim/$library"
       }

       if {[llength $num_libs] > 1} {
         puts $fh ""
       }
   }

   proc wr_compile_cmds_modelsim { file fh } {

       # Summary: Add compilation switches for the ModelSim simulator

       # Argument Usage:
       # file - compile order RTL file
       # fh   - file handle

       # Return Value:
       # none

       variable a_global_sim_vars

       set cmd_str [list]
       set file_type [get_property file_type [get_files -quiet -all $file]]
       set associated_library [get_property library [get_files -quiet -all $file]]
       set file [get_relative_file_path $file]
       switch -regexp -nocase -- $file_type {
         "vhd" {
           set tool "vcom"
           lappend cmd_str $tool
           append_compiler_options $tool cmd_str
           lappend cmd_str "-work"
           lappend cmd_str "$associated_library"
           lappend cmd_str "\"$file\""
         }
         "verilog" {
           set tool "vlog"
           lappend cmd_str $tool
           append_compiler_options $tool cmd_str
           lappend cmd_str "-work"
           lappend cmd_str "$associated_library"
           lappend cmd_str "\"$file\""
         }
         default {
           send_msg_id Vivado-projutils-029 WARNING "Unknown file type '$file_type'\n"
         }
       }
      
       set cmd [join $cmd_str " "]
       puts $fh $cmd

   }

   proc wr_compile_cmds_ies { file fh } {

       # Summary: Add compilation switches for the IES simulator

       # Argument Usage:
       # file - compile order RTL file
       # fh   - file handle

       # Return Value:
       # none

       variable a_global_sim_vars

       set cmd_str [list]
       set file_type [get_property file_type [get_files -quiet -all $file]]
       set associated_library [get_property library [get_files -quiet -all $file]]
       set file [get_relative_file_path $file]
       switch -regexp -nocase -- $file_type {
         "vhd" {
           set tool "ncvhdl"
           lappend cmd_str $tool
           append_compiler_options $tool cmd_str
           lappend cmd_str "-work"
           lappend cmd_str "$associated_library"
           lappend cmd_str "\"$file\""
         }
         "verilog" {
           set tool "ncvlog"
           lappend cmd_str $tool
           append_compiler_options $tool cmd_str
           lappend cmd_str "-work"
           lappend cmd_str "$associated_library"
           lappend cmd_str "\"$file\""
         }
         default {
           send_msg_id Vivado-projutils-028 WARNING "Unknown file type '$file_type'\n"
         }
       }
      
       set cmd [join $cmd_str " "]
       puts $fh $cmd

   }

   proc wr_compile_cmds_vcs_mx { file fh } {

       # Summary: Add compilation switches for the VCS simulator

       # Argument Usage:
       # file - compile order RTL file
       # fh   - file handle

       # Return Value:
       # none

       variable a_global_sim_vars

       set cmd_str [list]
       set file_type [get_property file_type [get_files -quiet -all $file]]
       set associated_library [get_property library [get_files -quiet -all $file]]
       set file [get_relative_file_path $file]
       switch -regexp -nocase -- $file_type {
         "vhd" {
           set tool "vhdlan"
           lappend cmd_str $tool
           append_compiler_options $tool cmd_str
           lappend cmd_str "-work"
           lappend cmd_str "$associated_library"
           lappend cmd_str "$file"
         }
         "verilog" {
           set tool "vlogan"
           lappend cmd_str $tool
           append_compiler_options $tool cmd_str
           lappend cmd_str "-work"
           lappend cmd_str "$associated_library"
           lappend cmd_str "$file"
         }
         default {
           send_msg_id Vivado-projutils-029 WARNING "Unknown file type '$file_type'\n"
         }
       }
      
       set cmd [join $cmd_str " "]
       puts $fh $cmd

   }

   proc wr_compile_cmds_xsim { file fh } {

       # Summary: Add compilation switches for the Vivado simulator

       # Argument Usage:
       # file - compile order RTL file
       # fh   - file handle

       # Return Value:
       # none

       variable a_global_sim_vars

       set cmd_str [list]
       set file_type [get_property file_type [get_files -quiet -all $file]]
       set associated_library [get_property library [get_files -quiet -all $file]]
       set file [get_relative_file_path $file]
       switch -regexp -nocase -- $file_type {
         "vhd" {
           set tool "vhdl"
           lappend cmd_str $tool
           append_compiler_options $tool cmd_str
           lappend cmd_str "-work"
           lappend cmd_str "$associated_library"
           lappend cmd_str "\"$file\""
         }
         "verilog" {
           set tool "verilog"
           lappend cmd_str $tool
           append_compiler_options $tool cmd_str
           lappend cmd_str "-work"
           lappend cmd_str "$associated_library"
           lappend cmd_str "\"$file\""
         }
         default {
           send_msg_id Vivado-projutils-029 WARNING "Unknown file type '$file_type'\n"
         }
       }
      
       set cmd [join $cmd_str " "]
       puts $fh $cmd

   }

   proc wr_filelist_modelsim { compile_order_files fh } {

       # Summary: Write simple compile order filelist for the ModelSim simulator

       # Argument Usage:
       # compile_order_files - list of design files
       # fh - file handle

       # Return Value:
       # none

       variable a_global_sim_vars

       # verilog include dirs?
       set incl_dirs      [find_verilog_incl_dirs]
       set incl_file_dirs [find_verilog_incl_file_dirs]
       if {[llength $incl_file_dirs] > 0} {
         lappend incl_dirs $incl_file_dirs
       }
       if { [llength $incl_dirs] > 0 } {
         set incl_dirs [lsort -unique $incl_dirs]
         puts $fh "+incdir+\"[join $incl_dirs \"\n\-incdir\ \"]\""
       }

       set work_lib "work"

       foreach file $compile_order_files {
         set lib [get_property library [get_files -quiet -all $file]]
         set file [get_relative_file_path $file]
         puts $fh "\"$file\" // library $lib"
       }
   }

   proc wr_filelist_ies { compile_order_files fh } {

       # Summary: Write simple compile order filelist for the IES simulator

       # Argument Usage:
       # compile_order_files - list of design files
       # fh - file handle

       # Return Value:
       # none

       variable a_global_sim_vars

       # verilog include dirs?
       set incl_dirs      [find_verilog_incl_dirs]
       set incl_file_dirs [find_verilog_incl_file_dirs]
       if {[llength $incl_file_dirs] > 0} {
         lappend incl_dirs $incl_file_dirs
       }
       if { [llength $incl_dirs] > 0 } {
         set incl_dirs [lsort -unique $incl_dirs]
         puts $fh "-incdir \"[join $incl_dirs \"\n\-incdir\ \"]\""
       }

       set work_lib "work"
       set prev_lib $work_lib

       foreach file $compile_order_files {
         set curr_lib [get_property library [get_files -quiet -all $file]]
         if { $prev_lib != $curr_lib } {
           # start of library files set
           if { $curr_lib != $work_lib } {
             puts $fh "-V93 -makelib ${curr_lib}"
           }
           # end of library files set
           if { $prev_lib != $work_lib } {
             puts $fh "-endlib"
           }
         }
         set file [get_relative_file_path $file]
         puts $fh "\"$file\""
         # reset previous library to current
         set prev_lib $curr_lib
       }
   }

   proc wr_filelist_vcs_mx { compile_order_files fh } {

       # Summary: Write simple compile order filelist for the VCS simulator

       # Argument Usage:
       # compile_order_files - list of design files
       # fh - file handle

       # Return Value:
       # none

       variable a_global_sim_vars

       # verilog include dirs?
       set incl_dirs      [find_verilog_incl_dirs]
       set incl_file_dirs [find_verilog_incl_file_dirs]
       if {[llength $incl_file_dirs] > 0} {
         lappend incl_dirs $incl_file_dirs
       }
       if { [llength $incl_dirs] > 0 } {
         set incl_dirs [lsort -unique $incl_dirs]
         puts $fh "+incdir+[join $incl_dirs \"\n\-incdir\ \"]"
       }

       foreach file $compile_order_files {
         set lib [get_property library [get_files -quiet -all $file]]
         set file [get_relative_file_path $file]
         puts $fh "$file // library $lib"
       }
   }

   proc wr_filelist_xsim { compile_order_files fh } {

       # Summary: Write simple compile order filelist for the Vivado simulator

       # Argument Usage:
       # compile_order_files - list of design files
       # fh - file handle

       # Return Value:
       # none

       variable a_global_sim_vars

       # verilog include dirs?
       set incl_dirs      [find_verilog_incl_dirs]
       set incl_file_dirs [find_verilog_incl_file_dirs]
       if {[llength $incl_file_dirs] > 0} {
         lappend incl_dirs $incl_file_dirs
       }
       if { [llength $incl_dirs] > 0 } {
         set incl_dirs [lsort -unique $incl_dirs]
         puts $fh "-i \"[join $incl_dirs \"\n\-i\ \"]\""
       }

       set work_lib "work"

       foreach file $compile_order_files {
         set lib [get_property library [get_files -quiet -all $file]]
         set file [get_relative_file_path $file]
         puts $fh "\"$file\" // library $lib"
       }
   }

   proc append_compiler_options { tool opts_arg } {

       # Summary: Add switches (options) for the target compiler tool

       # Argument Usage:
       # tool - compiler name
       # opts_arg - options list to be appended

       # Return Value:
       # none

       upvar $opts_arg opts

       variable a_global_sim_vars

       # verilog include directories
       set incl_dirs [find_verilog_incl_dirs]

       # verilog include file directories
       set incl_file_dirs [find_verilog_incl_file_dirs]
  
       set machine $::tcl_platform(machine)
       switch $tool {
         "vhdl" {
         }
         "verilog" {
         }
         "vcom" {
           lappend opts "-93"
         }
         "vlog" {
           foreach dir $incl_dirs {
             lappend opts "+incdir+\"$dir\""
           }
           foreach dir $incl_file_dirs {
             lappend opts "+incdir+\"$dir\""
           }
         }
         "ncvhdl" {
           lappend opts "-V93"
           lappend opts "-RELAX"
           if { [regexp {_64} $machine] } {
             lappend opts "-64bit"
           }
           lappend opts "-logfile"
           lappend opts "$tool.log"
           lappend opts "-append_log"
         }
         "ncvlog" {
           if { [regexp {_64} $machine] } {
             lappend opts "-64bit"
           }
           lappend opts "-messages"
           #lappend opts "+define+SVG"
           lappend opts "-logfile"
           lappend opts "$tool.log"
           lappend opts "-append_log"
           foreach dir $incl_dirs {
             lappend opts "+incdir+\"$dir\""
           }
           foreach dir $incl_file_dirs {
             lappend opts "+incdir+\"$dir\""
           }
         }
         "vhdlan" {
           lappend opts "-93"
           if { [regexp {_64} $machine] } {
             lappend opts "-full64"
           }
           lappend opts "-l"
           lappend opts "$tool.log"
         }
         "vlogan" {
           lappend opts "+v2k"
           if { [regexp {_64} $machine] } {
             lappend opts "-full64"
           }
           #lappend opts "+define+SVG"
           lappend opts "-l"
           lappend opts "$tool.log"
           foreach dir $incl_dirs {
             lappend opts "+incdir+\"$dir\""
           }
           foreach dir $incl_file_dirs {
             lappend opts "+incdir+\"$dir\""
           }
         }
         default {
           send_msg_id Vivado-projutils-036 ERROR "Unknown compiler name '$tool'\n"
         }
       }
   }

   proc find_verilog_incl_dirs { } {

       # Summary: Get the verilog include directory paths

       # Argument Usage:
       # none

       # Return Value:
       # Sorted unique list of verilog include directories (if any)
 
       variable a_global_sim_vars

       set dir_names [list]
 
       set tcl_obj $a_global_sim_vars(s_of_objects)
       if { [is_ip $tcl_obj] } {
         set incl_dir_str [find_incl_dirs_from_ip $tcl_obj]
       } else {
         set incl_dir_str [get_property include_dirs [get_filesets $tcl_obj]]
       }

       set incl_dirs [split $incl_dir_str " "]
       foreach vh_dir $incl_dirs {
         lappend dir_names [file normalize $vh_dir]
       }
       return [lsort -unique $dir_names]
   }

   proc find_verilog_incl_file_dirs {} {

       # Summary: Get the verilog include directory paths for files of type "Verilog Header"

       # Argument Usage:
       # none

       # Return Value:
       # Sorted unique list of verilog include directory paths for files of type "Verilog Header"

       variable a_global_sim_vars

       set dir_names [list]

       set tcl_obj $a_global_sim_vars(s_of_objects)
       if { [is_ip $tcl_obj] } {
         set vh_files [find_incl_files_from_ip $tcl_obj]
       } else {
         set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"Verilog Header\""
         set vh_files [get_files -quiet -filter $filter]
       }

       foreach vh_file $vh_files {
         lappend dir_names [file normalize [file dirname $vh_file]]
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
     
       set ip_name [file tail $tcl_obj]
       set incl_dirs [list]
       set filter "FILE_TYPE == \"Verilog Header\""
       set compile_order_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_name] -filter $filter]
       foreach file $compile_order_files {
         set incl_dir [file dirname $file]
         lappend incl_dirs $incl_dir
       }
 
       return $incl_dirs
   }

   proc find_incl_files_from_ip { tcl_obj } {

       # Summary: Get the verilog include files of type "Verilog Header" for an IP

       # Argument Usage:
       # none

       # Return Value:
       # List of verilog include directory files in an IP for files of type "Verilog Header"

       set ip_name [file tail $tcl_obj]
       set vh_files [list]
       set filter "FILE_TYPE == \"Verilog Header\""
       set compile_order_files [get_files -quiet -of_objects [get_files -quiet *$ip_name] -filter $filter]
       foreach file $compile_order_files {
         lappend vh_files $file
       }
 
       return $vh_files
   }

   proc export_ip_data_files { ip_name } {

       # Summary: Copy IP data files to output directory

       # Argument Usage:
       # ip_name - Name of the IP

       # Return Value:
       # none

       variable a_global_sim_vars
 
       set filter "FILE_TYPE == \"Data Files\" || FILE_TYPE == \"Memory Initialization Files\""
       set data_files [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $filter]
       set export_dir $a_global_sim_vars(s_sim_files_dir)
       
       if { [llength $data_files] > 0 } {
         send_msg_id Vivado-projutils-030 INFO "Exporting '[file root $ip_name]' IP data file(s):-\n"
       }

       # export now
       foreach file $data_files {
         if {[catch {file copy -force $file $export_dir} error_msg] } {
           send_msg_id Vivado-projutils-031 WARNING "failed to copy file '$file' to '$export_dir' : $error_msg\n"
         } else {
           send_msg_id Vivado-projutils-032 INFO " copied '$file'\n"
         }
       }
   }

   proc export_fileset_ip_data_files {} {

       # Summary: Copy fileset IP data files to output directory

       # Argument Usage:
       # none

       # Return Value:
       # none

       variable a_global_sim_vars
 
       set filter "FILE_TYPE == \"IP\""
       set ips [get_files -all -quiet -filter $filter]
       foreach ip $ips {
         set ip_name [file tail $ip]
         export_ip_data_files $ip_name
       }
   }

   proc export_glbl_file {} {

       # Summary: Copies glbl.v file from install data dir to output dir

       # Argument Usage:
       # none

       # Return Value:
       # True (1) if file copied, false (0) otherwise

       variable a_global_sim_vars

       set data_dir [rdi::get_data_dir -quiet -datafile verilog/src/glbl.v]
       set file [file normalize [file join $data_dir "verilog/src/glbl.v"]]
       set export_dir $a_global_sim_vars(s_sim_files_dir)

       if {[catch {file copy -force $file $export_dir} error_msg] } {
         send_msg_id Vivado-projutils-031 WARNING "failed to copy file '$file' to '$export_dir' : $error_msg\n"
         return 0
       }

       set glbl_file [file normalize [file join $export_dir "glbl.v"]]
       send_msg_id Vivado-projutils-032 INFO "Exported glbl file (glbl.v) to output directory\n"
       return 1
   }

   proc get_compile_order_libs { files } {

       # Summary: Find unique list of design libraries

       # Argument Usage:
       # files: list of design files

       # Return Value:
       # Unique list of libraries (if any)

       set libs [list]
       foreach file $files {
         set library [get_property library [get_files -all $file]]
         if { [lsearch -exact $libs $library] == -1 } {
           lappend libs $library
         }
       }
  
       return $libs
   }

   proc is_verilog { files } {

       # Summary: Check if the input file type is of type verilog or verilog header

       # Argument Usage:
       # files: list of files

       # Return Value:
       # True (1) if of type verilog, False (0) otherwise

       foreach file $files {
         set file_type [get_property file_type [get_files -all [file tail $file]]]
         if { [string equal -nocase $file_type "verilog"] ||
              [string equal -nocase $file_type "verilog header"] } {
           return 1
         }
       }
       return 0
   }

   proc get_relative_file_path { file_path_to_convert } {

       # Summary: Get the relative path wrt to path specified

       # Argument Usage:
       # file_path_to_convert: input file to make relative to specfied path

       # Return Value:
       # Relative path wrt the path specified
  
       variable a_global_sim_vars

       # relative_to requested? return input file if not
       set relative_to $a_global_sim_vars(s_relative_to)
       if { [string length $relative_to] == 0 } {
         return $file_path_to_convert
       }

       set cwd [file normalize [pwd]]

       if { [file pathtype $file_path_to_convert] eq "relative" } {
         # is relative_to path same as cwd?, just return this path, no further processing required
         if { [string equal $relative_to $cwd] } {
           return $file_path_to_convert
         }
         # the relative_to is "relative" but something else. So make it absolute wrt cwd.
         set file_path_to_convert [file join $cwd $file_path_to_convert]
       }

       # is relative_to "relative"? convert to absolute as well wrt cwd
       if { [file pathtype $relative_to] eq "relative" } {
         set relative_to [file join $cwd $relative_to]
       }

       # normalize 
       set file_path_to_convert [file normalize $file_path_to_convert]
       set relative_to          [file normalize $relative_to]

       # are these same at this point? just return, no more processing required
       if { [string equal $file_path_to_convert $relative_to] } {
         return $file_path_to_convert
       }

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
           if { $rel_path == "" } {
             # first dir
             set rel_path "[lindex $file_comps $rel_index]"
           } else {
             # append remaining dirs
             set rel_path "${rel_path}/[lindex $file_comps $rel_index]"
           }
           incr rel_index
         }

         # prepend parent dirs 
         set resolved_path "${parent_dir_path}${rel_path}"

         # is final resolved path "relative"? append ./
         if { [string equal [file pathtype $resolved_path] "relative"] } {
           set resolved_path "./$resolved_path"
         }

         return $resolved_path

       }

       # no common dirs found, just return the normalized path 
       return $file_path
   }

}
