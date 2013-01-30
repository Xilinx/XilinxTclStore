####################################################################################################
# Company:        Xilinx, Inc.
# Created by:     Raj Klair
# 
# Created Date:   01/25/2013
# Script name:    helpers.tcl
# Procedures:     write_project_tcl
# Tool Versions:  Vivado 2013.1
# Description:    This script is used to write a Tcl script for re-building the project
# 
# Getting Started:
#     % source ./write_project_tcl.tcl
#     % write_project_tcl my_project.tcl
#
# Revision History:
#
#   01/25/2013 1.0  - Initial version
#
#
####################################################################################################

# title: Vivado Project Re-Build Tcl Script
package require Vivado 2013.1

#
# export app procedures for Vivado shell
#
namespace eval ::tclapp::xilinx::bldproj {

    # Export procs that should be allowed to import into other namespaces
    namespace export write_project_tcl

    #
    # tcl script argument & file handle vars
    #
    variable a_global_vars
    variable l_script_data [list]
    variable l_local_files [list]
    variable l_remote_files [list]

    proc reset_global_vars {} {

        # Summary: initializes global namespace vars 
        # This helper command is used to reset the variables used in the script.
    
        # Argument Usage: 
        
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

    proc usage {} {

        # Summary: print script usage and description 
    
        # Argument Usage: 
    
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        puts "Description:"
        puts "Write tcl script for re-creating the current project\n"
        puts "Syntax:"
        puts "write_project_tcl \[-force\] \[-all_properties\] \[-no_copy_sources\] <file>"
        puts "\n"
        puts "Returns:"
        puts "Boolean 'true' if success, else 'false'\n"
        puts "Usage:"
        puts "Name                  Description"
        puts "----------------------------------------"
        puts "\[-force\]                Overwrite existing tcl script file"
        puts "\[-all_properties\]       Write all properties for the project object(s)"
        puts "\[-no_copy_sources\]      Donot import sources even if they were local in the original project"
        puts "<file>                  Name of the tcl script file to generate"
        puts ""
        puts "Description:"
        puts "  Writes a Tcl file for re-creating the current project with all the sources"
        puts "  and project settings that were set when this script was generated."
        puts ""
        puts "Examples:"
        puts "  The following command creates the Tcl file for the current project in the"
        puts "  current directory.\n"
        puts "  write_project_tcl\n"
        puts "  The following command creates the \"my_script.tcl\" Tcl file for the current"
        puts "  project in the /tmp/test directory.\n"
        puts "  write_project_tcl /tmp/test/my_script.tcl"
        puts ""
    
        return 0
    }

    proc write_project_tcl_script {} {

        # Summary: write project script 
        # This helper command is used to script help.
    
        # Argument Usage: 
    
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        variable a_global_vars
        variable l_script_data
        set l_script_data [list]

        # get the project name
        set tcl_obj [current_project]
        set proj_name [file tail [get_property name $tcl_obj]]
        set proj_dir [get_property directory $tcl_obj]
        set part_name [get_property part $tcl_obj]

        # output file script handle
        set file $a_global_vars(script_file)
        if {[catch {open $file w} a_global_vars(fh)]} {
          puts "ERROR: failed to open file for write ($file)"
          return false
        }
  
        # dump project in canonical form
        if { $a_global_vars(b_arg_dump_proj_info) } {
          set dump_file "${proj_name}_dump.txt"
          if {[catch {open $dump_file w} a_global_vars(dp_fh)]} {
            puts "ERROR: failed to open file for write ($dump_file)"
            return false
          }
  
          # default value output file script handle
          set def_val_file "${proj_name}_def_val.txt"
          if {[catch {open $def_val_file w} a_global_vars(def_val_fh)]} {
            puts "ERROR: failed to open file for write ($file)"
            return false
          }
        }

        # Default format
        write_create_project_helper $proj_dir $proj_name
        write_project_prop_helper $proj_name
        write_fileset_prop_sources_helper $proj_name
        write_runs_prop_helper $proj_name
        write_close_project_helper
        write_generated_project_info $proj_name

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
  
        if { $a_global_vars(b_local_sources) } {
          print_local_file_msg "warning"
        } else {
          print_local_file_msg "info"
        }

        set file [file normalize $file]
        puts "Tcl script for project $proj_name generated ($file)"
        puts ""
        puts "INFO: To recreate the current project, source this Tcl script in the Vivado shell (please see the header section in"
        puts "      this script file for more details). The script will create a new project in the ./$proj_name directory."
        puts ""

	    reset_global_vars

        return 0
    }

    proc write_create_project_helper { proj_dir name } {

        # Summary: write create project command 
        # This helper command is used to script help.
    
        # Argument Usage: 
        # proj_dir: project directory path
        # name: project name
    
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        variable a_global_vars
        variable l_script_data

        write_hash_comment ""
        lappend l_script_data "# Set the original project directory path for adding/importing sources in the new project"
        write_hash_comment ""
        lappend l_script_data "set proj_dir \"$proj_dir\""
        lappend l_script_data ""
  
        # create project
        write_hash_comment ""
        lappend l_script_data "# Create project"
        write_hash_comment ""
        lappend l_script_data "create_project $name ./$name"
  
        if { $a_global_vars(b_arg_dump_proj_info) } {
          puts $a_global_vars(dp_fh) "project_name=$name"
        }

        return 0
    }

    proc write_project_prop_helper { proj_name } {

        # Summary: write project properties
        # This helper command is used to script help.
    
        # Argument Usage: 
        # proj_name: project name
        
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.
    
        variable l_script_data

        # write project properties
        set tcl_obj [current_project]
        set get_what "get_projects"
    
        lappend l_script_data ""
        write_hash_comment ""

        lappend l_script_data "# Set project properties"
        write_hash_comment ""
        write_props $proj_name $get_what $tcl_obj "project"

        return 0
    }

    proc write_fileset_prop_sources_helper { proj_name } {

        # Summary: write fileset object properties 
        # This helper command is used to script help.
    
        # Argument Usage: 
        # proj_name: project name
    
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        # Write fileset (sources, constrs, simulation)
        set filesets [get_filesets -filter {FILESET_TYPE == "DesignSrcs"}]
        write_specified_fileset $proj_name $filesets
    
        set filesets [get_filesets -filter {FILESET_TYPE == "Constrs"}]
        write_specified_fileset $proj_name $filesets
    
        set filesets [get_filesets -filter {FILESET_TYPE == "SimulationSrcs"}]
        write_specified_fileset $proj_name $filesets
    
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

        # write filesets
        set type "file"
        foreach tcl_obj $filesets {

          set fs_type [get_property fileset_type [get_filesets $tcl_obj]]
          set fs_sw_type ""
          switch -regexp -- $fs_type {
            "DesignSrcs"     { set fs_sw_type "-srcset"      }
            "Constrs"        { set fs_sw_type "-constrset"   }
            "SimulationSrcs" { set fs_sw_type "-simset"      }
          }
  
          write_hash_comment ""
          lappend l_script_data "# Create '$tcl_obj' fileset (if not found)"
          write_hash_comment ""
          lappend l_script_data "if \{\[string equal \[get_filesets $tcl_obj\] \"\"\]\} \{"
          lappend l_script_data "  create_fileset $fs_sw_type $tcl_obj"
          lappend l_script_data "\}\n"
  
          set get_what_fs "get_filesets"
  
          write_hash_comment ""
          lappend l_script_data "# Set '$tcl_obj' fileset properties"
          write_hash_comment ""
  
          write_props $proj_name $get_what_fs $tcl_obj "fileset"

          set get_what_src "get_files"
          write_hash_comment ""
          lappend l_script_data "# Add files to '$tcl_obj' fileset"
          write_hash_comment ""

          write_files $proj_name $get_what_src $tcl_obj $type
    
          if { [string equal [get_property fileset_type [$get_what_fs $tcl_obj]] "Constrs"] } { continue }
    
          #puts $a_global_vars(fh) "update_compile_order -fileset $tcl_obj"
        }

        return 0
    }

    proc write_runs_prop_helper { proj_name } {

        # Summary: write runs and properties 
        # This helper command is used to script help.
    
        # Argument Usage: 
        # proj_name: project name
    
        # Return Value:
        # true - success.
        # TCL_OK is returned if the procedure completed successfully.

        # Write runs (synthesis, Implementation)
        set runs [get_runs -filter {IS_SYNTHESIS == 1}]
        write_specified_run $proj_name $runs
      
        set runs [get_runs -filter {IS_IMPLEMENTATION == 1}]
        write_specified_run $proj_name $runs
    
        return 0
    }

    proc write_close_project_helper {} {

        # Summary: write close project 
        # This helper command is used to script help.
    
        # Argument Usage: 
    
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        variable l_script_data

        # close project
        write_hash_comment ""
        lappend l_script_data "# Close project"

        write_hash_comment ""
        lappend l_script_data "close_project"

        return 0
    }

    proc write_generated_project_info { proj_name } {

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

        set product "Vivado"
        set curr_time [clock format [clock seconds]]
        set ver [lindex [split [version] "\n"] 0]
        set tcl_file [file tail $file]
        puts $a_global_vars(fh) "#\n# $product (TM) $ver"
        puts $a_global_vars(fh) "#\n# $tcl_file: Tcl script for re-creating project '$proj_name'\n#"
        puts $a_global_vars(fh) "# Generated by $product on $curr_time"
        puts $a_global_vars(fh) "# Copyright 1986-1999, 2001-2012 Xilinx, Inc. All Rights Reserved."
        puts $a_global_vars(fh) "#\n# This file contains the $product Tcl commands for re-creating the project to the state*"
        puts $a_global_vars(fh) "# when this script was generated. In order to re-create the project, please source this"
        puts $a_global_vars(fh) "# file in the $product Tcl Shell:-\n#"
        puts $a_global_vars(fh) "# vivado -mode batch -source ${tcl_file}"
        puts $a_global_vars(fh) "#\n# You can also re-create this project in the $product GUI by sourcing this script in"
        puts $a_global_vars(fh) "# the Tcl console."
        puts $a_global_vars(fh) "#\n"
        puts $a_global_vars(fh) "# *Please note that the run results will not be generated when this script is sourced\n#"
        puts $a_global_vars(fh) "#*****************************************************************************************"
        puts $a_global_vars(fh) "# NOTE: In order to use this script for source control purposes, please make sure that the"
        puts $a_global_vars(fh) "#       following files are added to the source control system:-"
        puts $a_global_vars(fh) "#"
        puts $a_global_vars(fh) "# 1. This project restoration tcl script (${tcl_file}) that was generated."
        puts $a_global_vars(fh) "#"
        puts $a_global_vars(fh) "# 2. The following source(s) files that were local or imported into the original project in"
        puts $a_global_vars(fh) "#    the project directory (proj_dir=$proj_dir)\n#"

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
        puts $a_global_vars(fh) "#*****************************************************************************************\n\n"
      
        return 0
    }

    proc write_hash_comment { leading_spaces } {
    
        # Summary: 
        # This helper command is used to script help.
    
        # Argument Usage: 
        
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        variable a_global_vars
        variable l_script_data

        #lappend ::tclapp::xilinx::bldproj::l_script_data "$leading_spaces##########################################################################################"
        lappend ::tclapp::xilinx::bldproj::l_script_data "$leading_spaces#"

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
          puts "WARNING: Found source(s) that were local or imported into the project. If this project is being source controlled,"
          puts "         then please ensure that the project source(s) are also part of this source controlled data. The list of these"
          puts "         local source(s) can be found in the generated script under the header section."
        } else {
          puts "INFO: If this project is being source controlled, then please ensure that the project source(s) are also part of this source"
          puts "      controlled data. The list of these local source(s) can be found in the generated script under the header section."
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

        set prop [string toupper $prop]
        if { [expr { $prop == "IS_HD" } || \
                   { $prop == "IS_PARTIAL_RECONFIG" } || \
                   { $prop == "ADD_STEP" }]} {
          return true
        }

        # error reported if file_type is set
        # ERROR: [Vivado 12-563] The file type 'IP' is not user settable.
        set val  [string tolower $val]
        if { [string equal $prop "FILE_TYPE"] } {
          set file_types [list "ip" "embedded design sources" "elf" "coefficient files" "block diagrams" "dsp design sources"]
          if { [lsearch $file_types $val] != -1 } {
            return true
          }
        }
    
        return 0
    }

    proc is_local_to_project { file } {

        # Summary: check if file local to the project directory structure 
        # This helper command is used to script help.
    
        # Argument Usage: 
    
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

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

    proc write_properties { prop_info_list get_what tcl_obj file } {

        # Summary: write object properties
        # This helper command is used to script help.
        
        # Argument Usage: 
        
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        variable a_global_vars
        variable l_script_data

        if {[llength $prop_info_list] > 0} {
          if { [string equal $get_what "get_files"] } {
            lappend l_script_data "set file_obj \[$get_what \"*\$file\" -of_objects $tcl_obj\]"
          } else {
            lappend l_script_data "set obj \[$get_what $tcl_obj\]"
          }
  
          foreach x $prop_info_list {
            set elem [split $x "#"]
            set name [lindex $elem 0]
            set value [lindex $elem 1]
            set cmd_str "set_property \"$name\" \"$value\""
            if { [string equal $get_what "get_files"] } {
              lappend l_script_data "$cmd_str \$file_obj"
            } else {
              lappend l_script_data "$cmd_str \$obj"
            }
          }
          lappend l_script_data ""
        }
    
        return true
    }

    proc write_props { proj_name get_what tcl_obj type } {

        # Summary: write first class object properties
        # This helper command is used to script help.
    
        # Argument Usage: 
    
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        variable a_global_vars

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
      
          # re-align values
          if { [string equal $def_val "false"] && [string equal $cur_val "0"] } { set cur_val "false" }
          if { [string equal $def_val "true"]  && [string equal $cur_val "1"] } { set cur_val "true"  }
          if { [string equal $def_val "false"] && [string equal $cur_val "1"] } { set cur_val "true"  }
          if { [string equal $def_val "true"]  && [string equal $cur_val "0"] } { set cur_val "false" }
          if { [string equal $def_val "{}"]    && [string equal $cur_val ""]  } { set cur_val "{}" }
      
          #puts "DEFAULT_VAL=$def_val;CURRENT_VAL=$cur_val ($prop Type:$prop_type)"
          #set cmd_str "set_property \"[string tolower $prop]\" \"[get_property $prop [$get_what $tcl_obj]]\" \[$get_what $tcl_obj\]"
          set prop_entry "[string tolower $prop]#[get_property $prop [$get_what $tcl_obj]]"
      
          set fs_name $tcl_obj
          set file_dirs [split [string trim [file normalize [string map {\\ /} $cur_val]]] "/"]
          set src_file [join [lrange $file_dirs [lsearch -exact $file_dirs "$tcl_obj"] end] "/"]
      
          # Fix paths wrt org proj dir
          if {([string equal -nocase $prop "target_constrs_file"] ||
               [string equal -nocase $prop "target_ucf"]) &&
               ($cur_val != "") } {
      
            set proj_file_path "\$proj_dir/${proj_name}.srcs/$src_file"
            set prop_entry "[string tolower $prop]#$proj_file_path"
          }
     
          if { $a_global_vars(b_arg_all_props) } {
            lappend prop_info_list $prop_entry
            #puts $a_global_vars(fh) $cmd_str
          } else {
            if { $def_val != $cur_val } {
              #puts $a_global_vars(fh) $cmd_str
              lappend prop_info_list $prop_entry
            }
          }
          if { $a_global_vars(b_arg_dump_proj_info) } {
            if { ([string equal $prop "TOP_FILE"] ||
                  [string equal $prop "TARGET_CONSTRS_FILE"] ||
                  [string equal $prop "TARGET_UCF"] ) && [string equal $type "fileset"] } {
              # fix path
              set cur_val "\$PSRCDIR/$src_file"
            }
            puts $a_global_vars(def_val_fh) "$prop:($prop_type) DEFAULT_VALUE ($def_val)==CURRENT_VALUE ($cur_val)"
            puts $a_global_vars(dp_fh) "${dump_prop_name}=$cur_val"
          }
        }
      
        # write properties now
        write_properties $prop_info_list $get_what $tcl_obj ""
    
        return 0
    }

    proc write_files { proj_name get_what tcl_obj type } {

        # Summary: write file and file properties 
        # This helper command is used to script help.
    
        # Argument Usage: 
    
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        variable a_global_vars
        variable l_local_files
        variable l_remote_files
        variable l_script_data

        set l_local_files [list]
        set l_remote_files [list]

        # return if empty fileset
        if {[llength [$get_what -of_objects $tcl_obj]] == 0 } {
          lappend l_script_data "# Empty (no sources present)\n"
          return
        }

        set fs_name [get_filesets $tcl_obj]

        set import_coln [list]
        set file_coln [list]
        lappend l_script_data "set files \[list \\"

        foreach file [lsort [$get_what -norecurse -of_objects $tcl_obj]] {
          set path_dirs [split [string trim [file normalize [string map {\\ /} $file]]] "/"]
          set src_file [join [lrange $path_dirs [lsearch -exact $path_dirs "$fs_name"] end] "/"]
          set file_props [list_property [$get_what $file -of_objects $fs_name]]
      
          if { [lsearch $file_props "IMPORTED_FROM"] != -1 } {

            # Import files
            set imported_path [get_property "imported_from" $file]
            set proj_file_path "\$proj_dir/${proj_name}.srcs/$src_file"
            set file "\"$proj_file_path\""
            lappend l_local_files $file

            # Add to the import collection
            lappend import_coln "\"$proj_file_path\""
            lappend file_coln "$file"

          } else {
            set file "\"$file\""

            # is local? add to local project, add to collection and then import this collection by default unless -no_copy_sources is specified
            if { [is_local_to_project $file] } {
              if { $a_global_vars(b_arg_dump_proj_info) } {
                set src_file "\$PSRCDIR/$src_file"
              }

              # Add to the import collection
              lappend import_coln $file
              lappend l_local_files $file
            } else {
              lappend l_remote_files $file
            }
      
            # Add files
            lappend file_coln "$file"

            # set flag that local sources were found and print warning at the end
            if { !$a_global_vars(b_local_sources) } {
              set a_global_vars(b_local_sources) 1
            }
          }
        }
      
        foreach file $file_coln {
          lappend l_script_data " $file\\"
        }
        lappend l_script_data "\]"
        lappend l_script_data "add_files -norecurse -fileset \$obj \$files"
        lappend l_script_data ""

        # Now import local files if -no_copy_sources is not specified.
        if { ! $a_global_vars(b_arg_no_copy_srcs)} {
          if { [llength $import_coln] > 0 } {
            write_hash_comment ""
            lappend l_script_data "# Import local files from the original project"
            write_hash_comment ""
            lappend l_script_data "set files \[list \\"
            foreach ifile $import_coln {
              lappend l_script_data " $ifile\\"
            }
            lappend l_script_data "\]"
            lappend l_script_data "set imported_files \[import_files -fileset $tcl_obj \$files\]"
            lappend l_script_data ""
          }
        }

        write_hash_comment ""
        lappend l_script_data "# Set '$tcl_obj' fileset file properties"
        write_hash_comment ""

        # set remote file properties
        foreach file $l_remote_files {
          set file [string trim $file "\""]
          lappend l_script_data "set file \"$file\""

          set file_props [list_property [$get_what $file -of_objects $fs_name]]
          set prop_info_list [list]

          foreach file_prop $file_props {
            set is_readonly [get_property is_readonly [rdi::get_attr_specs $file_prop -object [$get_what $file -of_objects $fs_name]]]
            if { [string equal $is_readonly "1"] } {
              continue
            }

            set prop_type [get_property type [rdi::get_attr_specs $file_prop -object [$get_what $file -of_objects $fs_name]]]
            set def_val [list_property_value -default $file_prop [get_files $file -of_objects $fs_name]]
            set cur_val [get_property $file_prop [get_files $file -of_objects $fs_name]]

            # filter special properties
            if { [filter $file_prop $cur_val] } { continue }

            # re-align values
            if { [string equal $def_val "false"] && [string equal $cur_val "0"] } { set cur_val "false" }
            if { [string equal $def_val "true"]  && [string equal $cur_val "1"] } { set cur_val "true"  }
            if { [string equal $def_val "false"] && [string equal $cur_val "1"] } { set cur_val "true"  }
            if { [string equal $def_val "true"]  && [string equal $cur_val "0"] } { set cur_val "false" }
            if { [string equal $def_val "{}"]    && [string equal $cur_val ""]  } { set cur_val "{}" }

            set dump_prop_name [string tolower ${fs_name}_file_${file_prop}]
            set prop_entry "[string tolower $file_prop]#[get_property $file_prop [$get_what $file -of_objects $fs_name]]"
            if { $a_global_vars(b_arg_all_props) } {
              lappend prop_info_list $prop_entry
            } else {
              if { $def_val != $cur_val } {
                lappend prop_info_list $prop_entry
              }
            }

            if { $a_global_vars(b_arg_dump_proj_info) } {
              puts $a_global_vars(def_val_fh) "[file tail $file]=$file_prop ($prop_type) :DEFAULT_VALUE ($def_val)==CURRENT_VALUE ($cur_val)"
              puts $a_global_vars(dp_fh) "$dump_prop_name=$cur_val"
            }
          }
          # write properties now
          write_properties $prop_info_list $get_what $tcl_obj $file
        }

        # set local file properties
        foreach file $l_local_files {
          set file [string trim $file "\""]

          set path_dirs [split [string trim [file normalize [string map {\\ /} $file]]] "/"]
          #set src_file [join [lrange $path_dirs [lsearch -exact $path_dirs "$fs_name"] end] "/"]
          set src_file [join [lrange $path_dirs end-1 end] "/"]

          #set src_file [string trimleft $src_file "$fs_name"]
          set src_file [string trimleft $src_file "/"]
          set src_file [string trimleft $src_file "\\"]

          set file $src_file

          lappend l_script_data "set file \"$file\""
          set file_props [list_property [$get_what "*$file" -of_objects $fs_name]]
          set prop_info_list [list]

          foreach file_prop $file_props {
            set is_readonly [get_property is_readonly [rdi::get_attr_specs $file_prop -object [$get_what "*$file" -of_objects $fs_name]]]
            if { [string equal $is_readonly "1"] } {
              continue
            }

            set prop_type [get_property type [rdi::get_attr_specs $file_prop -object [$get_what "*$file" -of_objects $fs_name]]]
            set def_val [list_property_value -default $file_prop [get_files "*$file" -of_objects $fs_name]]
            set cur_val [get_property $file_prop [get_files "*$file" -of_objects $fs_name]]

            # filter special properties
            if { [filter $file_prop $cur_val] } { continue }

            # re-align values
            if { [string equal $def_val "false"] && [string equal $cur_val "0"] } { set cur_val "false" }
            if { [string equal $def_val "true"]  && [string equal $cur_val "1"] } { set cur_val "true"  }
            if { [string equal $def_val "false"] && [string equal $cur_val "1"] } { set cur_val "true"  }
            if { [string equal $def_val "true"]  && [string equal $cur_val "0"] } { set cur_val "false" }
            if { [string equal $def_val "{}"]    && [string equal $cur_val ""]  } { set cur_val "{}" }

            set dump_prop_name [string tolower ${fs_name}_file_${file_prop}]
            set prop_value_entry [get_property $file_prop [$get_what "*$file" -of_objects $fs_name]]
            set prop_entry "[string tolower $file_prop]#$prop_value_entry"
            if { $a_global_vars(b_arg_all_props) } {
              lappend prop_info_list $prop_entry
            } else {
              if { $def_val != $cur_val } {
                lappend prop_info_list $prop_entry
              }
            }

            if { $a_global_vars(b_arg_dump_proj_info) } {
              puts $a_global_vars(def_val_fh) "[file tail $file]=$file_prop ($prop_type) :DEFAULT_VALUE ($def_val)==CURRENT_VALUE ($cur_val)"
              puts $a_global_vars(dp_fh) "$dump_prop_name=$cur_val"
            }
          }
          # write properties now
          write_properties $prop_info_list $get_what $tcl_obj $file
        }
      
        return 0
    }

    proc write_specified_run { proj_name runs } {

        # Summary: write the specified run information 
        # This helper command is used to script help.
        
        # Argument Usage: 
        
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        variable a_global_vars
        variable l_script_data

        set get_what "get_runs"
        foreach tcl_obj $runs {
          # fetch run attributes
          set part         [get_property part [get_runs $tcl_obj]]
          set parent_run   [get_property parent [get_runs $tcl_obj]]
          set src_set      [get_property srcset [get_runs $tcl_obj]]
          set constrs_set  [get_property constrset [get_runs $tcl_obj]]
          set strategy     [get_property strategy [get_runs $tcl_obj]]
          set parent_run_str ""
          if  { $parent_run != "" } {
            set parent_run_str " -parent_run $parent_run"
          }
  
          write_hash_comment ""
          lappend l_script_data "# Create '$tcl_obj' run (if not found)"
          write_hash_comment ""
          lappend l_script_data "if \{\[string equal \[get_runs $tcl_obj\] \"\"\]\} \{"
          lappend l_script_data "  create_run -name $tcl_obj -part $part -flow {[get_property flow [get_runs $tcl_obj]]} -strategy \"$strategy\" -constrset $constrs_set$parent_run_str"
          lappend l_script_data "\}"
  
          write_props $proj_name $get_what $tcl_obj "run"
        }
  
        return 0
    }

    proc write_simulation_runs {} {

        # Summary: write simulation run 
        # This helper command is used to script help.
    
        # Argument Usage: 
        
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        variable a_global_vars
        variable l_script_data

        set mode "behavioral"
        set type ""
        set get_what "get_filesets"
        foreach tcl_obj [get_filesets] {
          if { [string equal [get_property fileset_type [$get_what $tcl_obj]] "SimulationSrcs"] } {
            lappend l_script_data "\n# LAUNCH SIMULATION ($tcl_obj)"
            write_simulation_run $tcl_obj $mode $type
          }
        }

        return 0
    }

    proc write_simulation_run { tcl_obj mode type } {

        # Summary: write simulation runs 
        # This helper command is used to script help.
    
        # Argument Usage: 
    
        # Return Value:
        # TCL_OK is returned if the procedure completed successfully.

        variable a_global_vars
        variable l_script_data

        set sim_task "launch_xsim"
        set simulator [get_property target_simulator [current_project]]
        switch -regexp -- $simulator {
          "XSim"     { set sim_task "launch_xsim" }
          "ModelSim" { set sim_task "launch_modelsim" }
          default  { puts "unknown simulator type" }
        }
        set tcl_cmd "$sim_task -simset $tcl_obj -mode $mode"
        if { $a_global_vars(b_arg_launch_runs) } {
          lappend ::$tcl_cmd
        } else {
          lappend l_script_data "#$tcl_cmd"
        }
  
        return 0
    }  

    proc write_project_tcl {args} {

	    # Summary: 
	    # This helper command is used to create a new project.
	
	    # Argument Usage: 
	    # filename : This is the file name of the report.
	    
	    # Return Value:
        # TCL_OK is returned if the procedure completed successfully.
	
	    # Examples:
	    # write_project_tcl [-force] [-all_properties] [-no_copy_sources] <file>

	    # reset global variables
        variable a_global_vars

	    reset_global_vars

	    # if help
	    if { "?" in $args || "-help" in $args || "-h" in $args } {
	      usage;
	      return true
	    }

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
			    puts "ERROR: invalid switch specified"
			    usage;
			    return false
		      }
		      set a_global_vars(script_file) $option
		    }
	      }
	    }

	    # script file is a must
	    if { [string equal $a_global_vars(script_file) ""] } {
	      puts "ERROR: Tcl script filename not specified!\n"
	      usage;
	      return false
	    }
      
	    # should not be a directory
	    if { [file isdirectory $a_global_vars(script_file)] } {
	      puts "ERROR: The specified filename is a directory ($a_global_vars(script_file))"
	      usage;
	      return false
	    }

	    # check extension
	    if { [file extension $a_global_vars(script_file)] != ".tcl" } {
	      set a_global_vars(script_file) $a_global_vars(script_file).tcl
	    }
	    set a_global_vars(script_file [file normalize $a_global_vars(script_file)]
  
	    # recommend -force if file exists
	    if { [file exists $a_global_vars(script_file)] && !$a_global_vars(b_arg_force) } {
	      puts "ERROR: Tcl Script '$a_global_vars(script_file)' already exist. Use -force option to overwrite."
	      return false
	    }
      
	    # now write
	    write_project_tcl_script
    
	    return 0
    }
}
