####################################################################################
#
# write_project_tcl.tcl (write a Vivado project tcl script for re-creating project)
#
# Script created on 02/08/2013 by Raj Klair (Xilinx, Inc.)
#
# 2014.2 - v2.0 (rev 4)
#  * do not return value from main proc
#  * fixed bug with relative file path calculation (break from loop while comparing
#    directory elements of file paths for file to make relative to o/p script dir)
# 2014.1 - v2.0 (rev 3)
#  * make source file paths relative to script output directory
#
# 2013.4 -
# 2013.3 -
# 2013.2 - v1.0 (rev 2)
#  * no change
#
# 2013.1 - v1.0 (rev 1)
#  * initial version
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::projutils {
  namespace export write_project_tcl
}

namespace eval ::tclapp::xilinx::projutils {
proc write_project_tcl {args} {
  # Summary: 
  # Export Tcl script for re-creating the current project

  # Argument Usage: 
  # [-paths_relative_to <arg> = Script output directory path]: Override the reference directory variable for source file relative paths
  # [-target_proj_dir <arg> = Current project directory path]: Directory where the project needs to be restored
  # [-force]: Overwrite existing tcl script file
  # [-all_properties]: Write all properties (default & non-default) for the project object(s)
  # [-no_copy_sources]: Do not import sources even if they were local in the original project
  # [-absolute_path]: Make all file paths absolute wrt the original project directory
  # [-dump_project_info]: Write object values
  # file: Name of the tcl script file to generate

  # Return Value:
  # true (0) if success, false (1) otherwise

  # Categories: xilinxtclstore, projutils

  # reset global variables
  variable a_global_vars
 
  reset_global_vars
 
  # process options
  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-paths_relative_to"    { incr i;set a_global_vars(s_relative_to) [file normalize [lindex $args $i]] }
      "-target_proj_dir"      { incr i;set a_global_vars(s_target_proj_dir) [lindex $args $i] }
      "-force"                { set a_global_vars(b_arg_force) 1 }
      "-all_properties"       { set a_global_vars(b_arg_all_props) 1 }
      "-no_copy_sources"      { set a_global_vars(b_arg_no_copy_srcs) 1 }
      "-absolute_path"        { set a_global_vars(b_absolute_path) 1 }
      "-dump_project_info"    { set a_global_vars(b_arg_dump_proj_info) 1 }
      default {
        # is incorrect switch specified?
        if { [regexp {^-} $option] } {
          send_msg_id Vivado-projutils-001 ERROR "Unknown option '$option', please type 'write_project_tcl -help' for usage info.\n"
          return
        }
        set a_global_vars(script_file) $option
      }
    }
  }
 
  # script file is a must
  if { [string equal $a_global_vars(script_file) ""] } {
    send_msg_id Vivado-projutils-002 ERROR "Missing value for option 'file', please type 'write_project_tcl -help' for usage info.\n"
    return
  }
        
  # should not be a directory
  if { [file isdirectory $a_global_vars(script_file)] } {
    send_msg_id Vivado-projutils-003 ERROR "The specified filename is a directory ($a_global_vars(script_file)), please type 'write_project_tcl -help' for usage info.\n"
    return
  }
   
  # check extension
  if { [file extension $a_global_vars(script_file)] != ".tcl" } {
    set a_global_vars(script_file) $a_global_vars(script_file).tcl
  }
  set a_global_vars(script_file) [file normalize $a_global_vars(script_file)]
  
  # error if file directory path does not exist
  set file_path [file dirname $a_global_vars(script_file)]
  if { ! [file exists $file_path] } {
    set script_filename [file tail $a_global_vars(script_file)]
    send_msg_id Vivado-projutils-013 ERROR "Directory in which file ${script_filename} is to be written does not exist \[$a_global_vars(script_file)\]\n"
    return
  }
    
  # recommend -force if file exists
  if { [file exists $a_global_vars(script_file)] && !$a_global_vars(b_arg_force) } {
    send_msg_id Vivado-projutils-004 ERROR "Tcl Script '$a_global_vars(script_file)' already exist. Use -force option to overwrite.\n"
    return
  }

  # set script file directory path
  set a_global_vars(s_path_to_script_dir) [file normalize $file_path]
  
  # now write
  if {[write_project_tcl_script]} {
    return
  }
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
    
# Setup filter for non-user-settable filetypes
set l_filetype_filter [list "ip" "ipx" "embedded design sources" "elf" "coefficient files" "configuration files" \
                            "block diagrams" "block designs" "dsp design sources" "text" \
                            "design checkpoint" "waveform configuration file"]
# ip file extension types
variable l_valid_ip_extns [list]
set l_valid_ip_extns      [list ".xci" ".bd" ".slx"]

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

  set a_global_vars(s_relative_to)        {.}
  set a_global_vars(s_path_to_script_dir) ""
  set a_global_vars(s_target_proj_dir)    ""
  set a_global_vars(b_arg_force)          0
  set a_global_vars(b_arg_no_copy_srcs)   0
  set a_global_vars(b_absolute_path)      0
  set a_global_vars(b_arg_all_props)      0
  set a_global_vars(b_arg_dump_proj_info) 0
  set a_global_vars(b_local_sources)      0
  set a_global_vars(curr_time)            [clock format [clock seconds]]
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
    set dump_file [file normalize [file join $a_global_vars(s_path_to_script_dir) ${proj_name}_dump.txt]]
    if {[catch {open $dump_file w} a_global_vars(dp_fh)]} {
      send_msg_id Vivado-projutils-006 ERROR "failed to open file for write ($dump_file)\n"
      return 1
    }

    # default value output file script handle
    set def_val_file [file normalize [file join $a_global_vars(s_path_to_script_dir) ${proj_name}_def_val.txt]]
    if {[catch {open $def_val_file w} a_global_vars(def_val_fh)]} {
      send_msg_id Vivado-projutils-007 ERROR "failed to open file for write ($file)\n"
      return 1
    }
  }

  # explicitly update the compile order for current source/simset, if following conditions are met
  if { {All} == [get_property source_mgmt_mode [current_project]] &&
       {0}   == [get_property is_readonly [current_project]] &&
       {RTL} == [get_property design_mode [current_fileset]] } {


    # re-parse source fileset compile order for the current top
    if {[llength [get_files -compile_order sources -used_in synthesis]] > 1} {
      update_compile_order -fileset [current_fileset] -quiet
    }

    # re-parse simlulation fileset compile order for the current top
    if {[llength [get_files -compile_order sources -used_in simulation]] > 1} {
      update_compile_order -fileset [current_fileset -simset] -quiet
    }
  }

  # writer helpers
  wr_create_project $proj_dir $proj_name $part_name
  wr_project_properties $proj_dir $proj_name
  wr_filesets $proj_dir $proj_name
  wr_runs $proj_dir $proj_name
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

  set script_filename [file tail $file]
  set out_dir [file dirname [file normalize $file]]
  send_msg_id Vivado-projutils-008 INFO "Tcl script '$script_filename' generated in output directory '$out_dir'\n\n"

  if { $a_global_vars(b_absolute_path) } {
    send_msg_id Vivado-projutils-016 INFO "Please note that the -absolute_path switch was specified, hence the project source files will be referenced using\n\
    absolute path only, in the generated script. As such, the generated script will only work in the same filesystem where those absolute paths are accessible."
  } else {
    if { "." != $a_global_vars(s_relative_to) } {
      send_msg_id Vivado-projutils-017 INFO "Please note that the -paths_relative_to switch was specified, hence the project source files will be referenced\n\
      wrt the path that was specified with this switch. The 'origin_dir' variable is set to this path in the generated script."
    } else {
      send_msg_id Vivado-projutils-015 INFO "Please note that by default, the file path for the project source files were set wrt the 'origin_dir' variable in the\n\
      generated script. When this script is executed from the output directory, these source files will be referenced wrt this 'origin_dir' path value.\n\
      In case this script was later physically moved to a different directory, the 'origin_dir' value MUST be set manually in the script with the path\n\
      relative to the new output directory to make sure that the source files are referenced correctly from the original project. You can also set the\n\
      'origin_dir' automatically by setting the 'origin_dir_loc' variable in the tcl shell before sourcing this generated script. The 'origin_dir_loc'\n\
      variable should be set to the path relative to the new output directory. Alternatively, if you are sourcing the script from the Vivado command line,\n\
      then set the origin dir using '-tclargs --origin_dir <path>'. For example, 'vivado -mode tcl -source $script_filename -tclargs --origin_dir \"..\"\n"
    }
  }

  if { $a_global_vars(b_local_sources) } {
    print_local_file_msg "warning"
  } else {
    print_local_file_msg "info"
  }

  reset_global_vars

  return 0
}

proc wr_create_project { proj_dir name part_name } {
  # Summary: write create project command 
  # This helper command is used to script help.
  # Argument Usage: 
  # proj_dir: project directory path
  # name: project name
  # Return Value:
  # none

  variable a_global_vars
  variable l_script_data

  lappend l_script_data "# Set the reference directory for source file relative paths (by default the value is script directory path)"
  lappend l_script_data "set origin_dir \"$a_global_vars(s_relative_to)\""
  lappend l_script_data ""
  set var_name "origin_dir_loc"
  lappend l_script_data "# Use origin directory path location variable, if specified in the tcl shell"
  lappend l_script_data "if \{ \[info exists ::$var_name\] \} \{"
  lappend l_script_data "  set origin_dir \$::$var_name"
  lappend l_script_data "\}"

  lappend l_script_data ""

  lappend l_script_data "variable script_file"
  lappend l_script_data "set script_file \"[file tail $a_global_vars(script_file)]\"\n"
  lappend l_script_data "# Help information for this script"
  lappend l_script_data "proc help \{\} \{"
  lappend l_script_data "  variable script_file"
  lappend l_script_data "  puts \"\\nDescription:\""
  lappend l_script_data "  puts \"Recreate a Vivado project from this script. The created project will be\""
  lappend l_script_data "  puts \"functionally equivalent to the original project for which this script was\""
  lappend l_script_data "  puts \"generated. The script contains commands for creating a project, filesets,\""
  lappend l_script_data "  puts \"runs, adding/importing sources and setting properties on various objects.\\n\""
  lappend l_script_data "  puts \"Syntax:\""
  lappend l_script_data "  puts \"\$script_file\""
  lappend l_script_data "  puts \"\$script_file -tclargs \\\[--origin_dir <path>\\\]\""
  lappend l_script_data "  puts \"\$script_file -tclargs \\\[--help\\\]\\n\""
  lappend l_script_data "  puts \"Usage:\""
  lappend l_script_data "  puts \"Name                   Description\""
  lappend l_script_data "  puts \"-------------------------------------------------------------------------\""
  lappend l_script_data "  puts \"\\\[--origin_dir <path>\\\]  Determine source file paths wrt this path. Default\""
  lappend l_script_data "  puts \"                       origin_dir path value is \\\".\\\", otherwise, the value\""
  lappend l_script_data "  puts \"                       that was set with the \\\"-paths_relative_to\\\" switch\""
  lappend l_script_data "  puts \"                       when this script was generated.\\n\""
  lappend l_script_data "  puts \"\\\[--help\\\]               Print help information for this script\""
  lappend l_script_data "  puts \"-------------------------------------------------------------------------\\n\""
  lappend l_script_data "  exit 0"
  lappend l_script_data "\}\n"
  lappend l_script_data "if \{ \$::argc > 0 \} \{"
  lappend l_script_data "  for \{set i 0\} \{\$i < \[llength \$::argc\]\} \{incr i\} \{"
  lappend l_script_data "    set option \[string trim \[lindex \$::argv \$i\]\]"
  lappend l_script_data "    switch -regexp -- \$option \{"
  lappend l_script_data "      \"--origin_dir\" \{ incr i; set origin_dir \[lindex \$::argv \$i\] \}"
  lappend l_script_data "      \"--help\"       \{ help \}"
  lappend l_script_data "      default \{"
  lappend l_script_data "        if \{ \[regexp \{^-\} \$option\] \} \{"
  lappend l_script_data "          puts \"ERROR: Unknown option '\$option' specified, please type '\$script_file -tclargs --help' for usage info.\\n\""
  lappend l_script_data "          return 1"
  lappend l_script_data "        \}"
  lappend l_script_data "      \}"
  lappend l_script_data "    \}"
  lappend l_script_data "  \}"
  lappend l_script_data "\}\n"

  lappend l_script_data "# Set the directory path for the original project from where this script was exported"
  if { $a_global_vars(b_absolute_path) } {
    lappend l_script_data "set orig_proj_dir \"$proj_dir\""
  } else {
    set rel_file_path "[get_relative_file_path_for_source $proj_dir [get_script_execution_dir]]"
    set path "\[file normalize \"\$origin_dir/$rel_file_path\"\]"
    lappend l_script_data "set orig_proj_dir \"$path\""
  }
  lappend l_script_data ""

  # create project
  lappend l_script_data "# Create project"
    
  set tcl_cmd ""
  # set target project directory path if specified. If not, create project dir in current dir.
  set target_dir $a_global_vars(s_target_proj_dir)
  if { {} == $target_dir } {
    set tcl_cmd "create_project $name ./$name -part $part_name"
  } else {
    # is specified target proj dir == current dir? 
    set cwd [file normalize [string map {\\ /} [pwd]]]
    set dir [file normalize [string map {\\ /} $target_dir]]
    if { [string equal $cwd $dir] } {
      set tcl_cmd "create_project $name -part $part_name"
    } else {
      set tcl_cmd "create_project $name \"$target_dir\" -part $part_name"
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
  lappend l_script_data "# Reconstruct message rules"

  set msg_control_rules [ debug::get_msg_control_rules -as_tcl ]
  if { [string length $msg_control_rules] > 0 } {
    lappend l_script_data "${msg_control_rules}"
  } else {
    lappend l_script_data "# None"
  }
  lappend l_script_data ""
}

proc wr_project_properties { proj_dir proj_name } {
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

  # is project "board_part" set already?
  if { [string length [get_property "board_part" $tcl_obj]] > 0 } {
    set b_project_board_set 1
  }

  write_props $proj_dir $proj_name $get_what $tcl_obj "project"
}

proc wr_filesets { proj_dir proj_name } {
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
    write_specified_fileset $proj_dir $proj_name $filesets
  }
}

proc write_specified_fileset { proj_dir proj_name filesets } {
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

    # Is this a IP block fileset for a proxy IP that is owned by another composite file?
    # If so, we don't want to write it out as an independent file. The parent will take care of it.
    if { [is_proxy_ip_fileset $tcl_obj] } {
      continue
    }

    set fs_type [get_property fileset_type [get_filesets $tcl_obj]]

    # is this a IP block fileset? if yes, do not create block fileset, but create for a pure HDL based fileset (no IP's)
    if { [is_ip_fileset $tcl_obj] } {
      # do not create block fileset
    } else {
      lappend l_script_data "# Create '$tcl_obj' fileset (if not found)"
      lappend l_script_data "if \{\[string equal \[get_filesets -quiet $tcl_obj\] \"\"\]\} \{"

      set fs_sw_type [get_fileset_type_switch $fs_type]
      lappend l_script_data "  create_fileset $fs_sw_type $tcl_obj"
      lappend l_script_data "\}\n"  
    }

    set get_what_fs "get_filesets"

    # set IP REPO PATHS (if any) for filesets of type "DesignSrcs" or "BlockSrcs"
    if { (({DesignSrcs} == $fs_type) || ({BlockSrcs} == $fs_type)) } {
      if { ({RTL} == [get_property design_mode [get_filesets $tcl_obj]]) } {
        set repo_paths [get_ip_repo_paths $tcl_obj]
        if { [llength $repo_paths] > 0 } {
          lappend l_script_data "# Set IP repository paths"
          lappend l_script_data "set obj \[get_filesets $tcl_obj\]"
          set path_list [list]
          foreach path $repo_paths {
            if { $a_global_vars(b_absolute_path) } {
              lappend path_list $path
            } else {
              set rel_file_path "[get_relative_file_path_for_source $path [get_script_execution_dir]]"
              set path "\[file normalize \"\$origin_dir/$rel_file_path\"\]"
              lappend path_list $path
            }
          }
          set repo_path_str [join $path_list " "]
          lappend l_script_data "set_property \"ip_repo_paths\" \"${repo_path_str}\" \$obj" 
          lappend l_script_data "" 
          lappend l_script_data "# Rebuild user ip_repo's index before adding any source files"
          lappend l_script_data "update_ip_catalog -rebuild"
          lappend l_script_data ""
        }
      }
    }

    # is this a IP block fileset? if yes, then set the current srcset object (IP's will be added to current source fileset)
    if { [is_ip_fileset $tcl_obj] } {
      set srcset [current_fileset -srcset]
      lappend l_script_data "# Set '$srcset' fileset object"
      lappend l_script_data "set obj \[$get_what_fs $srcset\]"
    } else {
      lappend l_script_data "# Set '$tcl_obj' fileset object"
      lappend l_script_data "set obj \[$get_what_fs $tcl_obj\]"
    }
    if { {Constrs} == $fs_type } {
      lappend l_script_data ""
      write_constrs $proj_dir $proj_name $tcl_obj $type
    } else {
      write_files $proj_dir $proj_name $tcl_obj $type
    }
  
    # is this a IP block fileset? if yes, do not write block fileset properties (block fileset doesnot exist in new project)
    if { [is_ip_fileset $tcl_obj] } {
      # do not write ip fileset properties
    } else {
      lappend l_script_data "# Set '$tcl_obj' fileset properties"
      lappend l_script_data "set obj \[$get_what_fs $tcl_obj\]"
      write_props $proj_dir $proj_name $get_what_fs $tcl_obj "fileset"
    }
  }
}

proc wr_runs { proj_dir proj_name } {
  # Summary: write runs and properties 
  # This helper command is used to script help.
  # Argument Usage: 
  # proj_name: project name
  # Return Value:
  # None

  variable l_script_data

  # write runs (synthesis, Implementation)
  set runs [get_runs -filter {IS_SYNTHESIS == 1}]
  write_specified_run $proj_dir $proj_name $runs

  if { {RTL} == [get_property design_mode [current_fileset]] } {
    lappend l_script_data "# set the current synth run"
    lappend l_script_data "current_run -synthesis \[get_runs [current_run -synthesis]\]\n"
  }

  set runs [get_runs -filter {IS_IMPLEMENTATION == 1}]
  write_specified_run $proj_dir $proj_name $runs

  lappend l_script_data "# set the current impl run"
  lappend l_script_data "current_run -implementation \[get_runs [current_run -implementation]\]"
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

  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 2]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]

  set tcl_file [file tail $file]
  puts $a_global_vars(fh) "#\n# $product (TM) $version_id"
  puts $a_global_vars(fh) "#\n# $tcl_file: Tcl script for re-creating project '$proj_name'\n#"
  puts $a_global_vars(fh) "# Generated by $product on $a_global_vars(curr_time)"
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
  puts $a_global_vars(fh) "#    (Please see the '\$orig_proj_dir' and '\$origin_dir' variable setting below at the start of the script)\n#"

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
    send_msg_id Vivado-projutils-010 WARNING "Found source(s) that were local or imported into the project. If this project is being source controlled, then\n\
    please ensure that the project source(s) are also part of this source controlled data. The list of these local source(s) can be found in the generated script\n\
    under the header section."
  } else {
    send_msg_id Vivado-projutils-011 INFO "If this project is being source controlled, then please ensure that the project source(s) are also part of this source\n\
    controlled data. The list of these local source(s) can be found in the generated script under the header section."
  }
  puts ""
}

proc get_ip_repo_paths { tcl_obj } {
  # Summary:
  # Iterate over the fileset properties and get the ip_repo_paths (if set)
  # Argument Usage: 
  # tcl_obj : fileset
  # Return Value:
  # List of repo paths
 
  set repo_path_list [list]
  foreach path [get_property ip_repo_paths [get_filesets $tcl_obj]] {
    lappend repo_path_list $path
  }
  return $repo_path_list
}

proc is_deprecated { prop } {
  # Summary: filter deprecated properties
  # Argument Usage:
  # Return Value:
  # true (1) if found, false (1) otherwise

  set prop [string toupper $prop]
  if { $prop == "BOARD" } {
    return 1
  }
  return 0
}

proc filter { prop val { file {} } } {
  # Summary: filter special properties
  # This helper command is used to script help.
  # Argument Usage: 
  # Return Value:
  # true (1) if found, false (1) otherwise

  variable l_filetype_filter
  variable l_valid_ip_extns

  set prop [string toupper $prop]
  if { [expr { $prop == "BOARD" } || \
             { $prop == "IS_HD" } || \
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

  # filter readonly is_managed property for ip
  if { [string equal $prop "IS_MANAGED"] } {
    if { [lsearch -exact $l_valid_ip_extns [string tolower [file extension $file]]] >= 0 } {
      return 1
    }
  }

  # filter ip_repo_paths (ip_repo_paths is set before adding sources)
  if { [string equal -nocase $prop {ip_repo_paths}] } {
    return 1
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

proc is_ip_readonly_prop { name } {
  # Summary: Return true if dealing with following IP properties that are not settable for an IP in read-only state
  # Argument Usage:
  # name: property name
  # Return Value:
  # true if success, false otherwise

  if { [regexp -nocase {synth_checkpoint_mode}     $name] ||
       [regexp -nocase {is_locked}                 $name] ||
       [regexp -nocase {generate_synth_checkpoint} $name] } {
    return true
  }

  return false
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
    set b_add_closing_brace 0
    foreach x $prop_info_list {
      set elem [split $x "#"]
      set name [lindex $elem 0]
      set value [lindex $elem 1]
      if { [regexp "more options" $name] } {
        set cmd_str "set_property -name {$name} -value {$value} -objects"
      } elseif { ([is_ip_readonly_prop $name]) && ([string equal $get_what "get_files"]) } {
        set cmd_str "if \{ !\[get_property \"is_locked\" \$file_obj\] \} \{"
        lappend l_script_data "$cmd_str"
        set cmd_str "  set_property \"$name\" \"$value\""
        set b_add_closing_brace 1
      } else {
        set cmd_str "set_property \"$name\" \"$value\""
      }
      if { [string equal $get_what "get_files"] } {
        lappend l_script_data "$cmd_str \$file_obj"
        if { $b_add_closing_brace } {
          lappend l_script_data "\}"
          set b_add_closing_brace 0
        }
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

proc write_props { proj_dir proj_name get_what tcl_obj type } {
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
    if { [is_deprecated $prop] } { continue }

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
      set attr_spec [rdi::get_attr_specs -quiet $prop -object [$get_what $tcl_obj]]
      if { {} == $attr_spec } {
        set prop_lower [string tolower $prop]
        set attr_spec [rdi::get_attr_specs -quiet $prop_lower -object [$get_what $tcl_obj]]
      }
      set prop_type [get_property type $attr_spec]
    }
    set def_val [list_property_value -default $prop $tcl_obj]
    set dump_prop_name [string tolower ${obj_name}_${type}_$prop]
    set cur_val [get_property $prop $tcl_obj]

    # filter special properties
    if { [filter $prop $cur_val] } { continue }

    # do not set "runs" or "project" part, if "board_part" is set
    if { ([string equal $type "project"] || [string equal $type "run"]) && 
         [string equal -nocase $prop "part"] &&
         $b_project_board_set } {
      continue
    }

    # do not set "fileset" target_part, if "board_part" is set
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
        set proj_file_path "[get_relative_file_path_for_source $src_file [get_script_execution_dir]]"
      }
      set prop_entry "[string tolower $prop]#$proj_file_path"

    } elseif {([string equal -nocase $prop "target_constrs_file"] ||
               [string equal -nocase $prop "target_ucf"]) &&
               ($cur_val != "") } {
 
      set file $cur_val
      set fs_name $tcl_obj

      set path_dirs [split [string trim [file normalize [string map {\\ /} $file]]] "/"]
      set src_file [join [lrange $path_dirs [lsearch -exact $path_dirs "$fs_name"] end] "/"]
      set file_object [lindex [get_files -of_objects [get_filesets $fs_name] [list $file]] 0]
      set file_props [list_property $file_object]

      if { [lsearch $file_props "IMPORTED_FROM"] != -1 } {
        if { $a_global_vars(b_arg_no_copy_srcs) } {
          set proj_file_path "\$orig_proj_dir/${proj_name}.srcs/$src_file"
        } else {
          set proj_file_path "\$proj_dir/${proj_name}.srcs/$src_file"
        }
      } else {
        # is file new inside project?
        if { [is_local_to_project $file] } {
          # is file inside fileset dir?
          if { [regexp "^${fs_name}/" $src_file] } {
            set proj_file_path "\$orig_proj_dir/${proj_name}.srcs/$src_file"
          } else {
            set file_no_quotes [string trim $file "\""]
            set rel_file_path [get_relative_file_path_for_source $file_no_quotes [get_script_execution_dir]]
            set proj_file_path "\[file normalize \"\$origin_dir/$rel_file_path\"\]"
            #set proj_file_path "$file"
          }
        } else {
          if { $a_global_vars(b_absolute_path) } {
            set proj_file_path "$file"
          } else {
            set file_no_quotes [string trim $file "\""]
            set rel_file_path [get_relative_file_path_for_source $file_no_quotes [get_script_execution_dir]]
            set proj_file_path "\[file normalize \"\$origin_dir/$rel_file_path\"\]"
          }
        }
      }

      set prop_entry "[string tolower $prop]#$proj_file_path"
    }

 
    # re-align compiled_library_dir
    if { [string equal -nocase $prop "compxlib.compiled_library_dir"] ||
         [string equal -nocase $prop "compxlib.modelsim_compiled_library_dir"] ||
         [string equal -nocase $prop "compxlib.questa_compiled_library_dir"] ||
         [string equal -nocase $prop "compxlib.ies_compiled_library_dir"] ||
         [string equal -nocase $prop "compxlib.vcs_compiled_library_dir"] ||
         [string equal -nocase $prop "compxlib.riviera_compiled_library_dir"] ||
         [string equal -nocase $prop "compxlib.activehdl_compiled_library_dir"] } {
      set compile_lib_dir_path $cur_val
      set cache_dir "${proj_name}.cache"
      set path_dirs [split [string trim [file normalize [string map {\\ /} $cur_val]]] "/"]
      if {[lsearch -exact $path_dirs "$cache_dir"] > 0} {
        set dir_path [join [lrange $path_dirs [lsearch -exact $path_dirs "$cache_dir"] end] "/"]
        set compile_lib_dir_path "\$proj_dir/$dir_path"
      }
      set prop_entry "[string tolower $prop]#$compile_lib_dir_path"
    }

    # process run step tcl pre/post properties
    if { [string equal $type "run"] } {
      if { [regexp "STEPS" $prop] } {
        if { [regexp "TCL.PRE" $prop] || [regexp "TCL.POST" $prop] } {
          if { ($cur_val != "") } {
            set file $cur_val

            set srcs_dir "${proj_name}.srcs"
            set file_dirs [split [string trim [file normalize [string map {\\ /} $file]]] "/"]
            set src_file [join [lrange $file_dirs [lsearch -exact $file_dirs "$srcs_dir"] end] "/"]

            set tcl_file_path {}
            if { [is_local_to_project $file] } {
              set tcl_file_path "\$proj_dir/$src_file"
            } else {
              if { $a_global_vars(b_absolute_path) } {
                set tcl_file_path "$file"
              } else {
                set rel_file_path "[get_relative_file_path_for_source $src_file [get_script_execution_dir]]"
                set tcl_file_path "\[file normalize \"\$origin_dir/$rel_file_path\"\]"
              }
            }
            set prop_entry "[string tolower $prop]#$tcl_file_path"
          }
        }
      }
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

  if { {fileset} == $type } {
    set fs_type [get_property fileset_type [get_filesets $tcl_obj]]
    if { {SimulationSrcs} == $fs_type } {
      if { ![get_property is_readonly [current_project]] } {
        add_simulator_props $get_what $tcl_obj prop_info_list
      }
    }
  }

  # write properties now
  write_properties $prop_info_list $get_what $tcl_obj

}

proc add_simulator_props { get_what tcl_obj prop_info_list_arg } {
  # Summary: write file and file properties 
  # This helper command is used to script help.
  # Argument Usage: 
  # Return Value:
  # none
  upvar $prop_info_list_arg prop_info_list

  set target_simulator [get_property target_simulator [current_project]]
  set simulators [get_simulators]
  foreach simulator [get_simulators] {
    if { $target_simulator == $simulator } { continue }
    set_property target_simulator $simulator [current_project]
    set prefix [string tolower [lindex [split $simulator {.}] 0]]
    write_simulator_props $prefix $get_what $tcl_obj prop_info_list
  }
  set_property target_simulator $target_simulator [current_project]
}

proc write_simulator_props { prefix get_what tcl_obj prop_info_list_arg } {
  # Summary: write non-default simulator properties
  # Argument Usage: 
  # Return Value:
  # none
  
  upvar $prop_info_list_arg prop_info_list
  variable a_global_vars
  variable l_script_data

  set read_only_props [rdi::get_attr_specs -class [get_property class $tcl_obj] -filter {is_readonly}]
  foreach prop [list_property [$get_what $tcl_obj]] {
    if { [lsearch $read_only_props $prop] != -1 } { continue }
    if { [is_deprecated_property $prop] } { continue }
    set sim_prefix [string tolower [lindex [split $prop {.}] 0]]
    if { $prefix != $sim_prefix } { continue }

    set attr_spec [rdi::get_attr_specs -quiet $prop -object [$get_what $tcl_obj]]
    if { {} == $attr_spec } {
      set prop_lower [string tolower $prop]
      set attr_spec [rdi::get_attr_specs -quiet $prop_lower -object [$get_what $tcl_obj]]
    }
    set prop_type [get_property type $attr_spec]
    set def_val [list_property_value -default $prop $tcl_obj]
    set cur_val [get_property $prop $tcl_obj]
    set cur_val [get_target_bool_val $def_val $cur_val]
    set prop_entry "[string tolower $prop]#[get_property $prop [$get_what $tcl_obj]]"
    if { $def_val != $cur_val } {
      lappend prop_info_list $prop_entry
    }
  }
}

proc is_deprecated_property { property } {
  # Summary: filter old properties
  # Argument Usage: 
  # Return Value:

  set property [string tolower $property]

  if { [string equal $property "runtime"] ||
       [string equal $property "unit_under_test"] ||
       [string equal $property "xelab.snapshot"] ||
       [string equal $property "xelab.debug_level"] ||
       [string equal $property "xelab.relax"] ||
       [string equal $property "xelab.mt_level"] ||
       [string equal $property "xelab.load_glbl"] ||
       [string equal $property "xelab.rangecheck"] ||
       [string equal $property "xelab.sdf_delay"] ||
       [string equal $property "xelab.unifast"] ||
       [string equal $property "xelab.nosort"] ||
       [string equal $property "xelab.more_options"] ||
       [string equal $property "xsim.view"] ||
       [string equal $property "xsim.wdb"] ||
       [string equal $property "xsim.saif"] ||
       [string equal $property "xsim.more_options"] ||
       [string equal $property "modelsim.custom_do"] ||
       [string equal $property "modelsim.custom_udo"] ||
       [string equal $property "modelsim.vhdl_syntax"] ||
       [string equal $property "modelsim.use_explicit_decl"] ||
       [string equal $property "modelsim.log_all_signals"] ||
       [string equal $property "modelsim.sdf_delay"] ||
       [string equal $property "modelsim.saif"] ||
       [string equal $property "modelsim.incremental"] ||
       [string equal $property "modelsim.unifast"] ||
       [string equal $property "modelsim.64bit"] ||
       [string equal $property "modelsim.vsim_more_options"] ||
       [string equal $property "modelsim.vlog_more_options"] ||
       [string equal $property "modelsim.vcom_more_options"] } {
     return true
  }
  return false
}

proc write_files { proj_dir proj_name tcl_obj type } {
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
  if {[llength [get_files -quiet -of_objects [get_filesets $tcl_obj]]] == 0 } {
    lappend l_script_data "# Empty (no sources present)\n"
    return
  }

  set fs_name [get_filesets $tcl_obj]

  set import_coln [list]
  set add_file_coln [list]

  foreach file [get_files -norecurse -of_objects [get_filesets $tcl_obj]] {
    if { [file extension $file] == ".xcix" } { continue }
    set path_dirs [split [string trim [file normalize [string map {\\ /} $file]]] "/"]
    set begin [lsearch -exact $path_dirs "$proj_name.srcs"]
    set src_file [join [lrange $path_dirs $begin+1 end] "/"]

    # fetch first object
    set file_object [lindex [get_files -of_objects [get_filesets $fs_name] [list $file]] 0]
    set file_props [list_property $file_object]

    if { [lsearch $file_props "IMPORTED_FROM"] != -1 } {

      # import files
      set imported_path [get_property "imported_from" $file]
      set rel_file_path [get_relative_file_path_for_source $file [get_script_execution_dir]]
      set proj_file_path "\$origin_dir/$rel_file_path"

      set file "\"[file normalize $proj_dir/${proj_name}.srcs/$src_file]\""

      if { $a_global_vars(b_arg_no_copy_srcs) } {
        # add to the local collection
        lappend l_remote_file_list $file
        if { $a_global_vars(b_absolute_path) } {
          lappend add_file_coln "$file"
        } else {
          lappend add_file_coln "\"\[file normalize \"$proj_file_path\"\]\""
        }
      } else {
        # add to the import collection
        lappend l_local_file_list $file
        if { $a_global_vars(b_absolute_path) } {
          lappend import_coln "$file"
        } else {
          lappend import_coln "\"\[file normalize \"$proj_file_path\"\]\""
        }
      }

    } else {
      set file "\"$file\""

      # is local? add to local project, add to collection and then import this collection by default unless -no_copy_sources is specified
      if { [is_local_to_project $file] } {
        if { $a_global_vars(b_arg_dump_proj_info) } {
          set src_file "\$PSRCDIR/$src_file"
        }

        # add to the import collection
        set file_no_quotes [string trim $file "\""]
        set org_file_path "\$origin_dir/[get_relative_file_path_for_source $file_no_quotes [get_script_execution_dir]]"
        lappend import_coln "\"\[file normalize \"$org_file_path\"\]\""
        lappend l_local_file_list $file
      } else {
        lappend l_remote_file_list $file
      }

      # add file to collection
      if { $a_global_vars(b_arg_no_copy_srcs) && (!$a_global_vars(b_absolute_path))} {
        set file_no_quotes [string trim $file "\""]
        set rel_file_path [get_relative_file_path_for_source $file_no_quotes [get_script_execution_dir]]
        set file1 "\"\[file normalize \"\$origin_dir/$rel_file_path\"\]\""
        lappend add_file_coln "$file1"
      } else {
        lappend add_file_coln "$file"
      }

      # set flag that local sources were found and print warning at the end
      if { !$a_global_vars(b_local_sources) } {
        set a_global_vars(b_local_sources) 1
      }
    }
  }
   
  if {[llength $add_file_coln]>0} { 
    lappend l_script_data "set files \[list \\"
    foreach file $add_file_coln {
      if { $a_global_vars(b_absolute_path) } {
        lappend l_script_data " $file\\"
      } else {
        if { $a_global_vars(b_arg_no_copy_srcs) } {
          lappend l_script_data " $file\\"
        } else {
          set file_no_quotes [string trim $file "\""]
          set rel_file_path [get_relative_file_path_for_source $file_no_quotes [get_script_execution_dir]]
          lappend l_script_data " \"\[file normalize \"\$origin_dir/$rel_file_path\"\]\"\\"
        }
      }
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
      # is this a IP block fileset? if yes, import files into current source fileset
      if { [is_ip_fileset $tcl_obj] } {
        lappend l_script_data "set imported_files \[import_files -fileset [current_fileset -srcset] \$files\]"
      } else {
        lappend l_script_data "set imported_files \[import_files -fileset $tcl_obj \$files\]"
      }
      lappend l_script_data ""
    }
  }

  # write fileset file properties for remote files (added sources)
  write_fileset_file_properties $tcl_obj $fs_name $proj_dir $l_remote_file_list "remote"

  # write fileset file properties for local files (imported sources)
  write_fileset_file_properties $tcl_obj $fs_name $proj_dir $l_local_file_list "local"

}

proc write_constrs { proj_dir proj_name tcl_obj type } {
  # Summary: write constrs fileset files and properties 
  # Argument Usage: 
  # Return Value:
  # none

  variable a_global_vars
  variable l_script_data

  set fs_name [get_filesets $tcl_obj]

  # return if empty fileset
  if {[llength [get_files -quiet -of_objects [get_filesets $tcl_obj]]] == 0 } {
    lappend l_script_data "# Empty (no sources present)\n"
    return
  }

  foreach file [get_files -norecurse -of_objects [get_filesets $tcl_obj]] {
    lappend l_script_data "# Add/Import constrs file and set constrs file properties"
    set constrs_file  {}
    set file_category {}
    set path_dirs     [split [string trim [file normalize [string map {\\ /} $file]]] "/"]
    set begin         [lsearch -exact $path_dirs "$proj_name.srcs"]
    set src_file      [join [lrange $path_dirs $begin+1 end] "/"]
    set file_object   [lindex [get_files -of_objects [get_filesets $fs_name] [list $file]] 0]
    set file_props    [list_property $file_object]

    # constrs sources imported? 
    if { [lsearch $file_props "IMPORTED_FROM"] != -1 } {
      set imported_path  [get_property "imported_from" $file]
      set rel_file_path  [get_relative_file_path_for_source $file [get_script_execution_dir]]
      set proj_file_path "\$origin_dir/$rel_file_path"
      set file           "\"[file normalize $proj_dir/${proj_name}.srcs/$src_file]\""
      # donot copy imported constrs in new project? set it as remote file in new project.
      if { $a_global_vars(b_arg_no_copy_srcs) } {
        set constrs_file $file
        set file_category "remote"
        if { $a_global_vars(b_absolute_path) } {
          add_constrs_file "$file"
        } else {
          set str "\"\[file normalize \"$proj_file_path\"\]\""
          add_constrs_file $str
        }
      } else {
        # copy imported constrs in new project. Set it as local file in new project.
        set constrs_file $file
        set file_category "local"
        if { $a_global_vars(b_absolute_path) } {
          import_constrs_file $tcl_obj "$file"
        } else {
          set str "\"\[file normalize \"$proj_file_path\"\]\""
          import_constrs_file $tcl_obj $str
        }
      }
    } else {
      # constrs sources were added, so check if these are local or added from remote location
      set file "\"$file\""
      set constrs_file $file

      # is added constrs local to the project? import it in the new project and set it as local in the new project
      if { [is_local_to_project $file] } {
        # file is added from within project, so set it as local in the new project
        set file_category "local"

        if { $a_global_vars(b_arg_dump_proj_info) } {
          set src_file "\$PSRCDIR/$src_file"
        }
        set file_no_quotes [string trim $file "\""]
        set org_file_path "\$origin_dir/[get_relative_file_path_for_source $file_no_quotes [get_script_execution_dir]]"
        set str "\"\[file normalize \"$org_file_path\"\]\""
        if { $a_global_vars(b_arg_no_copy_srcs)} {
          add_constrs_file "$str"
        } else {
          import_constrs_file $tcl_obj $str
        }
      } else {
        # file is added from remote location, so set it as remote in the new project
        set file_category "remote"
 
        # find relative file path of the added constrs if no_copy in the new project
        if { $a_global_vars(b_arg_no_copy_srcs) && (!$a_global_vars(b_absolute_path))} {
          set file_no_quotes [string trim $file "\""]
          set rel_file_path [get_relative_file_path_for_source $file_no_quotes [get_script_execution_dir]]
          set file_1 "\"\[file normalize \"\$origin_dir/$rel_file_path\"\]\""
          add_constrs_file "$file_1"
        } else {
          add_constrs_file "$file"
        }
      }

      # set flag that local sources were found and print warning at the end
      if { !$a_global_vars(b_local_sources) } {
        set a_global_vars(b_local_sources) 1
      }
    }
    write_constrs_fileset_file_properties $tcl_obj $fs_name $proj_dir $constrs_file $file_category
  }
}

proc add_constrs_file { file_str } {
  # Summary: add constrs file 
  # This helper command is used to script help.
  # Argument Usage: 
  # Return Value:
  # none

  variable a_global_vars
  variable l_script_data

  if { $a_global_vars(b_absolute_path) } {
    lappend l_script_data "set file $file_str"
  } else {
    if { $a_global_vars(b_arg_no_copy_srcs) } {
      lappend l_script_data "set file $file_str"
    } else {
      set file_no_quotes [string trim $file_str "\""]
      set rel_file_path [get_relative_file_path_for_source $file_no_quotes [get_script_execution_dir]]
      lappend l_script_data "set file \"\[file normalize \"\$origin_dir/$rel_file_path\"\]\""
    }
  }
  lappend l_script_data "set file_added \[add_files -norecurse -fileset \$obj \$file\]"
}

proc import_constrs_file { tcl_obj file_str } {
  # Summary: import constrs file 
  # This helper command is used to script help.
  # Argument Usage: 
  # Return Value:
  # none

  variable a_global_vars
  variable l_script_data

  # now import local files if -no_copy_sources is not specified
  if { ! $a_global_vars(b_arg_no_copy_srcs)} {
    lappend l_script_data "set file $file_str"
    lappend l_script_data "set file_imported \[import_files -fileset $tcl_obj \$file\]"
  }
}

proc write_constrs_fileset_file_properties { tcl_obj fs_name proj_dir file file_category } {
  # Summary: write constrs fileset file properties 
  # This helper command is used to script help.
  # Argument Usage: 
  # Return Value:
  # none

  variable a_global_vars
  variable l_script_data
  variable l_local_files
  variable l_remote_files

  set file_prop_count 0

  # collect local/remote files for the header section
  if { [string equal $file_category "local"] } {
    lappend l_local_files $file
  } elseif { [string equal $file_category "remote"] } {
    lappend l_remote_files $file
  }

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
    set file_object [lindex [get_files -of_objects [get_filesets $fs_name] [list "*$file"]] 0]
  } elseif { [string equal $file_category "remote"] } {
    set file_object [lindex [get_files -of_objects [get_filesets $fs_name] [list $file]] 0]
  }

  # get the constrs file properties
  set file_props [list_property $file_object]
  set prop_info_list [list]
  set prop_count 0
  foreach file_prop $file_props {
    set is_readonly [get_property is_readonly [rdi::get_attr_specs $file_prop -object $file_object]]
    if { [string equal $is_readonly "1"] } {
      continue
    }
    set prop_type [get_property type [rdi::get_attr_specs $file_prop -object $file_object]]
    set def_val   [list_property_value -default $file_prop $file_object]
    set cur_val   [get_property $file_prop $file_object]

    # filter special properties
    if { [filter $file_prop $cur_val $file] } { continue }

    # re-align values
    set cur_val [get_target_bool_val $def_val $cur_val]

    set dump_prop_name [string tolower ${fs_name}_file_${file_prop}]
    set prop_entry ""
    if { [string equal $file_category "local"] } {
      set prop_entry "[string tolower $file_prop]#[get_property $file_prop $file_object]"
    } elseif { [string equal $file_category "remote"] } {
      set prop_value_entry [get_property $file_prop $file_object]
      set prop_entry "[string tolower $file_prop]#$prop_value_entry"
    }
    # include all properties?
    if { $a_global_vars(b_arg_all_props) } {
      lappend prop_info_list $prop_entry
      incr prop_count
    } else {
      # include only non-default (default behavior)
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
    if { {remote} == $file_category } {
      if { $a_global_vars(b_absolute_path) } {
        lappend l_script_data "set file \"$file\""
      } else {
        lappend l_script_data "set file \"\$origin_dir/[get_relative_file_path_for_source $file [get_script_execution_dir]]\""
        lappend l_script_data "set file \[file normalize \$file\]"
      }
    } else {
      lappend l_script_data "set file \"$file\""
    }

    lappend l_script_data "set file_obj \[get_files -of_objects \[get_filesets $tcl_obj\] \[list \"*\$file\"\]\]"
    set get_what "get_files"
    write_properties $prop_info_list $get_what $tcl_obj
    incr file_prop_count
  }

  if { $file_prop_count == 0 } {
    lappend l_script_data "# None"
  }
}

proc write_specified_run { proj_dir proj_name runs } {
  # Summary: write the specified run information 
  # This helper command is used to script help.
  # Argument Usage: 
  # Return Value:
  # none 

  variable a_global_vars
  variable l_script_data

  set get_what "get_runs"
  foreach tcl_obj $runs {
    # is block fileset based run that contains IP? donot create OOC run
    if { [is_ip_run $tcl_obj] } {
      continue
    }
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
    lappend l_script_data "if \{\[string equal \[get_runs -quiet $tcl_obj\] \"\"\]\} \{"
    set cmd_str "  create_run -name $tcl_obj -part $part -flow {$cur_flow_type_val} -strategy \"$cur_strat_type_val\""
    lappend l_script_data "$cmd_str -constrset $constrs_set$parent_run_str"
    lappend l_script_data "\} else \{"
    lappend l_script_data "  set_property strategy \"$cur_strat_type_val\" \[get_runs $tcl_obj\]"
    lappend l_script_data "  set_property flow \"$cur_flow_type_val\" \[get_runs $tcl_obj\]"
    lappend l_script_data "\}"

    lappend l_script_data "set obj \[$get_what $tcl_obj\]"
    write_props $proj_dir $proj_name $get_what $tcl_obj "run"
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

proc write_fileset_file_properties { tcl_obj fs_name proj_dir l_file_list file_category } {
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
  
  # is this a IP block fileset? if yes, set current source fileset
  if { [is_ip_fileset $tcl_obj] } {
    lappend l_script_data "# Set '[current_fileset -srcset]' fileset file properties for $file_category files"
  } else {
    lappend l_script_data "# Set '$tcl_obj' fileset file properties for $file_category files"
  }
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
      set file_object [lindex [get_files -of_objects [get_filesets $fs_name] [list "*$file"]] 0]
    } elseif { [string equal $file_category "remote"] } {
      set file_object [lindex [get_files -of_objects [get_filesets $fs_name] [list $file]] 0]
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
      if { [filter $file_prop $cur_val $file] } { continue }

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
      if { {remote} == $file_category } {
        if { $a_global_vars(b_absolute_path) } {
          lappend l_script_data "set file \"$file\""
        } else {
          lappend l_script_data "set file \"\$origin_dir/[get_relative_file_path_for_source $file [get_script_execution_dir]]\""
          lappend l_script_data "set file \[file normalize \$file\]"
        }
      } else {
        lappend l_script_data "set file \"$file\""
      }
      # is this a IP block fileset? if yes, get files from current source fileset
      if { [is_ip_fileset $tcl_obj] } {
        lappend l_script_data "set file_obj \[get_files -of_objects \[get_filesets [current_fileset -srcset]\] \[list \"*\$file\"\]\]"
      } else {
        lappend l_script_data "set file_obj \[get_files -of_objects \[get_filesets $tcl_obj\] \[list \"*\$file\"\]\]"
      }
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

proc get_script_execution_dir { } {
  # Summary: Return script directory path from where the script will be executed
  # Argument Usage: 
  # none
  # Return Value:
  # Path to the script direc

  variable a_global_vars

  # default: return script directory path
  set scr_exe_dir $a_global_vars(s_path_to_script_dir)

  # is -path_to_relative specified and the path exists? return this dir
  set rel_to_dir $a_global_vars(s_relative_to)
  if { ("." != $rel_to_dir) } {
    set rel_to_dir [file normalize $rel_to_dir]
    if { [file exists $rel_to_dir] } {
      set scr_exe_dir $rel_to_dir
    }
  }
  return $scr_exe_dir
}

# TODO: This is the same as xcs_get_relative_file_path for simulators, see common/utils.tcl
# Remember to add the 'source .../common/utils.tcl' in the write_project_tcl proc to load the common file
proc get_relative_file_path_for_source { file_path_to_convert relative_to } {
  # Summary: Get the relative path wrt to path specified
  # Argument Usage:
  # file_path_to_convert: input file to make relative to specfied path
  # Return Value:
  # Relative path wrt the path specified

  variable a_xport_sim_vars

  # make sure we are dealing with a valid relative_to directory. If regular file or is not a directory, get directory
  if { [file isfile $relative_to] || ![file isdirectory $relative_to] } {
    set relative_to [file dirname $relative_to]
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

  set fc_comps_len [llength $file_comps]
  set rt_comps_len [llength $relative_to_comps]

  # compare each dir element of file_to_convert and relative_to, set the flag and
  # get the final index till these sub-dirs matched. Break if limit reaches.
  while { [lindex $file_comps $index] == [lindex $relative_to_comps $index] } {
    if { !$found_match } { set found_match true }
    incr index
    if { ($index == $fc_comps_len) || ($index == $rt_comps_len) } {
      break;
    }
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

proc is_ip_fileset { fileset } {
  # Summary: Find IP's if any from the specified fileset and return true if 'generate_synth_checkpoint' is set to 1
  # Argument Usage:
  # fileset: fileset name
  # Return Value:
  # true (1) if success, false (0) otherwise

  # make sure fileset is block fileset type
  if { {BlockSrcs} != [get_property fileset_type [get_filesets $fileset]] } {
    return false
  }

  set ip_filter "FILE_TYPE == \"IP\" || FILE_TYPE==\"Block Designs\""
  set ips [get_files -all -quiet -of_objects [get_filesets $fileset] -filter $ip_filter]
  set b_found false
  foreach ip $ips {
    if { [get_property generate_synth_checkpoint [lindex [get_files -all $ip] 0]] } {
      set b_found true
      break
    }
  }

  if { $b_found } {
    return true
  }
  return false
}

proc is_proxy_ip_fileset { fileset } {
  # Summary: Determine if the fileset is an OOC run for a proxy IP that has a parent composite
  # Argument Usage:
  # fileset: fileset name
  # Return Value:
  # true (1) if the fileset contains an IP at its root with a parent composite, false (0) otherwise

  # make sure fileset is block fileset type
  if { {BlockSrcs} != [get_property fileset_type [get_filesets $fileset]] } {
    return false
  }

  set ip_with_parent_filter "FILE_TYPE == IP && PARENT_COMPOSITE_FILE != \"\""
  if {[llength [get_files -norecurse -quiet -of_objects [get_filesets $fileset] -filter $ip_with_parent_filter]] == 1} {
    return true
  }

  return false
}


proc is_ip_run { run } {
  # Summary: Find IP's if any from the fileset linked with the block fileset run
  # Argument Usage:
  # run: run name
  # Return Value:
  # true (1) if success, false (0) otherwise
  
  set fileset [get_property srcset [get_runs $run]]
  return [is_ip_fileset $fileset]
}
}
