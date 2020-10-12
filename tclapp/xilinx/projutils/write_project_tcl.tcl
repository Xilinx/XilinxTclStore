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
  # Summary: Export Tcl script for re-creating the current project

  # Argument Usage: 
  # [-paths_relative_to <arg> = Script output directory path]: Override the reference directory variable for source file relative paths
  # [-origin_dir_override <arg>]: Set 'origin_dir' directory variable to the specified value (Default is value specified with the -paths_relative_to switch)
  # [-target_proj_dir <arg> = Current project directory path]: Directory where the project needs to be restored
  # [-force]: Overwrite existing tcl script file
  # [-all_properties]: Write all properties (default & non-default) for the project object(s)
  # [-no_copy_sources]: Do not import sources even if they were local in the original project
  # [-no_ip_version]: Flag to not include the IP version as part of the IP VLNV in create_bd_cell commands.
  # [-absolute_path]: Make all file paths absolute wrt the original project directory
  # [-dump_project_info]: Write object values
  # [-use_bd_files ]: Use BD sources directly instead of writing out procs to create them
  # [-internal]: Print basic header information in the generated tcl script
  # [-validate]: Runs a validate script before recreating the project. To test if the files and paths refrenced in the tcl file exists or not.
  # [-quiet]: Execute the command quietly, returning no messages from the command.
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
      "-paths_relative_to" { 
        incr i;
        if { [regexp {^-} [lindex $args $i]] } {
          send_msg_id Vivado-projutils-021 ERROR "Missing value for the $option option.\
            Please provide a valid path/directory name immediately following '$option'"
          return
        }
        set a_global_vars(s_relative_to) [file normalize [lindex $args $i]] 
      }
      "-target_proj_dir" { 
        incr i;
        if { [regexp {^-} [lindex $args $i]] } {
          send_msg_id Vivado-projutils-021 ERROR "Missing value for the $option option.\
            Please provide a valid path/directory name immediately following '$option'"
          return
        }
        set a_global_vars(s_target_proj_dir) [lindex $args $i] 
      }
      "-origin_dir_override"  { incr i;set a_global_vars(s_origin_dir_override) [lindex $args $i] }
      "-force"                { set a_global_vars(b_arg_force) 1 }
      "-all_properties"       { set a_global_vars(b_arg_all_props) 1 }
      "-no_copy_sources"      { set a_global_vars(b_arg_no_copy_srcs) 1 }
      "-no_ip_version"        { set a_global_vars(b_arg_no_ip_version) 1 }
      "-absolute_path"        { set a_global_vars(b_absolute_path) 1 }
      "-dump_project_info"    { set a_global_vars(b_arg_dump_proj_info) 1 }
      "-use_bd_files"         { set a_global_vars(b_arg_use_bd_files) 1 }
      "-internal"             { set a_global_vars(b_internal) 1 }
      "-validate"             { set a_global_vars(b_validate) 1 }
      "-quiet"                { set a_global_vars(b_arg_quiet) 1}
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

  #read properties to exclude
  read_props_to_exclude

  # suppress all messages if -quiet flag is provided
  if { $a_global_vars(b_arg_quiet) } {
    suppress_messages
  }
 
  # script file is a must
  if { [lsearch {"" ".tcl"} [file tail $a_global_vars(script_file)]] != -1 } {
    if { $a_global_vars(b_arg_quiet) } {
      reset_msg_setting
    }
    send_msg_id Vivado-projutils-002 ERROR "Missing value for option 'file', please type 'write_project_tcl -help' for usage info.\n"
    return
  }
        
  # should not be a directory
  if { [file isdirectory $a_global_vars(script_file)] } {
    if { $a_global_vars(b_arg_quiet) } {
      reset_msg_setting
    }
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
    if { $a_global_vars(b_arg_quiet) } {
      reset_msg_setting
    }
    send_msg_id Vivado-projutils-013 ERROR "Directory in which file ${script_filename} is to be written does not exist \[$a_global_vars(script_file)\]\n"
    return
  }
    
  # recommend -force if file exists
  if { [file exists $a_global_vars(script_file)] && !$a_global_vars(b_arg_force) } {
    if { $a_global_vars(b_arg_quiet) } {
      reset_msg_setting
    }
    send_msg_id Vivado-projutils-004 ERROR "Tcl Script '$a_global_vars(script_file)' already exist. Use -force option to overwrite.\n"
    return
  }
 
  if { [get_files -quiet *.bd] eq "" } { set a_global_vars(b_arg_use_bd_files) 1 }
 
  # -no_copy_sources cannot be used without -use_bd_files
  if { $a_global_vars(b_arg_no_copy_srcs) && !$a_global_vars(b_arg_use_bd_files) } {
    if { $a_global_vars(b_arg_quiet) } {
      reset_msg_setting
    }
    send_msg_id Vivado-projutils-019 ERROR "This design contains BD sources. The option -no_copy_sources cannot be used without -use_bd_files.\
      Please remove -no_copy_sources if you wish to write out BD's as procs in the project tcl, otherwise add the option -use_bd_files to directly\
      include the *.bd files to the new project \n"
    return
  }

  # set script file directory path
  set a_global_vars(s_path_to_script_dir) [file normalize $file_path]
  
  # now write
  if {[write_project_tcl_script]} {
    if { $a_global_vars(b_arg_quiet) } {
      reset_msg_setting
    }
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
variable l_bd_wrapper [list]
variable l_validate_repo_paths [list]
variable l_bc_filesets  [list]
variable b_project_board_set 0

# set file types to filter
variable l_filetype_filter [list]
    
# Setup filter for non-user-settable filetypes
set l_filetype_filter [list "ip" "ipx" "embedded design sources" "elf" "coefficient files" "configuration files" \
                            "block diagrams" "block designs" "dsp design sources" "text" \
                            "design checkpoint" "waveform configuration file" "csv"]
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
  {{Utils}    {utilset}}
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
  set a_global_vars(s_origin_dir_override) "" 
  set a_global_vars(s_target_proj_dir)    ""
  set a_global_vars(b_arg_force)          0
  set a_global_vars(b_arg_no_copy_srcs)   0
  set a_global_vars(b_arg_no_ip_version)  0
  set a_global_vars(b_absolute_path)      0
  set a_global_vars(b_internal)           0
  set a_global_vars(b_validate)           0
  set a_global_vars(b_arg_all_props)      0
  set a_global_vars(b_arg_dump_proj_info) 0
  set a_global_vars(b_local_sources)      0
  set a_global_vars(curr_time)            [clock format [clock seconds]]
  set a_global_vars(fh)                   0
  set a_global_vars(dp_fh)                0
  set a_global_vars(def_val_fh)           0
  set a_global_vars(script_file)          ""
  set a_global_vars(b_arg_quiet)          0
  
  if { [get_param project.enableMergedProjTcl] } {
    set a_global_vars(b_arg_use_bd_files)   0
  } else {
    set a_global_vars(b_arg_use_bd_files) 1
  }

  set a_global_vars(excludePropDict)      [dict create]

  set l_script_data                       [list]
  set l_local_files                       [list]
  set l_remote_files                      [list]
  set l_bd_wrapper                        [list]
  set l_validate_repo_paths               [list]
  set l_bc_filesets                       [list]
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
  variable temp_dir
  variable temp_offset 1
  variable clean_temp
  variable l_open_bds [list]
  variable l_added_bds
  variable a_os
  variable l_bc_filesets
  variable l_validate_repo_paths

  set l_script_data [list]
  set l_local_files [list]
  set l_remote_files [list]
  set l_bc_filesets  [list]
  set l_open_bds [list]
  set l_added_bds [list]
  set l_validate_repo_paths [list]
  
  # Create temp directory (if required) for BD procs
  set temp_dir [ file join [file dirname $a_global_vars(script_file)] .Xiltemp ]  
  set clean_temp 1
  if { [file isdirectory $temp_dir] || $a_global_vars(b_arg_use_bd_files) } {
    set clean_temp 0
  } else {
    file mkdir $temp_dir
  }

  # Get OS
  if { [is_win_os] } {
    set a_os "win"
  } else {
    set a_os ""
  }

  # get the project name
  set tcl_obj [current_project]
  set proj_name [file tail [get_property name $tcl_obj]]
  set proj_dir [get_property directory $tcl_obj]
  set part_name [get_property part $tcl_obj]

  # output file script handle
  set file $a_global_vars(script_file)
  if {[catch {open $file w} a_global_vars(fh)]} {
    if { $a_global_vars(b_arg_quiet) } {
      reset_msg_setting
    }
    send_msg_id Vivado-projutils-005 ERROR "failed to open file for write ($file)\n"
    return 1
  }

  # dump project in canonical form
  if { $a_global_vars(b_arg_dump_proj_info) } {
    set dump_file [file normalize [file join $a_global_vars(s_path_to_script_dir) ${proj_name}_dump.txt]]
    if {[catch {open $dump_file w} a_global_vars(dp_fh)]} {
      if { $a_global_vars(b_arg_quiet) } {
        reset_msg_setting
      }
      send_msg_id Vivado-projutils-006 ERROR "failed to open file for write ($dump_file)\n"
      return 1
    }

    # default value output file script handle
    set def_val_file [file normalize [file join $a_global_vars(s_path_to_script_dir) ${proj_name}_def_val.txt]]
    if {[catch {open $def_val_file w} a_global_vars(def_val_fh)]} {
      if { $a_global_vars(b_arg_quiet) } {
        reset_msg_setting
      }
      send_msg_id Vivado-projutils-007 ERROR "failed to open file for write ($file)\n"
      return 1
    }
  }

  # explicitly update the compile order for current source/simset, if following conditions are met
  if { {All} == [get_property source_mgmt_mode [current_project]] &&
       {0}   == [get_property is_readonly [current_project]] &&
       {RTL} == [get_property design_mode [current_fileset]] } {


    # re-parse source fileset compile order for the current top
    if {[llength [get_files -quiet -compile_order sources -used_in synthesis]] > 1} {
      update_compile_order -fileset [current_fileset] -quiet
    }

    # re-parse simlulation fileset compile order for the current top
    if {[llength [get_files -quiet -compile_order sources -used_in simulation]] > 1} {
      update_compile_order -fileset [current_fileset -simset] -quiet
    }
  }

  # writer helpers
  wr_create_project $proj_dir $proj_name $part_name
  wr_project_properties $proj_dir $proj_name
  wr_filesets $proj_dir $proj_name
  wr_prflow $proj_dir $proj_name
  if { !$a_global_vars(b_arg_use_bd_files) } {
    wr_bd
    wr_bd_bc_specific
  }

  # write BC and RM filesets to handle extra files(ELF, XDC) added
  if { [llength $l_bc_filesets] > 0 } {
    write_specified_fileset $proj_dir $proj_name $l_bc_filesets 0
  }
  wr_bc_managed_rm_files $proj_dir $proj_name

  wr_prConf $proj_dir $proj_name 
  wr_runs $proj_dir $proj_name
  wr_proj_info $proj_name

  #write dashboards
  wr_dashboards $proj_dir $proj_name 
  # write header
  write_header $proj_dir $proj_name $file
  
  # write validate script
  set l_validate_script [wr_validate_files]
  foreach line $l_validate_script {
    puts $a_global_vars(fh) $line
  }
  
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
  if { !$a_global_vars(b_arg_quiet) } {
  send_msg_id Vivado-projutils-008 INFO "Tcl script '$script_filename' generated in output directory '$out_dir'\n\n"

  if { $a_global_vars(b_absolute_path) } {
    send_msg_id Vivado-projutils-016 INFO "Please note that the -absolute_path switch was specified, hence the project source files will be referenced using\n\
    absolute path only, in the generated script. As such, the generated script will only work in the same filesystem where those absolute paths are accessible."
  } else {
    if { "." != $a_global_vars(s_relative_to) } {
      if { {} == $a_global_vars(s_origin_dir_override) } {
        send_msg_id Vivado-projutils-017 INFO "Please note that the -paths_relative_to switch was specified, hence the project source files will be referenced\n\
        wrt the path that was specified with this switch. The 'origin_dir' variable is set to this path in the generated script."
      } else {
        send_msg_id Vivado-projutils-017 INFO "Please note that the -paths_relative_to switch was specified, hence the project source files will be referenced wrt the\n\
        path that was specified with this switch. The 'origin_dir' variable is set to '$a_global_vars(s_origin_dir_override)' in the generated script."
      }
    } else {
      send_msg_id Vivado-projutils-015 INFO "Please note that by default, the file path for the project source files were set wth respect to the 'origin_dir' variable in the\n\
      generated script. When this script is executed from the output directory, these source files will be referenced with respect to this 'origin_dir' path value.\n\
      In case this script was later moved to a different directory, the 'origin_dir' value must be set manually in the script with the path\n\
      relative to the new output directory to make sure that the source files are referenced correctly from the original project. You can also set the\n\
      'origin_dir' automatically by setting the 'origin_dir_loc' variable in the tcl shell before sourcing this generated script. The 'origin_dir_loc'\n\
      variable should be set to the path relative to the new output directory. Alternatively, if you are sourcing the script from the Vivado command line,\n\
      then set the origin dir using '-tclargs --origin_dir <path>'. For example, 'vivado -mode tcl -source $script_filename -tclargs --origin_dir \"..\"\n"
    }
  }
  }

  if { !$a_global_vars(b_arg_quiet) } {
  if { $a_global_vars(b_local_sources) } {
    print_local_file_msg "warning"
  } else {
    print_local_file_msg "info"
  }
  }

  if { $a_global_vars(b_arg_quiet) } {
    reset_msg_setting
  }
  reset_global_vars

  return 0
}

proc wr_validate_files {} {
  variable a_global_vars
  set l_script_validate [list]
  variable l_validate_repo_paths

  variable l_local_files 
  variable l_remote_files 
  
  lappend l_script_validate "# Check file required for this script exists"
  lappend l_script_validate "proc checkRequiredFiles \{ origin_dir\} \{"
  lappend l_script_validate "  set status true" 
  if {[llength $l_local_files]>0} {
  
    lappend l_script_validate "  set files \[list \\"
    foreach file $l_local_files {
      lappend l_script_validate "   $file \\"
    }
    lappend l_script_validate "  \]"
    
    lappend l_script_validate "  foreach ifile \$files \{"
    lappend l_script_validate "    if \{ !\[file isfile \$ifile\] \} \{"
    lappend l_script_validate "      puts \" Could not find local file \$ifile \""
    lappend l_script_validate "      set status false" 
    lappend l_script_validate "    \}" 
    lappend l_script_validate "  \}"
    lappend l_script_validate ""
  }
  if {[llength $l_remote_files]>0} {
    lappend l_script_validate "  set files \[list \\"
    foreach file $l_remote_files {
      lappend l_script_validate "   $file \\"
    }
    lappend l_script_validate "  \]"
    
    lappend l_script_validate "  foreach ifile \$files \{"
    lappend l_script_validate "    if \{ !\[file isfile \$ifile\] \} \{"
    lappend l_script_validate "      puts \" Could not find remote file \$ifile \""
    lappend l_script_validate "      set status false" 
    lappend l_script_validate "    \}" 
    lappend l_script_validate "  \}"
    lappend l_script_validate ""
  }

  if {[llength $l_validate_repo_paths]>0} {
    lappend l_script_validate "  set paths \[list \\"
    foreach path $l_validate_repo_paths {
      lappend l_script_validate "   $path \\"
    }
    lappend l_script_validate "  \]"
    
    lappend l_script_validate "  foreach ipath \$paths \{"
    lappend l_script_validate "    if \{ !\[file isdirectory \$ipath\] \} \{"
    lappend l_script_validate "      puts \" Could not access \$ipath \""
    lappend l_script_validate "      set status false" 
    lappend l_script_validate "    \}" 
    lappend l_script_validate "  \}"
    lappend l_script_validate ""
  }
 
 
  lappend l_script_validate "  return \$status"
  lappend l_script_validate "\}"
  return $l_script_validate  
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
  set relative_to "$a_global_vars(s_relative_to)"
  if { {} != $a_global_vars(s_origin_dir_override) } {
    set relative_to "$a_global_vars(s_origin_dir_override)"
  }
  lappend l_script_data "set origin_dir \"$relative_to\""
  lappend l_script_data ""
  set var_name "origin_dir_loc"
  lappend l_script_data "# Use origin directory path location variable, if specified in the tcl shell"
  lappend l_script_data "if \{ \[info exists ::$var_name\] \} \{"
  lappend l_script_data "  set origin_dir \$::$var_name"
  lappend l_script_data "\}"

  lappend l_script_data "" 
  set var_name "user_project_name"
  lappend l_script_data "# Set the project name\nset _xil_proj_name_ \"$name\"\n"
  lappend l_script_data "# Use project name variable, if specified in the tcl shell"
  lappend l_script_data "if \{ \[info exists ::$var_name\] \} \{"
  lappend l_script_data "  set _xil_proj_name_ \$::$var_name"
  lappend l_script_data "\}\n"

  lappend l_script_data "variable script_file"
  lappend l_script_data "set script_file \"[file tail $a_global_vars(script_file)]\"\n"
  lappend l_script_data "# Help information for this script"
  lappend l_script_data "proc print_help \{\} \{"
  lappend l_script_data "  variable script_file"
  lappend l_script_data "  puts \"\\nDescription:\""
  lappend l_script_data "  puts \"Recreate a Vivado project from this script. The created project will be\""
  lappend l_script_data "  puts \"functionally equivalent to the original project for which this script was\""
  lappend l_script_data "  puts \"generated. The script contains commands for creating a project, filesets,\""
  lappend l_script_data "  puts \"runs, adding/importing sources and setting properties on various objects.\\n\""
  lappend l_script_data "  puts \"Syntax:\""
  lappend l_script_data "  puts \"\$script_file\""
  lappend l_script_data "  puts \"\$script_file -tclargs \\\[--origin_dir <path>\\\]\""
  lappend l_script_data "  puts \"\$script_file -tclargs \\\[--project_name <name>\\\]\""
  lappend l_script_data "  puts \"\$script_file -tclargs \\\[--help\\\]\\n\""
  lappend l_script_data "  puts \"Usage:\""
  lappend l_script_data "  puts \"Name                   Description\""
  lappend l_script_data "  puts \"-------------------------------------------------------------------------\""
  if { {} == $a_global_vars(s_origin_dir_override) } {
    lappend l_script_data "  puts \"\\\[--origin_dir <path>\\\]  Determine source file paths wrt this path. Default\""
    lappend l_script_data "  puts \"                       origin_dir path value is \\\".\\\", otherwise, the value\""
    lappend l_script_data "  puts \"                       that was set with the \\\"-paths_relative_to\\\" switch\""
    lappend l_script_data "  puts \"                       when this script was generated.\\n\""
  } else {
    lappend l_script_data "  puts \"\\\[--origin_dir <path>\\\]  Determine source file paths wrt this path. Default\""
    lappend l_script_data "  puts \"                       origin_dir path value is \\\".\\\", otherwise, the value\""
    lappend l_script_data "  puts \"                       that was set with the \\\"-origin_dir_override\\\" switch\""
    lappend l_script_data "  puts \"                       when this script was generated.\\n\""
  }
  lappend l_script_data "  puts \"\\\[--project_name <name>\\\] Create project with the specified name. Default\""
  lappend l_script_data "  puts \"                       name is the name of the project from where this\""
  lappend l_script_data "  puts \"                       script was generated.\\n\""
  lappend l_script_data "  puts \"\\\[--help\\\]               Print help information for this script\""
  lappend l_script_data "  puts \"-------------------------------------------------------------------------\\n\""
  lappend l_script_data "  exit 0"
  lappend l_script_data "\}\n"
  lappend l_script_data "if \{ \$::argc > 0 \} \{"
  lappend l_script_data "  for \{set i 0\} \{\$i < \$::argc\} \{incr i\} \{"
  lappend l_script_data "    set option \[string trim \[lindex \$::argv \$i\]\]"
  lappend l_script_data "    switch -regexp -- \$option \{"
  lappend l_script_data "      \"--origin_dir\"   \{ incr i; set origin_dir \[lindex \$::argv \$i\] \}"
  lappend l_script_data "      \"--project_name\" \{ incr i; set _xil_proj_name_ \[lindex \$::argv \$i\] \}"
  lappend l_script_data "      \"--help\"         \{ print_help \}"
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
  if { $a_global_vars(b_absolute_path) || [need_abs_path $proj_dir] } {
    lappend l_script_data "set orig_proj_dir \"$proj_dir\""
  } else {
    set rel_file_path "[get_relative_file_path_for_source $proj_dir [get_script_execution_dir]]"
    set path "\[file normalize \"\$origin_dir/$rel_file_path\"\]"
    lappend l_script_data "set orig_proj_dir \"$path\""
  }
  lappend l_script_data ""
  
  # Validate 
  
  lappend l_script_data "# Check for paths and files needed for project creation" 
  lappend l_script_data "set validate_required $a_global_vars(b_validate)" 
  lappend l_script_data "if \{ \$validate_required \} \{"
  lappend l_script_data "  if \{ \[checkRequiredFiles \$origin_dir\] \} \{"  
  lappend l_script_data "    puts \"Tcl file \$script_file is valid. All files required for project creation is accesable. \""
  lappend l_script_data "  \} else \{"
  lappend l_script_data "    puts \"Tcl file \$script_file is not valid. Not all files required for project creation is accesable. \""
  lappend l_script_data "    return"
  lappend l_script_data "  \}"
  lappend l_script_data "\}"  
  lappend l_script_data ""
  
  # create project
  lappend l_script_data "# Create project"
    
  set tcl_cmd ""
  # set target project directory path if specified. If not, create project dir in current dir.
  set target_dir $a_global_vars(s_target_proj_dir)
  if { {} == $target_dir } {
    set tcl_cmd "create_project \$\{_xil_proj_name_\} ./\$\{_xil_proj_name_\} -part $part_name"
  } else {
    # is specified target proj dir == current dir? 
    set cwd [file normalize [string map {\\ /} [pwd]]]
    set dir [file normalize [string map {\\ /} $target_dir]]
    if { [string equal $cwd $dir] } {
      set tcl_cmd "create_project \$\{_xil_proj_name_\} -part $part_name"
    } else {
      set tcl_cmd "create_project \$\{_xil_proj_name_\} \"$target_dir\" -part $part_name"
    }
  }
      
  if { [get_property managed_ip [current_project]] } {
    set tcl_cmd "$tcl_cmd -ip"
  }
  lappend l_script_data $tcl_cmd

  if { $a_global_vars(b_arg_dump_proj_info) } {
    puts $a_global_vars(dp_fh) "project_name=\$\{_xil_proj_name_\}"
  }

  lappend l_script_data ""
  lappend l_script_data "# Set the directory path for the new project"
  lappend l_script_data "set proj_dir \[get_property directory \[current_project\]\]"

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
  lappend l_script_data "set obj \[current_project\]"

  # is project "board_part" set already?
  if { [string length [get_property "board_part" $tcl_obj]] > 0 } {
    set b_project_board_set 1
  }

  write_props $proj_dir $proj_name $get_what $tcl_obj "project"
}

proc write_bd_as_proc { bd_file } {
  # Summary: writes out BD creation steps as a proc
  # Argument: BD file
  # Return Value: None

  variable a_global_vars
  variable l_added_bds
  variable l_bd_proc_calls
  variable l_script_data
  variable temp_offset
  variable l_open_bds
  variable temp_dir
  variable bd_prop_steps
  set bd_file [list "$bd_file"]

  if { [lsearch $l_added_bds $bd_file] != -1 } { return }
  
  set to_close 1
  
  # Add sources referenced in the BD
  add_references $bd_file


  # Open BD in stealth mode, if not already open
  set bd_filename [file tail $bd_file]
  if { [lsearch $l_open_bds $bd_filename] != -1 } {
    set to_close 0
  } else {
    open_bd_design -stealth [ get_files $bd_file ]
  }
  current_bd_design [get_bd_designs [file rootname $bd_filename]]
  
  # write the BD as a proc to a temp file
  while { [file exists [file join $temp_dir "temp_$temp_offset.tcl"]] } {
    incr temp_offset
  } 
  set temp_bd_file [file join $temp_dir "temp_$temp_offset.tcl"]
  if { $a_global_vars(b_arg_no_ip_version) } {
    write_bd_tcl -no_project_wrapper -no_ip_version -make_local -include_layout $temp_bd_file
  } else {
    write_bd_tcl -no_project_wrapper -make_local -include_layout $temp_bd_file
  }
  
  # Set non default properties for the BD
  wr_bd_properties $bd_file
  
  # Close BD if opened in stealth mode
  if {$to_close == 1 } {
     close_bd_design [get_bd_designs [file rootname $bd_filename]]
  }

  # Get proc call
  if {[catch {open $temp_bd_file r} fp]} {
    if { $a_global_vars(b_arg_quiet) } {
      reset_msg_setting
    }
    send_msg_id Vivado-projutils-020 ERROR "failed to write out proc for $bd_file \n"
    return 1
  }
  # TODO no need to read whole file, just second line will do
  set file_data [read $fp ]
  set split_proc [split $file_data]
  set proc_index 7
  set str [lindex $split_proc $proc_index] 
  close $fp
  
  # Add the BD proc, call to the proc and BD property steps
  if { [string equal [lindex $split_proc [expr {$proc_index-1}] ] "proc"]
        && [regexp {^cr_bd_.*} $str]
  } then {
    append str " \"\""
    lappend l_script_data "\n"
    lappend l_script_data $file_data
    lappend l_added_bds $bd_file
    lappend l_script_data $str
    lappend l_script_data $bd_prop_steps
  }

  # delete temp file
  file delete $temp_bd_file
  incr temp_offset
}

proc wr_bd_properties { file } {
  # Summary: writes non default BD properties
  # Argument: the .BD file
  # Return Value: none
  variable bd_prop_steps
  variable a_global_vars

  set bd_prop_steps ""
  set bd_name [get_property FILE_NAME [current_bd_design]]
  set bd_props [list_property [ get_files $file ] ]
  set read_only_props [rdi::get_attr_specs -object [get_files $file] -filter {is_readonly}]

  foreach prop $bd_props {
     if { [lsearch $read_only_props $prop] != -1 
           || [string equal -nocase $prop "file_type" ]
     } then { continue }
    set def_val [list_property_value -default $prop [ get_files $file ] ]
    set cur_val [get_property $prop [get_files $file ] ]

    set def_val \"$def_val\"
    set cur_val \"$cur_val\"

    if { $a_global_vars(b_arg_all_props) } {
      append bd_prop_steps "set_property $prop $cur_val \[get_files $bd_name \] \n"
    } else {
    if { $def_val ne $cur_val } {
      append bd_prop_steps "set_property $prop $cur_val \[get_files $bd_name \] \n"
    }
  }
 }
}

proc add_references { sub_design } {
  # Summary: Looks for sources referenced in the block design and adds them
  # Argument: sub_design file
  # Return Value: None

  variable l_script_data
  variable l_added_bds

  # Getting references, if any

  set refs [ get_files -quiet -references -of_objects [ get_files $sub_design ] ]
  foreach file $refs {
    if { [file extension $file ] ==".bd" } {
      if { [lsearch $l_added_bds $file] != -1 } { continue }

      # Write out referred bd as a proc
      write_bd_as_proc $file
    } else {
      # Skip adding file if it's already part of the project
      lappend l_script_data "if { \[get_files [file tail $file]\] == \"\" } {"
      lappend l_script_data "  import_files -quiet -fileset [current_fileset -srcset] $file\n}"
    }
  }  
}

proc wr_bd {} {
  # Summary: write procs to create BD's
  # Return Value: None
  
  variable a_global_vars
  variable l_script_data
  variable l_added_bds 
  variable l_bd_proc_calls 
  variable l_open_bds [list]
  variable temp_dir
  variable clean_temp


  # String that will hold commands to set BD properties
  variable bd_prop_steps "\n# Setting BD properties \n"

  # Get already opened BD designs
  set open_bd_names [get_bd_designs]
  foreach bd_name $open_bd_names {
    lappend l_open_bds [get_property FILE_NAME [get_bd_designs $bd_name]]
  }

  # Get all BD files in the design
  set bd_files [get_files -norecurse *.bd -filter "IS_BLOCK_CONTAINER_MANAGED == 0"]
  lappend l_script_data "\n# Adding sources referenced in BDs, if not already added"


  foreach bd_file $bd_files {
    # Making sure BD is not locked
    set is_locked [get_property IS_LOCKED [get_files [list "$bd_file"] ] ]
    if { $is_locked == 1 } {
      file delete $a_global_vars(script_file)
      if { $a_global_vars(b_arg_quiet) } {
        reset_msg_setting
      }
      send_msg_id Vivado-projutils-018 ERROR "Project tcl cannot be written as the design contains one or more \
      locked/out-of-date design(s). Please run report_ip_status and update the design.\n"
      return 1
    }

    # Write out bd as a proc
    write_bd_as_proc $bd_file
  }


  # Delete temp directory
  if { $clean_temp == 1} {
    file delete -force $temp_dir
  }
  
  wr_bd_wrapper
}

proc wr_bd_bc_specific {} {
  # Summary: write generate_target for the top level BD that contains Block Containers 
  # Return Value: None

  variable l_bc_filesets
  variable l_script_data

  set bd_files [get_files -norecurse *.bd -filter "IS_BLOCK_CONTAINER_MANAGED == 0"]
  set bc_filesets_size [llength $l_bc_filesets]

  foreach bd_file $bd_files {
    set refs [ get_files -quiet -references -of_objects [ get_files $bd_file ] ]
    # If BD has references and project has BC filesets, then 
    # we are assuming it as it is top level BD with BCs
    # TODO - Need to check whether this assumption works for all cases
    set delivered_targets [lsearch [get_property delivered_targets [get_files $bd_file] ] Synthesis]
    set stale_targets [lsearch [get_property stale_targets [get_files $bd_file] ] Synthesis]
    set is_generated [expr {$delivered_targets != -1 && $stale_targets == -1}]
    if { [llength $refs] != 0 && $is_generated == 1 && $bc_filesets_size != 0} { 
      set filename [file tail $bd_file]
      lappend l_script_data "generate_target all \[get_files $filename\]\n"
    }
  }
}

proc wr_bd_wrapper {} {

  variable l_script_data
  variable l_bd_wrapper
  
  if {[llength $l_bd_wrapper]>0} { 	
    lappend l_script_data "#call make_wrapper to create wrapper files"
    foreach fileset_designame_wrappername $l_bd_wrapper {
      set fs_name [lindex $fileset_designame_wrappername 0]
      set design [lindex $fileset_designame_wrappername 1]
      set wrapper_name [lindex $fileset_designame_wrappername 2]
      
      lappend l_script_data "if \{ \[get_property IS_LOCKED \[ get_files -norecurse $design.bd\] \] == 1  \} \{"
      lappend l_script_data "  import_files -fileset $fs_name $wrapper_name"
      lappend l_script_data "\} else \{"	  
      lappend l_script_data "  set wrapper_path \[make_wrapper -fileset $fs_name -files \[ get_files -norecurse $design.bd] -top\]"
      lappend l_script_data "  add_files -norecurse -fileset $fs_name \$wrapper_path"
      lappend l_script_data "\}"
      lappend l_script_data ""
    }
    lappend l_script_data ""
  }
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
    write_specified_fileset $proj_dir $proj_name $filesets 1
  }
}

proc write_specified_fileset { proj_dir proj_name filesets ignore_bc } {
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
  variable l_bc_filesets
  variable l_validate_repo_paths

  # write filesets
  set type "file"
  foreach tcl_obj $filesets {

    # Is this a IP block fileset for a proxy IP that is owned by another composite file?
    # If so, we don't want to write it out as an independent file. The parent will take care of it.
    if { [is_proxy_ip_fileset $tcl_obj] } {
      continue
    }

    # Is this a Block Container managed block fileset?
    # If so, we don't need to create block fileset, it will be auto created
    if { $ignore_bc == 1 && [is_bc_managed_fileset $tcl_obj] == true } {
      lappend l_bc_filesets $tcl_obj
      continue
    }

    set fs_type [get_property fileset_type [get_filesets $tcl_obj]]

    # is this a IP block fileset? if yes, do not create block fileset, but create for a pure HDL based fileset (no IP's)
    if { [is_ip_fileset $tcl_obj] || [is_bc_managed_fileset $tcl_obj] } {
      # do not create block fileset
    } elseif { [string equal $tcl_obj "utils_1"] } {
      # do not create utils fileset
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
      # If BlockSet contains only one IP, then this indicates the case of OOC1
      # This means that we should not write these properties, they are read-only
      set blockset_is_ooc1 false
      if { {BlockSrcs} == $fs_type } {
        set current_fs_files [get_files -quiet -of_objects [get_filesets $tcl_obj] -norecurse]
        if { [llength $current_fs_files] == 1 } {
          set only_file_in_fs [lindex $current_fs_files 0]
          set file_type [get_property FILE_TYPE $only_file_in_fs]
          set blockset_is_ooc1 [expr {$file_type == {IP}} ? true : false]
        }
      }
      if { $blockset_is_ooc1} {
        # We do not write properties for OOC1 
      } elseif { ({RTL} == [get_property design_mode [get_filesets $tcl_obj]]) } {
        set repo_paths [get_ip_repo_paths $tcl_obj]
        if { [llength $repo_paths] > 0 } {
          lappend l_script_data "# Set IP repository paths"
          lappend l_script_data "set obj \[get_filesets $tcl_obj\]"
          set path_list [list]
          foreach path $repo_paths {
            if { $a_global_vars(b_absolute_path) || [need_abs_path $path] } {
              lappend path_list $path
              if { [lsearch $l_validate_repo_paths $path] == -1 } {
                 lappend l_validate_repo_paths $path
              }
            } else {
              set rel_file_path "[get_relative_file_path_for_source $path [get_script_execution_dir]]"
              set path "\[file normalize \"\$origin_dir/$rel_file_path\"\]"
              lappend path_list $path
              if { [lsearch $l_validate_repo_paths $path] == -1 } {
                lappend l_validate_repo_paths $path
              }
            }
          }
          set repo_path_str [join $path_list " "]
          lappend l_script_data "if \{ \$obj != \{\} \} \{"
          lappend l_script_data "   set_property \"ip_repo_paths\" \"${repo_path_str}\" \$obj" 
          lappend l_script_data "" 
          lappend l_script_data "   # Rebuild user ip_repo's index before adding any source files"
          lappend l_script_data "   update_ip_catalog -rebuild"
          lappend l_script_data "\}"
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

  lappend l_script_data "\nputs \"INFO: Project created:\${_xil_proj_name_}\""
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
  puts $a_global_vars(fh) "#*****************************************************************************************"
  puts $a_global_vars(fh) "# $product (TM) $version_id"
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
  if { !$a_global_vars(b_internal) } {
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
  }
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

  # filter sim_types
  if { ([string equal -nocase $prop {allowed_sim_models}]) } {
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

  # Remove quotes for proper normalize output
  set file [string trim $file "\""]
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

proc write_properties { prop_info_list get_what tcl_obj {delim "#"} } {
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
      set elem [split $x $delim] 
      set name [lindex $elem 0]
      set value [lindex $elem 1]
      if { ([is_ip_readonly_prop $name]) && ([string equal $get_what "get_files"]) } {
        set cmd_str "if \{ !\[get_property \"is_locked\" \$file_obj\] \} \{"
        lappend l_script_data "$cmd_str"
        set cmd_str "  set_property -name \"$name\" -value \"$value\" -objects"
        set b_add_closing_brace 1
      } else {
        set cmd_str "set_property -name \"$name\" -value \"$value\" -objects"
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
          if { ! $a_global_vars(b_arg_all_props) && !$a_global_vars(b_arg_quiet) } {
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

proc align_project_properties { prop proj_name proj_file_path } {
  # Summary:
  # Argument Usage: 
  # Return Value:

  variable a_global_vars

  set dir_suffix {}
  if { {} == $prop } {
    return $proj_file_path
  }

  # align project properties to have project name variable
  if {[string equal -nocase $prop "ip_output_repo"] ||
      [string equal -nocase $prop "sim.ipstatic.compiled_library_dir"] } {
    set dir_suffix "cache"
  } else {
  if {[string equal -nocase $prop "sim.central_dir"]   ||
      [string equal -nocase $prop "ip.user_files_dir"] ||
      [string equal -nocase $prop "sim.ipstatic.source_dir"] } {
    set dir_suffix "ip_user_files"
  }}

  # skip other properties
  if { {} == $dir_suffix } {
    return $proj_file_path
  }

  set match_str "${proj_name}/${proj_name}.${dir_suffix}"
  set proj_file_path [string map {\\ /} $proj_file_path]
  if { [regexp $match_str $proj_file_path] } {
    set proj_file_path [regsub -all "${proj_name}" $proj_file_path "\$\{_xil_proj_name_\}"]
  } else {
    set match_str "${proj_name}.${dir_suffix}"
    set proj_file_path [regsub "${proj_name}\.${dir_suffix}" $proj_file_path "\$\{_xil_proj_name_\}\.${dir_suffix}"]
  }
  return $proj_file_path
}

proc write_props { proj_dir proj_name get_what tcl_obj type {delim "#"}} {
  # Summary: write first class object properties
  # This helper command is used to script help.
  # Argument Usage: 
  # Return Value:
  # none

  variable a_global_vars
  variable l_script_data
  variable b_project_board_set

  if {[string equal $type "project"]} {
    # escape empty spaces in project name
    set tcl_obj [ list "$tcl_obj"]
  }
  if { [string first " " $get_what 0] != -1 } {
    # For cases where get_what is multiple workds like "get_dashboard_gadgets -of_object..."
    set current_obj [ eval $get_what $tcl_obj]
  } else {
    set current_obj [$get_what $tcl_obj]
  }
  if { $current_obj == "" } { return }

  set obj_name [get_property name $current_obj]
  set read_only_props [rdi::get_attr_specs -class [get_property class $current_obj] -filter {is_readonly}]
  set prop_info_list [list]
  set properties [list_property $current_obj]
  
  #move board_part_repo_pats property before board_part CR:1072610
  set idx [lsearch $properties "BOARD_PART_REPO_PATHS"]
  if {$idx ne -1} {
    set properties [lreplace $properties $idx $idx]
    set properties [linsert $properties 0 "BOARD_PART_REPO_PATHS"]
  }
  

  foreach prop $properties {
    if { [is_deprecated_property $prop] } { continue }

    # is property excluded from being written into the script file
    if { [is_excluded_property $current_obj $prop] } { continue }

    # skip read-only properties
    if { [lsearch $read_only_props $prop] != -1 } { continue }
    if { ([string equal $type "gadget"]) && ([string equal -nocase $prop "type"]) } {
      continue
    }

    # To handle the work-around solution of CR-988588 set board_part to base_board_part value then set board_connections
    if { ([ string equal $type "project" ]) && ([ string equal [ string tolower $prop ] "board_connections" ]) } {
      continue
    }
    if { ([ string equal $type "project" ]) && $b_project_board_set && ([ string equal [ string tolower $prop ] "board_part" ]) } {
      set board_part_val [get_property $prop $current_obj]
      set base_board_part_val [get_property base_board_part $current_obj]
      set board_connections_val [get_property board_connections $current_obj]
      if { $base_board_part_val != "" && $base_board_part_val != $board_part_val } {
        set prop_entry "[string tolower $prop]$delim$base_board_part_val"
        lappend prop_info_list $prop_entry
        set prop_entry "board_connections$delim$board_connections_val"
        lappend prop_info_list $prop_entry
        continue
      }
    }

    # skip writing PR-Configuration, attached right after creation of impl run
    if { ([get_property pr_flow [current_project]] == 1) && [string equal $type "run"] } {
      set isImplRun [get_property is_implementation $current_obj]
      if { ($isImplRun == 1) && [string equal -nocase $prop "pr_configuration"] } {
        continue
      }
    }

    set prop_type "unknown"
    if { [string equal $type "run"] } {
      # skip steps.<step_name>.reports dynamic read only property (to be populated by creation of reports)
      if { [regexp -nocase "STEPS\..*\.REPORTS" $prop] || [string equal -nocase "REPORT_STRATEGY" $prop] } {
        continue;
      }
      if { [regexp "STEPS" $prop] } {
        # skip step properties
      } else {
        set attr_names [rdi::get_attr_specs -class [get_property class [get_runs $tcl_obj] ]]
        if { [lsearch $attr_names $prop] != -1 } {
          set prop_type [get_property type [lindex $attr_names [lsearch $attr_names $prop]]]
        }
      }
    } else {
      set attr_spec [rdi::get_attr_specs -quiet $prop -object $current_obj]
      if { {} == $attr_spec } {
        set prop_lower [string tolower $prop]
        set attr_spec [rdi::get_attr_specs -quiet $prop_lower -object $current_obj]
      }
      set prop_type [get_property type $attr_spec]
    }

    set def_val [list_property_value -default $prop $current_obj]
    set dump_prop_name [string tolower ${obj_name}_${type}_$prop]
    set cur_val [get_property $prop $current_obj]

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

    # do not set default_rm for partitionDef initially as RM is not created at time of creation of pdef
    if { [string equal $type "partitionDef"] && 
         [string equal -nocase $prop "default_rm"] } {
      continue
    }

    # re-align values
    set cur_val [get_target_bool_val $def_val $cur_val]
    set abs_proj_file_path [get_property $prop $current_obj]
    
    set path_match [string match $proj_dir* $abs_proj_file_path]
    if { ($path_match == 1) && ($a_global_vars(b_absolute_path) != 1) && ![need_abs_path $abs_proj_file_path] } {
      # changing the absolute path to relative
      set abs_path_length [string length $proj_dir]
      set proj_file_path [string replace $abs_proj_file_path 0 $abs_path_length "\$proj_dir/"]
      set proj_file_path [align_project_properties $prop $proj_name $proj_file_path]
      set prop_entry "[string tolower $prop]$delim$proj_file_path"
    } else {
      set abs_proj_file_path [align_project_properties $prop $proj_name $abs_proj_file_path]
      set prop_entry "[string tolower $prop]$delim$abs_proj_file_path"
    }  

    # handle the board_part_repo_paths property    
    if {[string equal -nocase $prop "board_part_repo_paths"]} {
     set board_repo_paths [list]  
     set board_repo_paths [get_property $prop $current_obj]
     if { [llength $board_repo_paths] > 0 } {
          set board_paths [list]
          foreach path $board_repo_paths {
            if { $a_global_vars(b_absolute_path) || [need_abs_path $path] } {
              lappend board_paths $path
            } else {
              lappend board_paths "\[file normalize \"\$origin_dir/[get_relative_file_path_for_source $path [get_script_execution_dir]]\"\]"
            }
          }
          set prop_entry "[string tolower $prop]$delim[join $board_paths " "]"
      }
    }

    # re-align include dir path wrt origin dir
    if { [string equal -nocase $prop "include_dirs"] } {
      if { [llength $abs_proj_file_path] > 0 } {
        if { !$a_global_vars(b_absolute_path) } {
          set incl_paths $abs_proj_file_path
          set rel_paths [list]
          foreach path $incl_paths {
            if { ![need_abs_path $path] } {
              lappend rel_paths "\[file normalize \"\$origin_dir/[get_relative_file_path_for_source $path [get_script_execution_dir]]\"\]"
            }
          }
          set prop_entry "[string tolower $prop]$delim[join $rel_paths " "]"
        }
      }
    }

    # fix paths wrt the original project dir
    if {([string equal -nocase $prop "top_file"]) && ($cur_val != "") } {
      set file $cur_val

      set srcs_dir "${proj_name}.srcs"
      set file_dirs [split [string trim [file normalize [string map {\\ /} $file]]] "/"]
      set src_file [join [lrange $file_dirs [lsearch -exact $file_dirs "$srcs_dir"] end] "/"]

      if { [is_local_to_project $file] || [need_abs_path $file]} {
        set proj_file_path "\$proj_dir/$src_file"
      } else {
        set proj_file_path "[get_relative_file_path_for_source $src_file [get_script_execution_dir]]"
      }
      set prop_entry "[string tolower $prop]$delim$proj_file_path"

    } elseif {([string equal -nocase $prop "target_constrs_file"] ||
               [string equal -nocase $prop "target_ucf"]) &&
               ($cur_val != "") } {
 
      set file $cur_val
      set fs_name $tcl_obj

      set path_dirs [split [string trim [file normalize [string map {\\ /} $file]]] "/"]
      set src_file [join [lrange $path_dirs [lsearch -exact $path_dirs "$fs_name"] end] "/"]
      set file_object [lindex [get_files -quiet -of_objects [get_filesets $fs_name] [list $file]] 0]
      set file_props [list_property $file_object]

      if { [lsearch $file_props "IMPORTED_FROM"] != -1 } {
        if { $a_global_vars(b_arg_no_copy_srcs) } {
          set proj_file_path "\$orig_proj_dir/${proj_name}.srcs/$src_file"
        } else {
          set proj_file_path "\$proj_dir/\$\{_xil_proj_name_\}.srcs/$src_file"
        }
      } else {
        # is file new inside project?
        if { [is_local_to_project $file] } {
          set path_dirs [split [string trim [file normalize [string map {\\ /} $file]]] "/"]
          set local_constrs_file [join [lrange $path_dirs end-1 end] "/"]
          set local_constrs_file [string trimleft $local_constrs_file "/"]
          set local_constrs_file [string trimleft $local_constrs_file "\\"]
          set file $local_constrs_file
          set proj_file_path "\[get_files *$local_constrs_file\]"
        } else {
          if { $a_global_vars(b_absolute_path) || [need_abs_path $file] } {
            set proj_file_path "$file"
          } else {
            set file_no_quotes [string trim $file "\""]
            set rel_file_path [get_relative_file_path_for_source $file_no_quotes [get_script_execution_dir]]
            set proj_file_path "\[file normalize \"\$origin_dir/$rel_file_path\"\]"
          }
        }
      }

      set prop_entry "[string tolower $prop]$delim$proj_file_path"
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
        set compile_lib_dir_path [regsub $cache_dir $compile_lib_dir_path "\$\{_xil_proj_name_\}\.cache"]
      }
      set prop_entry "[string tolower $prop]$delim$compile_lib_dir_path"
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
              if { $a_global_vars(b_absolute_path)|| [need_abs_path $file]  } {
                set tcl_file_path "$file"
              } else {
                set rel_file_path "[get_relative_file_path_for_source $src_file [get_script_execution_dir]]"
                set tcl_file_path "\[file normalize \"\$origin_dir/$rel_file_path\"\]"
              }
            }
            set prop_entry "[string tolower $prop]$delim$tcl_file_path"
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
  write_properties $prop_info_list $get_what $tcl_obj $delim

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

  if { [string equal $property "board"] ||
       [string equal $property "verilog_dir"] ||
       [string equal $property "compxlib.compiled_library_dir"] ||
       [string equal $property "runtime"] ||
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
       [string equal $property "xsim.tclbatch"] ||
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
       [string equal $property "modelsim.vcom_more_options"] ||
       [string equal $property "xsim.simulate.uut"] ||
       [string equal $property "modelsim.simulate.uut"] ||
       [string equal $property "questa.simulate.uut"] ||
       [string equal $property "ies.simulate.uut"] ||
       [string equal $property "vcs.simulate.uut"] ||
       [string equal $property "platform.xocc_link_xp_switches_default"] ||
       [string equal $property "platform.xocc_compile_xp_switches_default"] ||
       [string equal $property "dsa"] ||
       [regexp {dsa\..*} $property ] } {
     return true
  }
  return false
}

proc read_props_to_exclude {} {
  # Summary: read properties that need to be excluded from writing into the script file generated by write_project_tcl command.
  # Argument Usage: 
  # Return Value:
  # none
  variable a_global_vars

  set objPropList [get_param project.wpt.excludeProperties -quiet]

  foreach objPropEle $objPropList {
    set objPropSplits [split $objPropEle ":"]
    if { [llength $objPropSplits] == 2 } {
      dict lappend a_global_vars(excludePropDict) [lindex $objPropSplits 0] [lindex $objPropSplits 1]
    }
  }
}

#This is a short term fix to address the need of exluding properties of certain object from getting written into the script file
#In this fix to execlude a property for an object comparison is done based on string representation of the tcl object.
#There is a chance that there are two Tcl objects with same string representaion in that case it all comes down to property name.
#If property name is also same then, then it could produce undefined results.
#This fix takes an assumption that object_string_rep:property is unique in the list.
proc is_excluded_property { obj property } {
  # Summary: To determine if a property of an object is excluded from writing into the script file or not.
  # Argument Usage: 
  # Return Value:
  # none
  variable a_global_vars

  foreach _obj [dict keys $a_global_vars(excludePropDict)] {
    if { $_obj == $obj } {
      set _property [dict get $a_global_vars(excludePropDict) $_obj]

      if { [lsearch -nocase $_property $property] != -1 } {
        return true
      }
    }
  }

  return false
}

proc getBdforMangedWrapper { fs_name wraperfile proj_name path_dirs } { 
  variable a_global_vars
  
  set srcs_index [lsearch -exact $path_dirs "$proj_name.srcs"]
  if { $srcs_index == -1} {
    #check for .gen directory
    set srcs_index [lsearch -exact $path_dirs "$proj_name.gen"]
  }
  set src_file [join [lrange $path_dirs $srcs_index+1 end] "/"]  
	
  set wrapperName [file tail $wraperfile]
  set wrapperNameNoExtension [file rootname $wrapperName]
  set designName [string range $wrapperNameNoExtension 0 [expr {[string last "_wrapper" $wrapperNameNoExtension] - 1}]]
  
  if { $designName == "" } {
  #Not a wrapper file
  return
  }
  set manged_file_path "$fs_name/bd/$designName/hdl/$wrapperName"
  set manged_file_path [string trim $manged_file_path "\""]

  if { $src_file != $manged_file_path || [get_files $designName.bd] == "" } {
    #Wrapper file is not managed by project
    return
  }
  return [list $designName $wrapperName]
}

proc write_files { proj_dir proj_name tcl_obj type } {
  # Summary: write file and file properties 
  # This helper command is used to script help.
  # Argument Usage: 
  # Return Value:
  # none

  variable a_global_vars
  variable l_script_data
  variable l_bd_wrapper

  set l_local_file_list [list]
  set l_remote_file_list [list]

  # return if empty fileset
  if {[llength [get_files -quiet -of_objects [get_filesets $tcl_obj]]] == 0 } {
    lappend l_script_data "# Empty (no sources present)\n"
    return
  }

  set fs_name [get_filesets $tcl_obj]

  set make_wrapper_list [list]
  set import_coln [list]
  set add_file_coln [list]

  set bc_managed_fs_filter "IS_BLOCK_CONTAINER_MANAGED == 0"
  foreach file [get_files -quiet -norecurse -of_objects [get_filesets $tcl_obj] -filter $bc_managed_fs_filter] {
    if { [file extension $file] == ".xcix" } { continue }
    # Skip direct import/add of BD files if -use_bd_files is not provided
    if { [file extension $file] == ".bd" && !$a_global_vars(b_arg_use_bd_files) } { continue }
    set path_dirs [split [string trim [file normalize [string map {\\ /} $file]]] "/"]
    set srcs_index [lsearch -exact $path_dirs "$proj_name.srcs"]
    set src_file [join [lrange $path_dirs $srcs_index+1 end] "/"]

    # fetch first object
    set file_object [lindex [get_files -quiet -of_objects [get_filesets $fs_name] [list $file]] 0]
    set file_props [list_property $file_object]

    if { [lsearch $file_props "IMPORTED_FROM"] != -1 } {

      # import files
      set imported_path [get_property "imported_from" $file]
      set rel_file_path [get_relative_file_path_for_source $file [get_script_execution_dir]]
      set proj_file_path "\$\{origin_dir\}/$rel_file_path"

      set file "\"[file normalize $proj_dir/${proj_name}.srcs/$src_file]\""

      if { $a_global_vars(b_arg_no_copy_srcs) } {
        # add to the local collection
        lappend l_remote_file_list $file
        if { $a_global_vars(b_absolute_path) || [need_abs_path $file] } {
          lappend add_file_coln "$file"
        } else {
          lappend add_file_coln "\[file normalize \"$proj_file_path\"\]"
        }
      } else {
        # add to the import collection
        lappend l_local_file_list $file
        if { $a_global_vars(b_absolute_path) || [need_abs_path $file] } {
          lappend import_coln "$file"
        } else {
          lappend import_coln "\[file normalize \"$proj_file_path\"\]"
        }
      }

    } else {
      set file "\"$file\""

      set designName ""
      set wrapperName ""
      set bd_file ""

      set design_wrapperName [getBdforMangedWrapper $fs_name $file $proj_name $path_dirs]
      
      if { [llength $design_wrapperName] == 2} {
        set designName [lindex $design_wrapperName 0]
        set wrapperName [lindex $design_wrapperName 1]	  
      }      
      if { $designName != "" } { 

        set wrapper_file ""
        # add to the import collection
        if { $a_global_vars(b_absolute_path)|| [need_abs_path $file]  } {
          set wrapper_file $file
        } else {
          set file_no_quotes [string trim $file "\""]
          set org_file_path "\$\{origin_dir\}/[get_relative_file_path_for_source $file_no_quotes [get_script_execution_dir]]"
          set wrapper_file "\[file normalize \"$org_file_path\" \]"
        }		

        # this is a wrapper file        
        if { $a_global_vars(b_arg_use_bd_files) } {
          set pair_fileset_designame [list]
          lappend pair_fileset_designame $wrapper_file
          lappend pair_fileset_designame $designName
          lappend make_wrapper_list $pair_fileset_designame          
        } else {
          set fileset_designame_wrappername [list]
          lappend fileset_designame_wrappername $fs_name
          lappend fileset_designame_wrappername $designName
          lappend fileset_designame_wrappername $wrapper_file
          lappend l_bd_wrapper $fileset_designame_wrappername		  
        }
		
      } elseif { [is_local_to_project $file] } {
        # is local? add to local project, add to collection and then import this collection by default unless -no_copy_sources is specified
        if { $a_global_vars(b_arg_dump_proj_info) } {
          set src_file "\$PSRCDIR/$src_file"
        }

        # add to the import collection
        if { $a_global_vars(b_absolute_path)|| [need_abs_path $file]  } {
          lappend import_coln $file
        } else {
          set file_no_quotes [string trim $file "\""]
          set org_file_path "\$\{origin_dir\}/[get_relative_file_path_for_source $file_no_quotes [get_script_execution_dir]]"
          lappend import_coln "\[file normalize \"$org_file_path\" \]"
        }
        lappend l_local_file_list $file
      } else {
        if {$a_global_vars(b_absolute_path) || [need_abs_path $file] } {
          lappend add_file_coln [string trim $file "\""]
        } else {
          set file_no_quotes [string trim $file "\""]
          set org_file_path "\$\{origin_dir\}/[get_relative_file_path_for_source $file_no_quotes [get_script_execution_dir]]"
          lappend add_file_coln "\[file normalize \"$org_file_path\"\]"
        }
        lappend l_remote_file_list $file
      }

    }
  }
  # set flag that local sources were found and print warning at the end
  if { (!$a_global_vars(b_local_sources)) && ([llength l_local_file_list] > 0) } {
    set a_global_vars(b_local_sources) 1
  }
   
  if {[llength $add_file_coln]>0} { 
    lappend l_script_data "set files \[list \\"
    foreach file $add_file_coln {
        lappend l_script_data " $file \\"
    }
    lappend l_script_data "\]"
    lappend l_script_data "add_files -norecurse -fileset \$obj \$files"
    lappend l_script_data ""
  }

  # now import local files if -no_copy_sources is not specified
    if { [llength $import_coln] > 0 } {
       if { ! $a_global_vars(b_arg_no_copy_srcs)} {
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
       } else {
         lappend l_script_data "# Add local files from the original project (-no_copy_sources specified)"
          lappend l_script_data "set files \[list \\"
          foreach ifile $import_coln {
            lappend l_script_data " $ifile\\"
          }
          lappend l_script_data "\]"
          # is this a IP block fileset? if yes, add files into current source fileset
          if { [is_ip_fileset $tcl_obj] } {
            lappend l_script_data "set added_files \[add_files -fileset [current_fileset -srcset] \$files\]"
          } else {
            lappend l_script_data "set added_files \[add_files -fileset $tcl_obj \$files\]"
          }
       }
      lappend l_script_data ""
    } 


    if {[llength $make_wrapper_list]>0} { 	
      lappend l_script_data "#call make_wrapper to create wrapper files"
      foreach pair_fileset_designame $make_wrapper_list {
        set wrapper_name [lindex $pair_fileset_designame 0]
        set design [lindex $pair_fileset_designame 1]
        lappend l_script_data "if \{ \[get_property IS_LOCKED \[ get_files -norecurse $design.bd\] \] == 1  \} \{"
        lappend l_script_data "  import_files -fileset $tcl_obj $wrapper_name"
        lappend l_script_data "\} else \{"
        lappend l_script_data "  set wrapper_path \[make_wrapper -fileset $fs_name -files \[ get_files -norecurse $design.bd\] -top\]"
        lappend l_script_data "  add_files -norecurse -fileset $fs_name \$wrapper_path"
        lappend l_script_data "\}"
        lappend l_script_data ""
      }
      lappend l_script_data ""
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

  foreach file [get_files -quiet -norecurse -of_objects [get_filesets $tcl_obj]] {
    lappend l_script_data "# Add/Import constrs file and set constrs file properties"
    set constrs_file  {}
    set file_category {}
    set path_dirs     [split [string trim [file normalize [string map {\\ /} $file]]] "/"]
    set begin         [lsearch -exact $path_dirs "$proj_name.srcs"]
    set src_file      [join [lrange $path_dirs $begin+1 end] "/"]
    set file_object   [lindex [get_files -quiet -of_objects [get_filesets $fs_name] [list $file]] 0]
    set file_props    [list_property $file_object]

    # constrs sources imported? 
    if { [lsearch $file_props "IMPORTED_FROM"] != -1 } {
      set imported_path  [get_property "imported_from" $file]
      set rel_file_path  [get_relative_file_path_for_source $file [get_script_execution_dir]]
      set proj_file_path \$\{origin_dir\}/$rel_file_path
      set file           "\"[file normalize $proj_dir/${proj_name}.srcs/$src_file]\""
      # donot copy imported constrs in new project? set it as remote file in new project.
      if { $a_global_vars(b_arg_no_copy_srcs) } {
        set constrs_file $file
        set file_category "remote"
        if { $a_global_vars(b_absolute_path) || [need_abs_path $imported_path] } {
          add_constrs_file "$file"
        } else {
          set str "\"\[file normalize $proj_file_path\]\""
          add_constrs_file $str
        }
      } else {
        # copy imported constrs in new project. Set it as local file in new project.
        set constrs_file $file
        set file_category "local"
        if { $a_global_vars(b_absolute_path) || [need_abs_path $file] } {
          import_constrs_file $tcl_obj "$file"
        } else {
          set str "\"\[file normalize $proj_file_path\]\""
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
        if { $a_global_vars(b_arg_no_copy_srcs) && (!$a_global_vars(b_absolute_path))&&  ![need_abs_path $file] } {
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

  if { $a_global_vars(b_absolute_path) || [need_abs_path $file_str]} {
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
  lappend l_script_data "set file_added \[add_files -norecurse -fileset \$obj \[list \$file\]\]"
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
    lappend l_script_data "set file_imported \[import_files -fileset $tcl_obj \[list \$file\]\]"
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
    set file_object [lindex [get_files -quiet -of_objects [get_filesets $fs_name] [list "*$file"]] 0]
  } elseif { [string equal $file_category "remote"] } {
    set file_object [lindex [get_files -quiet -of_objects [get_filesets $fs_name] [list $file]] 0]
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
      if { $a_global_vars(b_absolute_path) || [need_abs_path $file]} {
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

    set fileset_type [get_property fileset_type [get_property srcset [$get_what $tcl_obj]]]
    set isImplRun    [get_property is_implementation [$get_what $tcl_obj]]
    set isPRProject  [get_property pr_flow [current_project]]

    set def_flow_type_val  [list_property_value -default flow [$get_what $tcl_obj]]
    set cur_flow_type_val  [get_property flow [$get_what $tcl_obj]]
    set def_strat_type_val [list_property_value -default strategy [$get_what $tcl_obj]]
    set cur_strat_type_val [get_property strategy [$get_what $tcl_obj]]

    set isChildImplRun 0
    if { $isPRProject == 1 && $isImplRun == 1 && $parent_run != "" } {
      set isChildImplRun [get_property is_implementation [$get_what $parent_run]]
      if { $isChildImplRun == 1 } {
        set prConfig [get_property pr_configuration [get_runs $tcl_obj]]
        if { [get_pr_configurations $prConfig] == "" } {
#         review this change. Either skip this run creation or flag error while sourcing script...???
          continue
        }
      }
    }

    set cmd_str "  create_run -name $tcl_obj -part $part -flow {$cur_flow_type_val} -strategy \"$cur_strat_type_val\""

    set retVal [get_param project.enableReportConfiguration]
    set report_strategy ""
    if { $retVal == 1 } {
      set cmd_str "  $cmd_str -report_strategy {No Reports}"
      set report_strategy [get_property report_strategy $tcl_obj]
    }

    if { $isChildImplRun == 1 } {
      set cmd_str "  $cmd_str -pr_config $prConfig"
    }

    lappend l_script_data "# Create '$tcl_obj' run (if not found)"
    lappend l_script_data "if \{\[string equal \[get_runs -quiet $tcl_obj\] \"\"\]\} \{"
    lappend l_script_data "$cmd_str -constrset $constrs_set$parent_run_str"
    lappend l_script_data "\} else \{"
    lappend l_script_data "  set_property strategy \"$cur_strat_type_val\" \[get_runs $tcl_obj\]"
    lappend l_script_data "  set_property flow \"$cur_flow_type_val\" \[get_runs $tcl_obj\]"
    lappend l_script_data "\}"

    if { ($isImplRun == 1) && ($isPRProject == 1 && $isChildImplRun == 0) && ({DesignSrcs} == $fileset_type) } {
      set prConfig [get_property pr_configuration [get_runs $tcl_obj]]
      if { [get_pr_configurations $prConfig] != "" } {
        lappend l_script_data "set_property pr_configuration $prConfig \[get_runs $tcl_obj\]"
      }
    }

    write_report_strategy $tcl_obj $report_strategy

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
      set file_object [lindex [get_files -quiet -of_objects [get_filesets $fs_name] [list "*$file"]] 0]
    } elseif { [string equal $file_category "remote"] } {
      set file_object [lindex [get_files -quiet -of_objects [get_filesets $fs_name] [list $file]] 0]
    }

    set file_props [list_property $file_object]
    set prop_info_list [list]
    set prop_count 0

    foreach file_prop $file_props {
      set is_readonly [get_property is_readonly [rdi::get_attr_specs $file_prop -object $file_object]]
      if { [string equal $is_readonly "1"] } {
        continue
      }

      # Fix for CR-939211 
      if { ([file extension $file] == ".bd") && ([string equal -nocase $file_prop "generate_synth_checkpoint"] || [string equal -nocase $file_prop "synth_checkpoint_mode"]) } {
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
        if { $a_global_vars(b_absolute_path) || [need_abs_path $file]} {
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
  set isPRFlow [get_property pr_flow [current_project]]
  set isRMFileset 0

  if { $isPRFlow == 1 } {
    set allReconfigModules [get_reconfig_modules]
    foreach reconfigmodule $allReconfigModules {
      set rmFileset [get_filesets -of_objects [get_reconfig_modules $reconfigmodule]]
      if { [string equal $rmFileset $fileset] } {
        set isRMFileset 1
        break
      }
    }
  }

  if { $isRMFileset == 1 } {
    return false
  }

  if { [is_bc_managed_fileset $fileset] } {
    return false
  }

  if { {BlockSrcs} != [get_property fileset_type [get_filesets $fileset]] } {
    return false
  }

  set ip_filter "FILE_TYPE == \"IP\" || FILE_TYPE==\"Block Designs\""
  set ips [get_files -all -quiet -of_objects [get_filesets $fileset] -filter $ip_filter]
  set b_found false
  foreach ip $ips {
    if { [get_property generate_synth_checkpoint [lindex [get_files -quiet -all [list "$ip"]] 0]] } {
      set b_found true
      break
    }
  }

  if { $b_found } {
    return true
  }
  return false
}

proc is_bc_managed_fileset { fileset } {
  # Summary: Determine if the fileset is managed by Block Container
  # Argument Usage:
  # fileset: fileset name
  # Return Value:
  # true (1) if the fileset contains a BD that is managed by Block Container, false (0) otherwise

  # make sure fileset is block fileset type
  if { {BlockSrcs} != [get_property fileset_type [get_filesets $fileset]] } {
    return false
  }

  set bc_managed_fs_filter "IS_BLOCK_CONTAINER_MANAGED == 1"
  if {[llength [get_files -norecurse -quiet -of_objects [get_filesets $fileset] -filter $bc_managed_fs_filter]] == 1} {
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

proc is_win_os {} {
  # Summary: Determine if OS is Windows
  # Return Value:
  # true (1) if windows, false (0) otherwise
  set os [lindex $::tcl_platform(os) 0]
  set plat [lindex $::tcl_platform(platform) 0]
  if { [string compare -nocase -length 3 $os "win"] == 0 ||
       [string compare -nocase -length 3 $plat "win"] == 0  } {
     return true
  } else { return false }
}

proc need_abs_path { src } {
  # Summary: Determine if src provided is in a different network mount than execution directory
  # Argument Usage:
  # src: source file to check
  # Return Value:
  # true (1) if src is in a different drive than script execution directory, false (0) otherwise
  variable a_os
  if { $a_os eq "win" } {
    set src_path [file normalize [string trim $src "\""]]
    set ref_path [file normalize [get_script_execution_dir]]
    if { [string compare -nocase -length 2 $src_path $ref_path] != 0 } {
      return true;
    }
  }
  return false
}

proc wr_dashboards { proj_dir proj_name } {
  # Summary: write dashboards and properties 
  # This helper command is used to script help.
  # Argument Usage: 
  # proj_name: project name
  # Return Value:
  # None

  # get current dash board
  # get all dash boards
  # For each dash boards
  # 	create dash board

  write_specified_dashboard $proj_dir $proj_name 

}

proc write_specified_gadget { proj_dir proj_name gadget } {
  # Summary: write the specified gadget 
  # This helper command is used to script help.
  # Argument Usage: 
  # Return Value:
  # none 
  
  variable l_script_data

  set gadgetName [get_property name [get_dashboard_gadgets [list "$gadget"]]]
  set gadgetType [get_property type [get_dashboard_gadgets [list "$gadget"]]]

  set cmd_str "create_dashboard_gadget -name {$gadgetName} -type $gadgetType"

  lappend l_script_data "# Create '$gadgetName' gadget (if not found)"
  lappend l_script_data "if \{\[string equal \[get_dashboard_gadgets  \[ list \"$gadget\" \] \] \"\"\]\} \{"
  lappend l_script_data "$cmd_str"
  lappend l_script_data "\}"

  lappend l_script_data "set obj \[get_dashboard_gadgets \[ list \"$gadget\" \] \]"
  set tcl_obj [get_dashboard_gadgets [list "$gadget"] ]
  set get_what "get_dashboard_gadgets "
  write_props $proj_dir $proj_name $get_what $tcl_obj "gadget" "$"
}


proc write_specified_dashboard { proj_dir proj_name } {
  # Summary: write the specified dashboard 
  # This helper command is used to script help.
  # Argument Usage: 
  # Return Value:
  # none 

  variable l_script_data

  #Create map of gadgets wrt to their position, so that gadget position can be restored.
  set gadgetPositionMap [dict create]

  ##get gadgets of this dashboard
  set gadgets [get_dashboard_gadgets ]
  foreach gd $gadgets {
    write_specified_gadget $proj_dir $proj_name $gd 
    set gadgetCol [get_property COL [get_dashboard_gadgets [list "$gd"]]]
    set gadgetRow [get_property ROW [get_dashboard_gadgets [list "$gd"]]]
    dict set gadgetPositionMap $gadgetCol $gadgetRow $gd
  }

  #if current dashboard is "default_dashboard"
  #check if the above "gadgets" variable has all the default_gadgets, if any default gadget is not there in "gadgets" variable, it means user has deleted those gadgets but as part of create_project, all the default gadgets are created. So we have to delete the gadgets which user has deleted. 

    set default_gadgets {"drc_1" "methodology_1" "power_1" "timing_1" "utilization_1" "utilization_2"}
    foreach dgd $default_gadgets {
      #if dgd is not in gadgets, then delete dgd
      if {$dgd ni $gadgets } {
        lappend l_script_data "# Delete the gadget '$dgd' "
        lappend l_script_data "if \{\[string equal \[get_dashboard_gadgets \[ list \"$dgd\" \] \] \"$dgd\"\]\} \{"
        set cmd_str "delete_dashboard_gadgets -gadgets $dgd"
        lappend l_script_data "$cmd_str"
        lappend l_script_data "\}"
      }
    }


  foreach col [lsort [dict keys $gadgetPositionMap]] {
    set rowDict [dict get $gadgetPositionMap $col]
    foreach row [lsort [dict keys $rowDict]] {
      set gadgetName [dict get $rowDict $row]
      set cmd_str "move_dashboard_gadget -name {$gadgetName} -row $row -col $col"
      lappend l_script_data "$cmd_str"
    }
  }

}

proc wr_bc_managed_rm_files { proj_dir proj_name } {
  # Summary: write bc managed reconfig module files
  # This helper command is used to script help.
  # Argument Usage: 
  # proj_name: project name
  # Return Value:
  
  if { [get_property pr_flow [current_project]] == 0 } {
    return
  }

  set partitionDefs [get_partition_defs -filter "IS_BLOCK_CONTAINER_MANAGED == 1"]
  if { [llength $partitionDefs] == 0 } {
    return
  }
  set reconfigModules [get_reconfig_modules -of_objects $partitionDefs]
  foreach rm $reconfigModules {
    write_reconfigmodule_files $proj_dir $proj_name $rm
  }
}

proc wr_prflow { proj_dir proj_name } {
  # Summary: write partial reconfiguration and properties 
  # This helper command is used to script help.
  # Argument Usage: 
  # proj_name: project name
  # Return Value:
  # None

  if { [get_property pr_flow [current_project]] == 0 } {
    return
  }

  # write below properties only if it's a pr project
  wr_pdefs $proj_dir $proj_name
  wr_reconfigModules $proj_dir $proj_name
  #wr_prConf $proj_dir $proj_name 
}

proc wr_pdefs { proj_dir proj_name } {
  # Summary: write partial reconfiguration and properties 
  # This helper command is used to script help.
  # Argument Usage: 
  # proj_name: project name
  # Return Value:
  # None

  # write pDef i.e. create partition def
  set partitionDefs [get_partition_defs -filter "IS_BLOCK_CONTAINER_MANAGED == 0"]
  
  foreach partitionDef $partitionDefs {
    write_specified_partition_definition $proj_dir $proj_name $partitionDef
  }
}
 
proc write_specified_partition_definition { proj_dir proj_name pDef } {
  # Summary: write the specified partition definition
  # This helper command is used to script help.
  # Argument Usage: 
  # Return Value:
  # none 

  variable l_script_data

  set get_what "get_partition_defs"
  
  set pdefName           [get_property name        [$get_what $pDef]]
  set moduleName         [get_property module_name [$get_what $pDef]]
  set pdef_library       [get_property library     [$get_what $pDef]]
  set default_library    [get_property default_lib [current_project]]

  set cmd_str "create_partition_def -name $pdefName -module $moduleName"
  if { ($pdef_library != "") && (![string equal $pdef_library $default_library]) } {
    set cmd_str "$cmd_str -library $pdef_library"
  }

  lappend l_script_data "# Create '$pdefName' partition definition"
  lappend l_script_data "$cmd_str"

  lappend l_script_data "set obj \[$get_what $pDef\]"
  write_props $proj_dir $proj_name $get_what $pDef "partitionDef"
}

proc wr_reconfigModules { proj_dir proj_name } {
  # Summary: write reconfiguration modules for RPs 
  # This helper command is used to script help.
  # Argument Usage: 
  # proj_name: project name
  # Return Value:
  # None

  # Ignore Block Container managed PartionDefs/RMs
  set partitionDefs [get_partition_defs -filter "IS_BLOCK_CONTAINER_MANAGED == 0"]
  if { [llength $partitionDefs] == 0 } {
    return
  }

  # write  reconfigurations modules
  set reconfigModules [get_reconfig_modules -of_objects $partitionDefs]
  variable a_global_vars

  # associate a bd with rm to be used with write_specified_reconfig_module
  set bd_rm_map [dict create]
  foreach rm $reconfigModules {
    set rm_bds [get_files -norecurse -quiet -of_objects [get_reconfig_modules $rm] *.bd]
    foreach rm_bd1 $rm_bds {
      dict set bd_rm_map $rm_bd1 $rm
    }
  }

  set done_bds [list]
  foreach rm $reconfigModules {
    set rm_bds [get_files -norecurse -quiet -of_objects [get_reconfig_modules $rm] *.bd]
    # get the dependent bd for a rm and process it first, this is required for 2RP support
    set rm_bd_dep [lindex [get_files -references -quiet -of_objects [get_reconfig_modules $rm] *.bd] 0]
    if {[llength $rm_bd_dep] == 1} {
      if {$rm_bd ni $done_bds} {
        if { !$a_global_vars(b_arg_use_bd_files) } {
          write_bd_as_proc $rm_bd_dep
        }
        set rm1 [dict get $bd_rm_map $rm_bd_dep]
        write_specified_reconfig_module $proj_dir $proj_name $rm1
        lappend done_bds $rm_bd_dep
      }
    }

    foreach rm_bd $rm_bds {
      # process bd only if it has not already been processed
      if {$rm_bd ni $done_bds} {
        if { !$a_global_vars(b_arg_use_bd_files) } {
          write_bd_as_proc $rm_bd
        }
        set rm1 [dict get $bd_rm_map $rm_bd]
        write_specified_reconfig_module $proj_dir $proj_name $rm1
        lappend done_bds $rm_bd
      }
    }

    # when no RM BDs are present
    if {[llength $rm_bds] == 0} {
      write_specified_reconfig_module $proj_dir $proj_name $rm
    }
  }
}

proc write_specified_reconfig_module { proj_dir proj_name reconfModule } {
  # Summary: write the specified partial reconfiguration module information 
  # This helper command is used to script help.
  # Argument Usage: 
  # Return Value:
  # none 

  variable l_script_data

  set get_what "get_reconfig_modules"
  
  # fetch all the run attritubes and properties of passed reconfig modules
  set name             [get_property name          [$get_what $reconfModule]]
  set partitionDefName [get_property partition_def [$get_what $reconfModule]]
  set isGateLevelSet   [get_property is_gate_level [$get_what $reconfModule]]

  lappend l_script_data "# Create '$reconfModule' reconfigurable module"
  lappend l_script_data "set partitionDef \[get_partition_defs $partitionDefName\]"

  if { $isGateLevelSet } {
    set moduleName      [get_property module_name [$get_what $reconfModule]]
    if { $moduleName == "" } {
      return
    }
    lappend l_script_data "create_reconfig_module -name $name -top $moduleName -partition_def \$partitionDef -gate_level"    
  } else {
    lappend l_script_data "create_reconfig_module -name $name -partition_def \$partitionDef"
  }

  # write default_rm property for pDef if RM and its corresponding property for pDef->defaultRM is same
  set defaultRM_for_pDef [get_property default_rm [get_partition_def $partitionDefName]]
  
  if { [string equal $reconfModule $defaultRM_for_pDef] } {
    lappend l_script_data "set_property default_rm $reconfModule \$partitionDef" 
  }

  lappend l_script_data "set obj \[$get_what $reconfModule\]"
  write_props $proj_dir $proj_name $get_what $reconfModule "reconfigModule"  

  write_reconfigmodule_files $proj_dir $proj_name $reconfModule
}

proc wr_prConf {proj_dir proj_name} {
  # Summary: write reconfiguration modules for RPs 
  # This helper command is used to script help.
  # Argument Usage: 
  # proj_name: project name
  # Return Value:
  # None

  if { [get_property pr_flow [current_project]] == 0 } {
    return
  }

  # write pr configurations
  set prConfigurations [get_pr_configurations]

  foreach prConfig $prConfigurations {
    write_specified_prConfiguration $proj_dir $proj_name $prConfig
  }
}

proc write_specified_prConfiguration { proj_dir proj_name prConfig } {
  # Summary: write the specified pr reconfiguration 
  # This helper command is used to script help.
  # Argument Usage: 
  # Return Value:
  # none 

  variable l_script_data

  set get_what "get_pr_configurations"

  # fetch pr config properties
  set name           [get_property name [$get_what $prConfig]]
  set configObj   [$get_what $prConfig]
  set partition     [get_property "partition_cell_rms" $configObj] 
  set greyBoxCell     [get_property "greybox_cells" $configObj] 
  variable options 
  if {$partition ne ""} {
    set options "-partitions \[list $partition \]" 
  }
  
  if {$greyBoxCell ne ""} {
    set options "$options -greyboxes \[list $greyBoxCell \]" 
  }

  lappend l_script_data "# Create '$prConfig' pr configurations"
  lappend l_script_data "create_pr_configuration -name $name $options"
  lappend l_script_data "set obj \[$get_what $prConfig\]"

  write_props $proj_dir $proj_name $get_what $prConfig "prConfiguration"
}

proc write_reconfigmodule_files { proj_dir proj_name reconfigModule } {
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
  set bc_managed_fs_filter "IS_BLOCK_CONTAINER_MANAGED == 0"
  set files [get_files -quiet -norecurse -of_objects [get_filesets -of_objects $reconfigModule] -filter $bc_managed_fs_filter]
  if {[llength $files] == 0 } {
    lappend l_script_data "# Empty (no sources present)\n"
    return
  }

  set fileset [get_filesets -of_objects $reconfigModule]
  set fs_name [get_property name $fileset]

  set import_coln [list]
  set add_file_coln [list]
  set bd_list [list]
 
  foreach file $files { 
    if { [file extension $file ] ==".bd" && !$a_global_vars(b_arg_use_bd_files)} {
      lappend bd_list $file
      continue
    }
    set path_dirs [split [string trim [file normalize [string map {\\ /} $file]]] "/"]
    set begin [lsearch -exact $path_dirs "$proj_name.srcs"]
    set src_file [join [lrange $path_dirs $begin+1 end] "/"]

    # fetch first object
    set file_object [lindex [get_files -quiet -norecurse -of_objects [get_filesets -of_objects $reconfigModule] [list $file]] 0]
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
        if { $a_global_vars(b_absolute_path) || [need_abs_path $file]} {
          lappend add_file_coln "$file"
        } else {
          lappend add_file_coln "\"\[file normalize \"$proj_file_path\"\]\""
        }
      } else {
        # add to the import collection
        lappend l_local_file_list $file
        if { $a_global_vars(b_absolute_path) || [need_abs_path $file]} {
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
      if { $a_global_vars(b_arg_no_copy_srcs) && (!$a_global_vars(b_absolute_path)) && ![need_abs_path $file]} {
        set file_no_quotes [string trim $file "\""]
        set rel_file_path [get_relative_file_path_for_source $file_no_quotes [get_script_execution_dir]]
        set file1 "\"\[file normalize \"\$origin_dir/$rel_file_path\"\]\""
        lappend add_file_coln "$file1"
      } else {
        lappend add_file_coln "$file"
      }

    }
  }

  if {[llength $bd_list] > 0 } {
    foreach bd_file $bd_list {
      set filename [file tail $bd_file]
      lappend l_script_data " move_files \[ get_files $filename \] -of_objects \[get_reconfig_modules $reconfigModule\]"
    }
  }
 
  if {[llength $add_file_coln]>0} { 
    lappend l_script_data "set files \[list \\"
    foreach file $add_file_coln {
      if { $a_global_vars(b_absolute_path) || [need_abs_path $file]} {
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
    lappend l_script_data "add_files -norecurse -of_objects \[get_reconfig_modules $reconfigModule\] \$files"
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
      lappend l_script_data "import_files -of_objects \[get_reconfig_modules $reconfigModule\] \$files"
      lappend l_script_data ""
    }
  }

  # write fileset file properties for remote files (added sources)
  write_reconfigmodule_file_properties $reconfigModule $fs_name $proj_dir $l_remote_file_list "remote"

  # write fileset file properties for local files (imported sources)
  write_reconfigmodule_file_properties $reconfigModule $fs_name $proj_dir $l_local_file_list "local"

  # move sub-design files (XCI/BD) of reconfig modules from sources fileset to reconfig-module (RM) fileset
  add_reconfigmodule_subdesign_files $reconfigModule
}

proc add_reconfigmodule_subdesign_files { reconfigModule } {
  # Summary: 
  # Argument Usage: 
  # Return Value:

  variable l_script_data

  foreach rmSubdesignFileset [get_property subdesign_filesets $reconfigModule] {
    foreach fileObj [get_files -quiet -norecurse -of_objects [get_filesets $rmSubdesignFileset]] {
      set path_dirs [split [string trim [file normalize [string map {\\ /} $fileObj ]]] "/"]
      set path [join [lrange $path_dirs end-1 end] "/"]
      set path [string trimleft $path "/"]
      lappend l_script_data "move_files -of_objects \$obj \[get_files *$path\]"
      lappend l_script_data ""
    }
  }
}

proc write_reconfigmodule_file_properties { reconfigModule fs_name proj_dir l_file_list file_category } {
  # Summary: 
  # Write fileset file properties for local and remote files
  # Argument Usage: 
  # reconfigModule : object to inspect
  # fs_name: fileset name
  # l_file_list: list of files (local or remote)
  # file_category: file catwgory (local or remote)
  # Return Value:
  # none


  variable a_global_vars
  variable l_script_data
  variable l_local_files
  variable l_remote_files
  
  set l_local_files  [list]
  set l_remote_files [list]

  set tcl_obj [get_filesets -of_objects $reconfigModule]

  lappend l_script_data "# Set '$reconfigModule' fileset file properties for $file_category files"
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
      set file_object [lindex [get_files -quiet -norecurse -of_objects [get_filesets -of_objects $reconfigModule] [list "*$file"]] 0]
    } elseif { [string equal $file_category "remote"] } {
      set file_object [lindex [get_files -quiet -norecurse -of_objects [get_filesets -of_objects $reconfigModule] [list $file]] 0]
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
        if { $a_global_vars(b_absolute_path) || [need_abs_path $file]} {
          lappend l_script_data "set file \"$file\""
        } else {
          lappend l_script_data "set file \"\$origin_dir/[get_relative_file_path_for_source $file [get_script_execution_dir]]\""
          lappend l_script_data "set file \[file normalize \$file\]"
        }
      } else {
        lappend l_script_data "set file \"$file\""
      }
      lappend l_script_data "set obj \[get_files -of_objects \[get_reconfig_modules $reconfigModule\] \[list \"*\$file\"\]\]"
      set get_what "get_files -of_objects "
      write_properties $prop_info_list $get_what $tcl_obj
      incr file_prop_count
    }
  }

  if { $file_prop_count == 0 } {
    lappend l_script_data "# None"
  }
  lappend l_script_data ""
}

proc write_report_strategy { run report_strategy } {
  # Summary: 
  # create report one by one as per its configuration.
  # Argument Usage:
  # run FCO:
  # Return Value: none

  set retVal [get_param project.enableReportConfiguration]
  if { $retVal == 0 } {
    return
  }
  set reports [get_report_configs -of_objects [get_runs $run]]
  if { [llength $reports] == 0 } {
    return
  }

  variable l_script_data

  lappend l_script_data "set obj \[get_runs $run\]"
  lappend l_script_data "set_property set_report_strategy_name 1 \$obj"
  lappend l_script_data "set_property report_strategy {$report_strategy} \$obj"
  lappend l_script_data "set_property set_report_strategy_name 0 \$obj"

  foreach report $reports {
    set report_name [get_property name $report]
    set report_spec [get_property report_type $report]
    set step [get_property run_step $report]

    lappend l_script_data "# Create '$report' report (if not found)"
    lappend l_script_data "if \{ \[ string equal \[get_report_configs -of_objects \[get_runs $run\] $report\] \"\" \] \} \{"
    lappend l_script_data "  create_report_config -report_name $report_name -report_type $report_spec -steps $step -runs $run"
    lappend l_script_data "\}"

    lappend l_script_data "set obj \[get_report_configs -of_objects \[get_runs $run\] $report\]"
    lappend l_script_data "if { \$obj != \"\" } {"
    write_report_props $report
    lappend l_script_data "}"
  }
}

proc write_report_props { report } {
  # Summary: 
  # iterate over all report options and send all non default values to -->set_property <property> <curr_value> [report FCO]
  # Argument Usage: 
  # report FCO: 
  # Return Value: none

  variable l_script_data
  variable a_global_vars

  set obj_name [get_property name $report]
  set read_only_props [rdi::get_attr_specs -class [get_property class $report] -filter {is_readonly}]
  set prop_info_list [list]
  set properties [list_property $report]

  foreach prop $properties {
    if { [string equal -nocase $prop "OPTIONS.pb"] || [string equal -nocase $prop "OPTIONS.rpx"] } {
      #skipping read_only property
      continue
    }
    if { [lsearch $read_only_props $prop] != -1 } { continue }

    set def_val [list_property_value -default $prop $report]
    set cur_val [get_property $prop $report]

    # filter special properties
    if { [filter $prop $cur_val] } { continue }

    set cur_val [get_target_bool_val $def_val $cur_val]
    set prop_entry "[string tolower $prop]#[get_property $prop $report]"

    if { $a_global_vars(b_arg_all_props) } {
      lappend prop_info_list $prop_entry
    } elseif { $def_val != $cur_val } {
      lappend prop_info_list $prop_entry
    }
  }

  write_properties $prop_info_list "get_report_configs" $report
}

proc suppress_messages {} {
  variable levels_to_suppress
  set levels_to_suppress { {STATUS} {INFO} {WARNING} {CRITICAL WARNING} }
  set msg_rules [split [ debug::get_msg_control_rules -as_tcl ] \n]
  foreach line  $msg_rules {
    set idx_suppress [lsearch $line "-suppress"]
    if { $idx_suppress >= 0  } {
      set idx_severity [lsearch $line "-severity"]
      if { $idx_suppress == $idx_severity + 2 } {
        set lvl_idx [ lsearch $levels_to_suppress [lindex $line $idx_suppress-1 ] ]
        if { $lvl_idx >= 0 } {
          set levels_to_suppress [ lreplace $levels_to_suppress $lvl_idx $lvl_idx]
        }
      }
    }
  }
  foreach level $levels_to_suppress {
    set_msg_config -quiet -suppress -severity $level
  }
}

proc reset_msg_setting {} {
  variable levels_to_suppress
  foreach level $levels_to_suppress {
    reset_msg_config -quiet -suppress -severity $level
  }
}
}
