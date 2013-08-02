####################################################################################################
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# 
# Created Date:   01/25/2013
# Script name:    helpers.tcl
# Procedures:     write_project_tcl, export_simulation
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
#              ::tclapp::xilinx::projutils namespace (export_simulation)
# SECTION (B): Main app procedure implementation
#              write_project_tcl
#              export_simulation
# SECTION (C): App helpers for the exported procedures
# 
# Command help:
#     % write_project_tcl -help
#     % export_simulation -help
#
# Revision History:
#
#   02/08/2013 1.0  - Initial version (write_project_tcl)
#   07/12/2013 2.0  - Initial version (export_simulation)
#
#
####################################################################################################

# title: Vivado Project Re-Build Tcl Script
package require Vivado 2013.1

#
# SECTION (A): Exported app procedures
#
namespace eval ::tclapp::xilinx::projutils {

  # Generate project tcl script for re-generating the project
  namespace export write_project_tcl

  # Generate simulation file(s) for the target simulator
  namespace export export_simulation
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
        # true (0) if success, false (1) otherwise

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
 			    return 1
 		      }
 		      set a_global_vars(script_file) $option
 		    }
 	      }
 	    }
 
 	    # script file is a must
 	    if { [string equal $a_global_vars(script_file) ""] } {
          send_msg_id Vivado-projutils-002 ERROR "Missing value for option 'file', please type 'write_project_tcl -help' for usage info.\n"
 	      return 1
 	    }
      
 	    # should not be a directory
 	    if { [file isdirectory $a_global_vars(script_file)] } {
          send_msg_id Vivado-projutils-003 ERROR "The specified filename is a directory ($a_global_vars(script_file)), please type 'write_project_tcl -help' for usage info.\n"
 	      return 1
 	    }
 
 	    # check extension
 	    if { [file extension $a_global_vars(script_file)] != ".tcl" } {
 	      set a_global_vars(script_file) $a_global_vars(script_file).tcl
 	    }
 	    set a_global_vars(script_file [file normalize $a_global_vars(script_file)]
  
 	    # recommend -force if file exists
 	    if { [file exists $a_global_vars(script_file)] && !$a_global_vars(b_arg_force) } {
          send_msg_id Vivado-projutils-004 ERROR "Tcl Script '$a_global_vars(script_file)' already exist. Use -force option to overwrite."
 	      return 1
 	    }

 	    # now write
 	    if {[write_project_tcl_script]} {
          return 1
        }
   
        # TCL_OK 
 	    return 0
    }

    proc export_simulation {args} {

        # Summary:
        # Generate design filelist for the specified simulator for standalone simulation

        # Argument Usage:
        # [-of_objects <name>]: Export simulation file(s) for the specified object
        # [-relative_to <dir>]: Make all file paths relative to the specified directory
        # [-32bit]: Perform 32bit compilation
        # [-force]: Overwrite previous files
        # -dir <name>: Directory where the simulation files is saved
        # -simulator <name>: Simulator for which simulation files will be exported (<name>: ies|vcs_mx)

        # Return Value:
        # true (0) if success, false (1) otherwise

        variable a_global_sim_vars
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
            "-of_objects"               { incr i;set a_global_sim_vars(s_of_objects) [lindex $args $i] }
            "-32bit"                    { set a_global_sim_vars(b_32bit) 1 }
            "-relative_to"              { incr i;set a_global_sim_vars(s_relative_to) [lindex $args $i] }
            "-force"                    { set a_global_sim_vars(b_overwrite_sim_files_dir) 1 }
            "-simulator"                { incr i;set a_global_sim_vars(s_simulator) [lindex $args $i] }
            "-dir"                      { incr i;set a_global_sim_vars(s_sim_files_dir) [lindex $args $i] }
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
        set a_global_sim_vars(s_project_name) [get_property name [current_project]]
        set a_global_sim_vars(s_project_dir) [get_property directory [current_project]]

        # is valid simulator specified?
        if { [lsearch -exact $l_valid_simulator_types $a_global_sim_vars(s_simulator)] == -1 } {
          send_msg_id Vivado-projutils-015 ERROR \
            "Invalid simulator type specified. Please type 'export_simulation -help' for usage info.\n"
          return 1
        }

        # is valid relative_to set?
        if { [lsearch $options {-relative_to}] != -1} {
          set relative_file_path $a_global_sim_vars(s_relative_to)
          if { ![file exists $relative_file_path] } {
            send_msg_id Vivado-projutils-037 ERROR \
              "Invalid relative path specified! Path does not exist:$a_global_sim_vars(s_relative_to)\n"
            return 1
          }
        }

        # is valid tcl obj specified?
        if { ([lsearch $options {-of_objects}] != -1) && ([llength $a_global_sim_vars(s_of_objects)] == 0) } {
          send_msg_id Vivado-projutils-038 ERROR "Invalid object specified. The object does not exist.\n"
          return 1
        }
 
        # set pretty name
        if { [set_simulator_name] } {
          return 1
        }

        # is managed project?
        set a_global_sim_vars(b_is_managed) [get_property managed_ip [current_project]]

        # setup run dir
        if { [create_sim_files_dir] } {
          return 1
        }
  
        # set default object if not specified, bail out if no object found
        if { [set_default_source_object] } {
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
        # None

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
    
    }

    #
    # export_simulation tcl script argument & file handle vars
    #
    variable a_global_sim_vars
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

        variable a_global_sim_vars

        set a_global_sim_vars(s_simulator)               ""
        set a_global_sim_vars(s_simulator_name)          ""
        set a_global_sim_vars(s_sim_files_dir)           ""
        set a_global_sim_vars(b_32bit)                   0
        set a_global_sim_vars(s_relative_to)             ""             
        set a_global_sim_vars(b_overwrite_sim_files_dir) 0
        set a_global_sim_vars(s_driver_script)           ""
        set a_global_sim_vars(s_of_objects)              ""
        set a_global_sim_vars(s_sim_top)                 ""
        set a_global_sim_vars(s_project_name)            ""
        set a_global_sim_vars(s_project_dir)             ""
        set a_global_sim_vars(b_is_managed)              0 

        set l_compile_order_files                        [list]

    }


    proc write_project_tcl_script {} {

        # Summary: write project script 
        # This helper command is used to script help.
    
        # Argument Usage: 
        # none
    
        # Return Value:
        # true (0) if success, false (1) otherwise

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
          return 1
        }
  
        # dump project in canonical form
        if { $a_global_vars(b_arg_dump_proj_info) } {
          set dump_file "${proj_name}_dump.txt"
          if {[catch {open $dump_file w} a_global_vars(dp_fh)]} {
            send_msg_id Vivado-projutils-006 ERROR "failed to open file for write ($dump_file)\n"
            return 1
          }
  
          # default value output file script handle
          set def_val_file "${proj_name}_def_val.txt"
          if {[catch {open $def_val_file w} a_global_vars(def_val_fh)]} {
            send_msg_id Vivado-projutils-007 ERROR "failed to open file for write ($file)\n"
            return 1
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

        return 0
    }

    proc wr_create_project { proj_dir name } {

        # Summary: write create project command 
        # This helper command is used to script help.
    
        # Argument Usage: 
        # proj_dir: project directory path
        # name: project name
    
        # Return Value:
        # none

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
    }

    proc wr_project_properties { proj_name } {

        # Summary: write project properties
        # This helper command is used to script help.
    
        # Argument Usage: 
        # proj_name: project name
        
        # Return Value:
        # None
    
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
    }

    proc wr_filesets { proj_name } {

        # Summary: write fileset object properties 
        # This helper command is used to script help.
    
        # Argument Usage: 
        # proj_name: project name
    
        # Return Value:
        # None

        variable a_fileset_types

        # write fileset data
        foreach {fs_data} $a_fileset_types {
          set filesets [get_filesets -filter FILESET_TYPE==[lindex $fs_data 0]]
          write_specified_fileset $proj_name $filesets
        }
    }

    proc write_specified_fileset { proj_name filesets } {

        # Summary: write fileset properties and sources 
        # This helper command is used to script help.
    
        # Argument Usage: 
        # proj_name: project name
        # filesets: list of filesets
    
        # Return Value:
        # None

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
    }

    proc wr_runs { proj_name } {

        # Summary: write runs and properties 
        # This helper command is used to script help.
    
        # Argument Usage: 
        # proj_name: project name
    
        # Return Value:
        # None

        # write runs (synthesis, Implementation)
        set runs [get_runs -filter {IS_SYNTHESIS == 1}]
        write_specified_run $proj_name $runs
      
        set runs [get_runs -filter {IS_IMPLEMENTATION == 1}]
        write_specified_run $proj_name $runs
    }

    proc wr_proj_info { proj_name } {

        # Summary: write generated project status message 
        # This helper command is used to script help.
    
        # Argument Usage: 
        # proj_name: project name
    
        # Return Value:
        # None

        variable l_script_data

        lappend l_script_data "\nputs \"INFO: Project created:$proj_name\""
    }

    proc write_header { proj_dir proj_name file } {
    
        # Summary: write script header 
        # This helper command is used to script help.
    
        # Argument Usage: 
    
        # Return Value:
        # None

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
    }

    proc print_local_file_msg { msg_type } {

        # Summary: print warning on finding local sources 
        # This helper command is used to script help.
    
        # Argument Usage: 
        
        # Return Value:
        # None

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
    }

    proc filter { prop val } {

        # Summary: filter special properties
        # This helper command is used to script help.
    
        # Argument Usage: 
    
        # Return Value:
        # true (1) if found, false (1) otherwise

        variable l_filetype_filter

        set prop [string toupper $prop]
        if { [expr { $prop == "IS_HD" } || \
                   { $prop == "IS_PARTIAL_RECONFIG" } || \
                   { $prop == "ADD_STEP" }]} {
          return 1
        }

        if { [string equal type "project"] } {
          if { [expr { $prop == "DIRECTORY" }] } {
            return 1
          }
        }

        # error reported if file_type is set
        # e.g ERROR: [Vivado 12-563] The file type 'IP' is not user settable.
        set val  [string tolower $val]
        if { [string equal $prop "FILE_TYPE"] } {
          if { [lsearch $l_filetype_filter $val] != -1 } {
            return 1
          }
        }
    
        return 0
    }

    proc is_local_to_project { file } {

        # Summary: check if file is local to the project directory structure 
        # This helper command is used to script help.
    
        # Argument Usage: 
    
        # Return Value:
        # true (1), if file is local to the project (inside project directory structure)
        # false (0), if file is outside the project directory structure

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
        # None

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
       # true (0) if success, false (1) otherwise

       variable a_global_sim_vars
       set tcl_obj $a_global_sim_vars(s_of_objects)
       if { [string length $tcl_obj] == 0 } {
         if { $a_global_sim_vars(b_is_managed) } {
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
           set a_global_sim_vars(s_of_objects) $curr_simset
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
           set ip_obj_count [llength [get_files -all -quiet $tcl_obj]]
           if { $ip_obj_count == 0 } {
             send_msg_id Vivado-projutils-009 ERROR "The specified object could not be found in the project:$tcl_obj\n"
             return 1
           } elseif { $ip_obj_count > 1 } {
             send_msg_id Vivado-projutils-019 ERROR "The script expects exactly one object got $ip_obj_count\n"
             return 1
           }
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

       variable a_global_sim_vars

       set tcl_obj $a_global_sim_vars(s_of_objects)

       if { [is_ip $tcl_obj] } {
         set a_global_sim_vars(s_sim_top) [file tail [file root $tcl_obj]]
         if {[export_sim_files_for_ip $tcl_obj]} {
           return 1
         }
       } elseif { [is_fileset $tcl_obj] } {
         set a_global_sim_vars(s_sim_top) [get_property top [get_filesets $tcl_obj]]
         if {[string length $a_global_sim_vars(s_sim_top)] == 0} {
           set a_global_sim_vars(s_sim_top) "unknown"
         }
         if {[export_sim_files_for_fs $tcl_obj]} {
           return 1
         }
       } else {
         send_msg_id Vivado-projutils-020 INFO "Unsupported object source: $tcl_obj\n"
         return 1
       }

       send_msg_id Vivado-projutils-021 INFO "Script generated:$a_global_sim_vars(s_sim_files_dir)/$a_global_sim_vars(s_driver_script)\n"

       return 0
   }

   proc export_sim_files_for_ip { tcl_obj } {

       # Summary: 

       # Argument Usage:
       # source object

       # Return Value:
       # true (0) if success, false (1) otherwise
     
       variable a_global_sim_vars
       variable s_data_files_filter
       variable l_compile_order_files
 
       set obj_name [file root [file tail $tcl_obj]]
       set ip_filename [file tail $tcl_obj]
       set l_compile_order_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_filename]]

       set simulator $a_global_sim_vars(s_simulator)
       set ip_name [file root $ip_filename]
       set a_global_sim_vars(s_driver_script) "${ip_name}_sim_${simulator}.txt"

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
       
       variable a_global_sim_vars
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
         set simulator $a_global_sim_vars(s_simulator)
         set a_global_sim_vars(s_driver_script) "$a_global_sim_vars(s_sim_top)_sim_${simulator}.txt"
         if {[export_simulation_for_object $obj_name]} {
           return 1
         }

         # fetch data files for all IP's in simset and export to output dir
         export_fileset_ip_data_files
       }
 
       return 0
   }

   proc is_ip { obj } {

       # Summary: Determine if specified source object is IP

       # Argument Usage:
       # source object

       # Return Value:
       # true (1) if specified object is an IP, false (0) otherwise
      
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
       # true (1) if specified object is a fileset, false (0) otherwise

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
       # True (0) if name set, false (1) otherwise

       variable a_global_sim_vars
       set simulator $a_global_sim_vars(s_simulator)
       switch -regexp -- $simulator {
         "ies"       { set a_global_sim_vars(s_simulator_name) "Cadence Incisive Enterprise" }
         "vcs_mx"    { set a_global_sim_vars(s_simulator_name) "Synopsys VCS MX" }
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

       variable a_global_sim_vars

       if { [string length $a_global_sim_vars(s_sim_files_dir)] == 0 } {
         send_msg_id Vivado-projutils-036 ERROR "Missing directory value. Please specify the output directory path for the exported files.\n"
         return 1
       }

       set dir [file normalize [string map {\\ /} $a_global_sim_vars(s_sim_files_dir)]]
       if { ! [file exists $dir] } {
         if {[catch {file mkdir $dir} error_msg] } {
           send_msg_id Vivado-projutils-023 ERROR "failed to create the directory ($dir): $error_msg\n"
           return 1
         }
       }
       set a_global_sim_vars(s_sim_files_dir) $dir
       return 0
   }

   proc export_simulation_for_object { obj_name } {

       # Summary: Open files and write compile order for the target simulator

       # Argument Usage:
       # obj_name - source object

       # Return Value:
       # true (0) if success, false (1) otherwise

       variable a_global_sim_vars
       
       set file [file normalize [file join $a_global_sim_vars(s_sim_files_dir) $a_global_sim_vars(s_driver_script)]]

 	   # recommend -force if file exists
 	   if { [file exists $file] && (!$a_global_sim_vars(b_overwrite_sim_files_dir)) } {
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
         "Generating driver script for '$a_global_sim_vars(s_simulator_name)' simulator (DESIGN OBJECT=$obj_name)...\n"

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

       variable a_global_sim_vars

       write_script_header $fh

       # setup source dir var
       set relative_to $a_global_sim_vars(s_relative_to)
       if {[string length $relative_to] > 0 } {
         puts $fh "#"
         puts $fh "# Relative path for design sources and include directories (if any) relative to this path"
         puts $fh "#"
         puts $fh "set origin_dir \"$relative_to\""
         puts $fh ""
       }

       puts $fh "#"
       puts $fh "# STEP: compile"
       puts $fh "#"

       switch -regexp -- $a_global_sim_vars(s_simulator) {
         "ies"      { wr_driver_script_ies $fh }
         "vcs_mx"   { wr_driver_script_vcs_mx $fh }
         default {
           send_msg_id Vivado-projutils-022 ERROR "Invalid simulator ($a_global_sim_vars(s_simulator))\n"
           close $fh
           return 1
         }
       }

       # add glbl
       if { [contains_verilog] } {
         set file_str "-work work ./glbl.v"
         switch -regexp -- $a_global_sim_vars(s_simulator) {
           "ies"      { puts $fh "ncvlog $file_str" }
           "vcs_mx"   { puts $fh "vlogan $file_str" }
           default {
             send_msg_id Vivado-projutils-031 ERROR "Invalid simulator ($a_global_sim_vars(s_simulator))\n"
             close $fh
             return 1
           }
         }
       }

       puts $fh ""
       write_elaboration_cmds $fh

       puts $fh ""
       write_simulation_cmds $fh

       return 0
   }

   proc wr_driver_script_ies { fh } {

       # Summary: Write driver script for the IES simulator

       # Argument Usage:
       # file - compile order RTL file
       # fh   - file handle

       # Return Value:
       # none

       variable a_global_sim_vars
       variable l_compile_order_files

       foreach file $l_compile_order_files {
         set cmd_str [list]
         set file_type [get_property file_type [get_files -quiet -all $file]]
         set associated_library [get_property library [get_files -quiet -all $file]]
         if {[string length $a_global_sim_vars(s_relative_to)] > 0 } {
           set file "\$origin_dir/[get_relative_file_path $file $a_global_sim_vars(s_relative_to)]"
         }
         switch -regexp -nocase -- $file_type {
           "vhd" {
             set tool "ncvhdl"
             lappend cmd_str $tool
             append_compiler_options $tool $file_type cmd_str
             lappend cmd_str "-work"
             lappend cmd_str "$associated_library"
             lappend cmd_str "\"$file\""
           }
           "verilog" {
             set tool "ncvlog"
             lappend cmd_str $tool
             append_compiler_options $tool $file_type cmd_str
             lappend cmd_str "-work"
             lappend cmd_str "$associated_library"
             lappend cmd_str "\"$file\""
           }
         }
         set cmd [join $cmd_str " "]
         puts $fh $cmd
       }
   }

   proc wr_driver_script_vcs_mx { fh } {

       # Summary: Write driver script for the VCS simulator

       # Argument Usage:
       # file - compile order RTL file
       # fh   - file handle

       # Return Value:
       # none

       variable a_global_sim_vars
       variable l_compile_order_files

       foreach file $l_compile_order_files {
         set cmd_str [list]
         set file_type [get_property file_type [get_files -quiet -all $file]]
         set associated_library [get_property library [get_files -quiet -all $file]]
         if {[string length $a_global_sim_vars(s_relative_to)] > 0 } {
           set file "\$origin_dir/[get_relative_file_path $file $a_global_sim_vars(s_relative_to)]"
         }
         switch -regexp -nocase -- $file_type {
           "vhd" {
             set tool "vhdlan"
             lappend cmd_str $tool
             append_compiler_options $tool $file_type cmd_str
             lappend cmd_str "-work"
             lappend cmd_str "$associated_library"
             lappend cmd_str "$file"
           }
           "verilog" {
             set tool "vlogan"
             lappend cmd_str $tool
             append_compiler_options $tool $file_type cmd_str
             lappend cmd_str "-work"
             lappend cmd_str "$associated_library"
             lappend cmd_str "$file"
           }
         }
         set cmd [join $cmd_str " "]
         puts $fh $cmd
       }
   }

   proc write_script_header { fh } {

       # Summary: Driver script header info

       # Argument Usage:
       # fh - file descriptor

       # Return Value:
       # none

       variable a_global_sim_vars

       set curr_time   [clock format [clock seconds]]
       set version_txt [split [version] "\n"]
       set version     [lindex $version_txt 0]
       set copyright   [lindex $version_txt 2]
       set product     [lindex [split $version " "] 0]
       set version_id  [join [lrange $version 1 end] " "]

       puts $fh "#\n# $product (TM) $version_id\n#"
       puts $fh "# $a_global_sim_vars(s_driver_script): Simulation script\n#"
       puts $fh "# Generated by $product on $curr_time"
       puts $fh "# $copyright \n#"
       puts $fh "# This file contains commands for compiling the design in '$a_global_sim_vars(s_simulator_name)' simulator\n#"
       puts $fh "#*****************************************************************************************"
       puts $fh "# NOTE: To compile and run simulation, you must perform following pre-steps:-"
       puts $fh "#"
       puts $fh "# 1. Compile the Xilinx simulation libraries using the 'compile_simlib' TCL command. For more information"
       puts $fh "#    about this command, run 'compile_simlib -help' in $product Tcl Shell."
       puts $fh "#"
    
       switch -regexp -- $a_global_sim_vars(s_simulator) {
         "ies" { 
            puts $fh "# 2. Copy the CDS.lib and HDL.var files from the compiled directory location to the working directory."
            puts $fh "#    In case the libraries are compled in the working directory then ignore this step."
            puts $fh "#"
            puts $fh "# 3. Create directory for each design library* (for example: mkdir -p ius/fifo_gen)\n#"
            puts $fh "# 4. Define library mapping for each library in CDS.lib file (for example: DEFINE fifo_gen ius/fifo_gen)\n"
         }
         "vcs_mx" {
            puts $fh "# 2. Copy the synopsys_sim.setup file from the compiled directory location to the current working directory."
            puts $fh "#    In case the libraries are compled in the current working directory then ignore this step."
            puts $fh "#"
            puts $fh "# 3. Create directory for each design library* (for example: mkdir -p vcs/fifo_gen)\n#"
            puts $fh "# 4. Map libraries to physical directory location in synopsys_sim.setup file (for example: fifo_gen : vcs/fifo_gen)\n#"
         }
       }
       puts $fh "# 3. For more information please refer to the following guide:-\n#"
       puts $fh "#    Xilinx Vivado Design Suite User Guide:Logic simulation (UG900)\n#"
       puts $fh "# *Design Libraries:-\n#"
       foreach lib [get_compile_order_libs] {
         puts $fh "#  $lib"
       }
       puts $fh "#"
       puts $fh "#*****************************************************************************************\n"

   }

   proc write_elaboration_cmds { fh } {

       # Summary: Driver script header info

       # Argument Usage:
       # files - compile order files
       # fh - file descriptor

       # Return Value:
       # none

       variable a_global_sim_vars

       set tcl_obj $a_global_sim_vars(s_of_objects)
       set v_generics [list]
       if { [is_fileset $tcl_obj] } {
         set v_generics [get_property vhdl_generic [get_filesets $tcl_obj]]
       }

       puts $fh "#"
       puts $fh "# STEP: elaborate"
       puts $fh "#"

       switch -regexp -- $a_global_sim_vars(s_simulator) {
         "ies" { 
           set cmd_str [list]
           lappend cmd_str "ncelab"
           lappend cmd_str "-timescale"
           lappend cmd_str "1ns/1ps"
           foreach generic $v_generics {
             set name [lindex [split $generic "="] 0]
             set val  [lindex [split $generic "="] 1]
             if { [string length $val] > 0 } {
               lappend cmd_str "-g"
               lappend cmd_str "\"$name=>$val\""
             }
           }
           lappend cmd_str "-override_precision"
           lappend cmd_str "-lib_binding"
           lappend cmd_str "-messages"
           lappend cmd_str "$a_global_sim_vars(s_sim_top)"
           lappend cmd_str "glbl"
           foreach library [get_compile_order_libs] {
             lappend cmd_str "-libname"
             lappend cmd_str "[string tolower $library]"
           }
           lappend cmd_str "-libname"
           lappend cmd_str "unisims_ver"
           lappend cmd_str "-libname"
           lappend cmd_str "secureip"
           if { !$a_global_sim_vars(b_32bit) } {
             lappend cmd_str "-64bit"
           }
           lappend cmd_str "-logfile"
           lappend cmd_str "$a_global_sim_vars(s_sim_top)_elab.log"
           set cmd [join $cmd_str " "]
           puts $fh $cmd
         }
         "vcs_mx" {
           set cmd_str [list]
           lappend cmd_str "vcs"
           if { !$a_global_sim_vars(b_32bit) } {
             lappend cmd_str "-full64"
           }
           lappend cmd_str "$a_global_sim_vars(s_sim_top)"
           lappend cmd_str "-l"
           lappend cmd_str "$a_global_sim_vars(s_sim_top)_comp.log"
           lappend cmd_str "-t"
           lappend cmd_str "-ps"
           lappend cmd_str "-licwait"
           lappend cmd_str "-60"
           lappend cmd_str "-o"
           lappend cmd_str "$a_global_sim_vars(s_sim_top)_simv"
           set cmd [join $cmd_str " "]
           puts $fh $cmd
         }
       }
   }

   proc write_simulation_cmds { fh } {

       # Summary: Driver script simulation commands info

       # Argument Usage:
       # files - compile order files
       # fh - file descriptor

       # Return Value:
       # none

       variable a_global_sim_vars

       puts $fh "#"
       puts $fh "# STEP: simulate"
       puts $fh "#"

       switch -regexp -- $a_global_sim_vars(s_simulator) {
         "ies" { 
           set cmd_str [list]
           lappend cmd_str "ncsim"
           if { !$a_global_sim_vars(b_32bit) } {
             lappend cmd_str "-64bit"
           }
           lappend cmd_str "-input"
           lappend cmd_str "$a_global_sim_vars(s_sim_top).do"
           lappend cmd_str "-logfile"
           lappend cmd_str "$a_global_sim_vars(s_sim_top)_sim.log"
           set cmd [join $cmd_str " "]
           puts $fh $cmd
         }
         "vcs_mx" {
           set cmd_str [list]
           lappend cmd_str "vcs"
           lappend cmd_str "$a_global_sim_vars(s_sim_top)_simv"
           lappend cmd_str "-ucli"
           lappend cmd_str "-do"
           lappend cmd_str "$a_global_sim_vars(s_sim_top)_sim.do"
           lappend cmd_str "-licwait"
           lappend cmd_str "-60"
           lappend cmd_str "-l"
           lappend cmd_str "$a_global_sim_vars(s_sim_top)_sim.log"
           set cmd [join $cmd_str " "]
           puts $fh $cmd
         }
       }
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

       variable a_global_sim_vars

       # verilog include directories
       set incl_dirs [find_verilog_incl_dirs]

       # verilog include file directories
       set incl_file_dirs [find_verilog_incl_file_dirs]

       # verilog defines
       set tcl_obj $a_global_sim_vars(s_of_objects)
       set v_defines [list]
       if { [is_fileset $tcl_obj] } {
         set v_defines [get_property verilog_define [get_filesets $tcl_obj]]
       }
       set v_generics [list]
       if { [is_fileset $tcl_obj] } {
         set v_generics [get_property vhdl_generic [get_filesets $tcl_obj]]
       }
  
       switch $tool {
         "ncvhdl" {
           lappend opts "-V93"
           lappend opts "-RELAX"
           if { !$a_global_sim_vars(b_32bit) } {
             lappend opts "-64bit"
           }
           lappend opts "-logfile"
           lappend opts "$tool.log"
           lappend opts "-append_log"
         }
         "ncvlog" {
           if { !$a_global_sim_vars(b_32bit) } {
             lappend opts "-64bit"
           }
           lappend opts "-messages"
           foreach define $v_defines {
             set name [lindex [split $define "="] 0]
             set val  [lindex [split $define "="] 1]
             if { [string length $val] > 0 } {
               lappend opts "-define"
               lappend opts "\"$name=$val\""
             }
           }
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
           if { !$a_global_sim_vars(b_32bit) } {
             lappend opts "-full64"
           }
           lappend opts "-l"
           lappend opts "$tool.log"
         }
         "vlogan" {
           if { [string equal $file_type "verilog"] } {
             lappend opts "+v2k"
           } elseif { [string equal $file_type "systemverilog"] } {
             lappend opts "-sverilog"
           }
           if { !$a_global_sim_vars(b_32bit) } {
             lappend opts "-full64"
           }
           foreach define $v_defines {
             set name [lindex [split $define "="] 0]
             set val  [lindex [split $define "="] 1]
             if { [string length $val] > 0 } {
               lappend opts "+define+"
               lappend opts "$name=$val"
             }
           }
           lappend opts "-l"
           lappend opts "$tool.log"
           foreach dir $incl_dirs {
             lappend opts "+incdir+\"$dir\""
           }
           foreach dir $incl_file_dirs {
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
         set dir [file normalize $vh_dir]
         if {[string length $a_global_sim_vars(s_relative_to)] > 0 } {
           set dir "\$origin_dir/[get_relative_file_path $dir $a_global_sim_vars(s_relative_to)]"
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
         set dir [file normalize [file dirname $vh_file]]
         if {[string length $a_global_sim_vars(s_relative_to)] > 0 } {
           set dir "\$origin_dir/[get_relative_file_path $dir $a_global_sim_vars(s_relative_to)]"
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
    
       variable a_global_sim_vars 

       set ip_name [file tail $tcl_obj]
       set incl_dirs [list]
       set filter "FILE_TYPE == \"Verilog Header\""
       set vh_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_name] -filter $filter]
       foreach file $vh_files {
         set dir [file dirname $file]
         if {[string length $a_global_sim_vars(s_relative_to)] > 0 } {
           set dir "\$origin_dir/[get_relative_file_path $dir $a_global_sim_vars(s_relative_to)]"
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

       variable a_global_sim_vars

       set incl_files [list]
       set ip_name [file tail $tcl_obj]
       set filter "FILE_TYPE == \"Verilog Header\""
       set vh_files [get_files -quiet -of_objects [get_files -quiet *$ip_name] -filter $filter]
       foreach file $vh_files {
         if {[string length $a_global_sim_vars(s_relative_to)] > 0 } {
           set file "\$origin_dir/[get_relative_file_path $file $a_global_sim_vars(s_relative_to)]"
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

       variable a_global_sim_vars
 
       set export_dir $a_global_sim_vars(s_sim_files_dir)
       
       # export now
       foreach file $data_files {
         if {[catch {file copy -force $file $export_dir} error_msg] } {
           send_msg_id Vivado-projutils-027 WARNING "failed to copy file '$file' to '$export_dir' : $error_msg\n"
         } else {
           send_msg_id Vivado-projutils-028 INFO "copied '$file'\n"
         }
       }
   }

   proc export_fileset_ip_data_files { } {

       # Summary: Copy fileset IP data files to output directory

       # Argument Usage:
       # none

       # Return Value:
       # none

       variable a_global_sim_vars
       variable s_data_files_filter
 
       set ip_filter "FILE_TYPE == \"IP\""
       set ips [get_files -all -quiet -filter $ip_filter]
       foreach ip $ips {
         set ip_name [file tail $ip]
         set data_files [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $s_data_files_filter]
         export_data_files $data_files
       }

       # export fileset data files
       set fs_data_files [get_files -all -quiet -of_objects [get_filesets -quiet [current_fileset]] -filter $s_data_files_filter]
       export_data_files $fs_data_files
   }

   proc export_glbl_file {} {

       # Summary: Copies glbl.v file from install data dir to output dir

       # Argument Usage:
       # none

       # Return Value:
       # True (0) if file copied, false (1) otherwise

       variable a_global_sim_vars

       set data_dir [rdi::get_data_dir -quiet -datafile verilog/src/glbl.v]
       set file [file normalize [file join $data_dir "verilog/src/glbl.v"]]
       set export_dir $a_global_sim_vars(s_sim_files_dir)

       if {[catch {file copy -force $file $export_dir} error_msg] } {
         send_msg_id Vivado-projutils-029 WARNING "failed to copy file '$file' to '$export_dir' : $error_msg\n"
         return 1
       }

       set glbl_file [file normalize [file join $export_dir "glbl.v"]]
       send_msg_id Vivado-projutils-030 INFO "Exported glbl file (glbl.v) to output directory\n"

       return 0
   }

   proc get_compile_order_libs { } {

       # Summary: Find unique list of design libraries

       # Argument Usage:
       # files: list of design files

       # Return Value:
       # Unique list of libraries (if any)
    
       variable a_global_sim_vars
       variable l_compile_order_files

       set libs [list]
       foreach file $l_compile_order_files {
         set library [get_property library [get_files -all $file]]
         if { [lsearch -exact $libs $library] == -1 } {
           lappend libs $library
         }
       }
       return $libs
   }

   proc contains_verilog {} {

       # Summary: Check if the input file type is of type verilog or verilog header

       # Argument Usage:
       # files: list of files

       # Return Value:
       # True (1) if of type verilog, False (0) otherwise

       set filter "FILE_TYPE == \"Verilog\" || FILE_TYPE == \"Verilog Header\""
       if {[llength [get_files -quiet -all -filter $filter]] > 0} {
         return 1
       }
       return 0
   }

   proc get_relative_file_path { file_path_to_convert relative_to } {

       # Summary: Get the relative path wrt to path specified

       # Argument Usage:
       # file_path_to_convert: input file to make relative to specfied path

       # Return Value:
       # Relative path wrt the path specified
  
       variable a_global_sim_vars

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
