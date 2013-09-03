####################################################################################################
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# 
# Date Created     :  01/25/2013
# Script name      :  write_project_tcl.tcl
# Procedures       :  write_project_tcl
# Tool Version     :  Vivado 2013.3
# Description      :  Write a Tcl script for the current project in order to re-build the project, based
#                     on the current project settings.
#
# Command help     :  write_project_tcl -help
#
# Revision History :
#   02/08/2013 1.0  - Initial version (write_project_tcl)
#
####################################################################################################

# title: Vivado Project Re-Build Tcl Script
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::projutils {

  # Generate project tcl script for re-generating the project
  namespace export write_project_tcl

}

namespace eval ::tclapp::xilinx::projutils {

    proc write_project_tcl {args} {

        # Summary: 
        # Export Tcl script for re-creating the current project

        # Argument Usage: 
        # [-target_proj_dir <name>]: Directory where the project needs to be restored
        # [-force]: Overwrite existing tcl script file
        # [-all_properties]: Write all properties (default & non-default) for the project object(s)
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
            "-target_proj_dir"      { incr i;set a_global_vars(s_target_proj_dir) [lindex $args $i] }
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
        set a_global_vars(script_file) [file normalize $a_global_vars(script_file)]
        
        # create script file directories, if does not exist
        set file_path [file dirname $a_global_vars(script_file)]
        if { ! [file exists $file_path] } {
          if {[catch {file mkdir $file_path} error_msg] } {
            send_msg_id Vivado-projutils-013 ERROR "failed to create the directory ($file_path): $error_msg\n"
            return 1
          }
        }
          
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
}

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
                                "block diagrams" "block designs" "dsp design sources" "text" \
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

        set a_global_vars(s_target_proj_dir)    ""
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
          
        set tcl_cmd ""
        # set target project directory path if specified. If not, create project dir in current dir.
        set target_dir $a_global_vars(s_target_proj_dir)
        if { {} == $target_dir } {
          set tcl_cmd "create_project $name ./$name"
        } else {
          # is specified target proj dir == current dir? 
          set cwd [file normalize [string map {\\ /} [pwd]]]
          set dir [file normalize [string map {\\ /} $target_dir]]
          if { [string equal $cwd $dir] } {
            set tcl_cmd "create_project $name"
          } else {
            set tcl_cmd "create_project $name \"$target_dir\""
          }
        }
            
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
}
