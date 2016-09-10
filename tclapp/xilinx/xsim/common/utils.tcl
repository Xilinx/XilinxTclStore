####################################################################################
#
# utils.tcl
#
# Script created on 11/17/2015 by Nik Cimino (Xilinx, Inc.)
#
####################################################################################

# These procedures are not designed to be part of the global namespace, but should 
# be sourced inside of a simulation app's namespace. This is done to prevent 
# collisions of these functions if they all belonged to the same namespace, i.e.
# multiple utils.tcl files loaded with the same namespace.

variable _xcs_defined 1

proc xcs_control_pre_compile_flow { b_static_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $b_static_arg b_static

  set val [string tolower [get_param "project.overrideIPStaticPrecompile"]]
  if { {na} == $val } { return }

  if { ({force} == $val) && (!$b_static) } {
    set b_static 1
  } elseif { ({disable} == $val) && ($b_static) } {
    set b_static 0
  }
}

proc xcs_contains_verilog { design_files {flow "NULL"} {s_netlist_file {}} } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set b_verilog_srcs 0
  foreach file $design_files {
    set type [lindex [split $file {|}] 0]
    switch $type {
      {VERILOG} {
        set b_verilog_srcs 1
      }
    }
  }

  if { $flow != "NULL" } {
    if { (({post_synth_sim} == $flow) || ({post_impl_sim} == $flow)) && (!$b_verilog_srcs) } {
      set extn [file extension $s_netlist_file]
      if { {.v} == $extn } {
        set b_verilog_srcs 1
      }
    }
  }

  return $b_verilog_srcs
}

proc xcs_contains_system_verilog { design_files {flow "NULL"} {s_netlist_file {}} } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set b_system_verilog_srcs 0
  foreach file $design_files {
    set type [lindex [split $file {|}] 1]
    switch $type {
      {SystemVerilog} {
        set b_system_verilog_srcs 1
      }
    }
  }

  if { $flow != "NULL" } {
    if { (({post_synth_sim} == $flow) || ({post_impl_sim} == $flow)) && (!$b_system_verilog_srcs) } {
      set extn [file extension $s_netlist_file]
      if { {.sv} == $extn } {
        set b_system_verilog_srcs 1
      }
    }
  }

  return $b_system_verilog_srcs
}

proc xcs_contains_vhdl { design_files {flow "NULL"} {s_netlist_file {}} } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set b_vhdl_srcs 0
  foreach file $design_files {
    set type [lindex [split $file {|}] 0]
    switch $type {
      {VHDL} -
      {VHDL 2008} {
        set b_vhdl_srcs 1
      }
    }
  }

  if { (({post_synth_sim} == $flow) || ({post_impl_sim} == $flow)) && (!$b_vhdl_srcs) } {
    set extn [file extension $s_netlist_file]
    if { {.vhd} == $extn } {
      set b_vhdl_srcs 1
    }
  }

  return $b_vhdl_srcs
}

proc xcs_copy_glbl_file { run_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set target_glbl_file [file normalize [file join $run_dir "glbl.v"]]
  if { [file exists $target_glbl_file] } {
    return
  }

  set data_dir [rdi::get_data_dir -quiet -datafile verilog/src/glbl.v]
  set src_glbl_file [file normalize [file join $data_dir "verilog/src/glbl.v"]]

  if {[catch {file copy -force $src_glbl_file $run_dir} error_msg] } {
    send_msg_id USF-IES-097 WARNING "Failed to copy glbl file '$src_glbl_file' to '$run_dir' : $error_msg\n"
  }
}

proc xcs_fetch_header_from_dynamic { vh_file b_is_bd dynamic_repo_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  #puts vh_file=$vh_file
  set ip_file [xcs_get_top_ip_filename $vh_file]
  if { {} == $ip_file } {
    return $vh_file
  }
  set ip_name [file root [file tail $ip_file]]
  #puts ip_name=$ip_name

  # if not core-container (classic), return original source file from project
  set file_extn [file extension $ip_file]
  if { ![xcs_is_core_container ${ip_name}${file_extn}] } {
    return $vh_file
  }

  set vh_filename   [file tail $vh_file]
  set vh_file_dir   [file dirname $vh_file]
  set output_dir    [get_property IP_OUTPUT_DIR [lindex [get_ips -all $ip_name] 0]]
  set sub_file_path [xcs_get_sub_file_path $vh_file_dir $output_dir]

  # construct full repo dynamic file path
  set sub_dir "ip"
  if { $b_is_bd } {
    set sub_dir "bd"
  }
  set vh_file [file join $dynamic_repo_dir $sub_dir $ip_name $sub_file_path $vh_filename]
  #puts vh_file=$vh_file

  return $vh_file
}

proc xcs_fetch_ip_static_file { file vh_file_obj ipstatic_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # /tmp/tp/tp.srcs/sources_1/ip/my_ip/bd_0/ip/ip_2/axi_infrastructure_v1_1_0/hdl/verilog/axi_infrastructure_v1_1_0_header.vh
  set src_ip_file $file
  set src_ip_file [string map {\\ /} $src_ip_file]
  #puts src_ip_file=$src_ip_file

  # get parent composite file path dir
  set comp_file [get_property parent_composite_file -quiet $vh_file_obj] 
  set comp_file_dir [file dirname $comp_file]
  set comp_file_dir [string map {\\ /} $comp_file_dir]
  # /tmp/tp/tp.srcs/sources_1/ip/my_ip/bd_0/ip/ip_2
  #puts comp_file_dir=$comp_file_dir

  # strip parent dir from file path dir
  set lib_file_path {}
  # axi_infrastructure_v1_1_0/hdl/verilog/axi_infrastructure_v1_1_0_header.vh

  set src_file_dirs  [file split [file normalize $src_ip_file]]
  set comp_file_dirs [file split [file normalize $comp_file_dir]]
  set src_file_len [llength $src_file_dirs]
  set comp_dir_len [llength $comp_file_dir]

  set index 1
  #puts src_file_dirs=$src_file_dirs
  #puts com_file_dirs=$comp_file_dirs
  while { [lindex $src_file_dirs $index] == [lindex $comp_file_dirs $index] } {
    incr index
    if { ($index == $src_file_len) || ($index == $comp_dir_len) } {
      break;
    }
  }
  set lib_file_path [join [lrange $src_file_dirs $index end] "/"]
  #puts lib_file_path=$lib_file_path

  set dst_cip_file [file join $ipstatic_dir $lib_file_path]
  # /tmp/tp/tp.ip_user_files/ipstatic/axi_infrastructure_v1_1_0/hdl/verilog/axi_infrastructure_v1_1_0_header.vh
  #puts dst_cip_file=$dst_cip_file
  return $dst_cip_file
}

proc xcs_find_comp { comps_arg index_arg to_match } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $comps_arg comps
  upvar $index_arg index
  set index 0
  set b_found false
  foreach comp $comps {
    incr index
    if { $to_match != $comp } continue;
    set b_found true
    break
  }
  return $b_found
}

proc xcs_find_file_from_compile_order { ip_name src_file compile_order_files } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set file [string map {\\ /} $src_file]

  set sub_dirs [list]
  set comps [lrange [split $file "/"] 1 end]
  foreach comp $comps {
    if { {.} == $comp } continue;
    if { {..} == $comp } continue;
    lappend sub_dirs $comp
  }
  set file_path_str [join $sub_dirs "/"]

  set str_to_replace "/{$ip_name}/"
  set str_replace_with "/${ip_name}/"
  regsub -all $str_to_replace $file_path_str $str_replace_with file_path_str
  #puts file_path_str=$file_path_str

  foreach file [xcs_uniquify_cmd_str $compile_order_files] {
    set file [string map {\\ /} $file]
    #puts +co_file=$file
    if { [string match  *$file_path_str $file] } {
      set src_file $file
      break
    }
  }
  #puts out_file=$src_file
  return $src_file
}

proc xcs_find_ipstatic_file_path { src_ip_file parent_comp_file ipstatic_dir} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set dest_file {}
  set filename [file tail $src_ip_file]
  set file_obj [lindex [get_files -quiet -all [list "$src_ip_file"]] 0]
  if { {} == $file_obj } {
    set file_obj [lindex [get_files -quiet -all $filename] 0]
  }
  if { {} == $file_obj } {
    return $dest_file
  }

  if { {} == $parent_comp_file } {
    set library_name [get_property library $file_obj]
    set comps [lrange [split $src_ip_file "/"] 1 end]
    set index 0
    set b_found false
    set to_match $library_name
    set b_found [xcs_find_comp comps index $to_match]
    if { $b_found } {
      set file_path_str [join [lrange $comps $index end] "/"]
      #puts file_path_str=$file_path_str
      set dest_file [file normalize [file join $ipstatic_dir $file_path_str]]
    }
  } else {
    set parent_ip_name [file root [file tail $parent_comp_file]]
    set ip_output_dir [get_property ip_output_dir [get_ips -all $parent_ip_name]]
    set src_ip_file_dir [file dirname $src_ip_file]
    set lib_dir [xcs_get_sub_file_path $src_ip_file_dir $ip_output_dir]
    set target_extract_dir [file normalize [file join $ipstatic_dir $lib_dir]]
    set dest_file [file join $target_extract_dir $filename]
  }
  return $dest_file
}

proc xcs_find_top_level_ip_file { src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set comp_file $src_file
  #puts "-----\n  +$src_file"
  set MAX_PARENT_COMP_LEVELS 10
  set count 0
  while (1) {
    incr count
    if { $count > $MAX_PARENT_COMP_LEVELS } { break }
    set file_obj [lindex [get_files -all -quiet [list "$comp_file"]] 0]
    if { {} == $file_obj } {
      # try from filename
      set file_name [file tail $comp_file]
      set file_obj [lindex [get_files -all "$file_name"] 0]
      set comp_file $file_obj
    }
    set props [list_property $file_obj]
    if { [lsearch $props "PARENT_COMPOSITE_FILE"] == -1 } {
      break
    }
    set comp_file [get_property parent_composite_file -quiet $file_obj]
    #puts "  +$comp_file"
  }
  #puts "  +[file root [file tail $comp_file]]"
  #puts "-----\n"
  return $comp_file
}

proc xcs_generate_comp_file_for_simulation { comp_file runs_to_launch_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $runs_to_launch_arg runs_to_launch
  set ts [get_property "SIMULATOR_LANGUAGE" [current_project]]
  set ip_filename [file tail $comp_file]
  set ip_name     [file root $ip_filename]
  # - does the ip support behavioral language?, 
  #   -- if yes, then generate simulation products (if not generated by ip earlier)
  #   -- if not, then does ip synth checkpoint set?,
  #       --- if yes, then generate all products (if not generated by ip earlier)
  #       --- if not, then error with recommendation
  # and also generate the IP netlist
  if { [get_property "IS_IP_BEHAV_LANG_SUPPORTED" $comp_file] } {
    # does ip generated simulation products? if not, generate them
    if { ![get_property "IS_IP_GENERATED_SIM" $comp_file] } {
      send_msg_id USF-XSim-071 INFO "Generating simulation products for IP '$ip_name'...\n"
      set delivered_targets [get_property delivered_targets [get_ips -all -quiet ${ip_name}]]
      if { [regexp -nocase {simulation} $delivered_targets] } {
        generate_target {simulation} [get_files [list "$comp_file"]] -force
      }
    } else {
      send_msg_id USF-XSim-074 INFO "IP '$ip_name' is upto date for simulation\n"
    }
  } elseif { [get_property "GENERATE_SYNTH_CHECKPOINT" $comp_file] } {
    # make sure ip is up-to-date
    if { ![get_property "IS_IP_GENERATED" $comp_file] } { 
      generate_target {all} [get_files [list "$comp_file"]] -force
      send_msg_id USF-XSim-077 INFO "Generating functional netlist for IP '$ip_name'...\n"
      xcs_generate_ip_netlist $comp_file runs_to_launch
    } else {
      send_msg_id USF-XSim-078 INFO "IP '$ip_name' is upto date for all products\n"
    }
  } else {
    # at this point, ip doesnot support behavioral language and synth check point is false, so advise
    # users to select synthesized checkpoint option or set the "generate_synth_checkpoint' ip property.
    set simulator_lang [get_property "SIMULATOR_LANGUAGE" [current_project]]
    set error_msg "IP contains simulation files that do not support the current Simulation Language: '$simulator_lang'.\n"
    if { [get_property "IS_IP_SYNTH_TARGET_SUPPORTED" $comp_file] } {
      append error_msg "Resolution:-\n"
      append error_msg "1)\n"
      append error_msg "or\n2) Select the option Generate Synthesized Checkpoint (.dcp) in the Generate Output Products dialog\
                        to automatically create a matching simulation netlist, or set the 'GENERATE_SYNTH_CHECKPOINT' property on the core."
    } else {
      # no synthesis, so no recommendation to do a synth checkpoint.
    }
    send_msg_id USF-XSim-079 WARNING "$error_msg\n"
    #return 1
  }
}

proc xcs_generate_ip_netlist { comp_file runs_to_launch_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $runs_to_launch_arg runs_to_launch
  set comp_file_obj [get_files [list "$comp_file"]]
  set comp_file_fs  [get_property "FILESET_NAME" $comp_file_obj]
  if { ![get_property "GENERATE_SYNTH_CHECKPOINT" $comp_file_obj] } {
    send_msg_id USF-IES-084 INFO "Generate synth checkpoint is 'false':$comp_file\n"
    # if synth checkpoint read-only, return
    if { [get_property "IS_IP_SYNTH_CHECKPOINT_READONLY" $comp_file_obj] } {
      send_msg_id USF-IES-085 WARNING "Synth checkpoint property is 'readonly' ... skipping:$comp_file\n"
      return
    }
    # set property to create a DCP/structural simulation file
    send_msg_id USF-IES-086 INFO "Setting synth checkpoint for generating simulation netlist:$comp_file\n"
    set_property "GENERATE_SYNTH_CHECKPOINT" true $comp_file_obj
  } else {
    send_msg_id USF-IES-087 INFO "Generate synth checkpoint is set:$comp_file\n"
  }
  # block fileset name is based on the basename of the IP
  set src_file [file normalize $comp_file]
  set ip_basename [file root [file tail $src_file]]
  # block-fileset may not be created at this point, so quiet if not found
  set block_fs_obj [get_filesets -quiet $ip_basename]
  # "block fileset" exists? if not create it
  if { {} == $block_fs_obj } {
    create_fileset -blockset "$ip_basename"
    set block_fs_obj [get_filesets $ip_basename]
    send_msg_id USF-IES-088 INFO "Block-fileset created:$block_fs_obj"
    # set fileset top
    set comp_file_top [get_property "IP_TOP" $comp_file_obj]
    set_property "TOP" $comp_file_top [get_filesets $ip_basename]
    # move sub-design to block-fileset
    send_msg_id USF-IES-089 INFO "Moving ip composite source(s) to '$ip_basename' fileset"
    move_files -fileset [get_filesets $ip_basename] [get_files -of_objects [get_filesets $comp_file_fs] $src_file] 
  }
  if { {BlockSrcs} != [get_property "FILESET_TYPE" $block_fs_obj] } {
    send_msg_id USF-IES-090 ERROR "Given source file is not associated with a design source fileset.\n"
    return 1
  }
  # construct block-fileset run for the netlist
  set run_name $ip_basename;append run_name "_synth_1"
  if { ![get_property "IS_INITIALIZED" [get_runs $run_name]] } {
    reset_run $run_name
  }
  lappend runs_to_launch $run_name
  send_msg_id USF-IES-091 INFO "Run scheduled for '$ip_basename':$run_name\n"
}

proc xcs_get_bin_path { tool_name path_sep } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set path_value $::env(PATH)
  set bin_path {}
  foreach path [split $path_value $path_sep] {
    set exe_file [file normalize [file join $path $tool_name]]
    if { [file exists $exe_file] } {
      set bin_path $path
      break
    }
  }
  return $bin_path
}

proc xcs_get_dynamic_sim_file_core_classic { src_file dynamic_repo_dir b_found_in_repo_arg repo_src_file_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $b_found_in_repo_arg b_found_in_repo
  upvar $repo_src_file_arg repo_src_file

  set filename  [file tail $src_file]
  set file_dir  [file dirname $src_file]
  set file_obj  [lindex [get_files -all [list "$src_file"]] 0]

  set top_ip_file_name {}
  set ip_dir [xcs_get_ip_output_dir_from_parent_composite $src_file top_ip_file_name]
  set hdl_dir_file [xcs_get_sub_file_path $file_dir $ip_dir]

  set top_ip_name [file root [file tail $top_ip_file_name]]
  set extn [file extension $top_ip_file_name]
  set repo_src_file {}
  set sub_dir "ip"
  if { {.bd} == $extn } {
    set sub_dir "bd"
  }
  set repo_src_file [file join $dynamic_repo_dir $sub_dir $top_ip_name $hdl_dir_file $filename]
  if { [file exists $repo_src_file] } {
    set b_found_in_repo 1
    return $repo_src_file
  }
  return $src_file
}

proc xcs_get_dynamic_sim_file_core_container { src_file dynamic_repo_dir b_found_in_repo_arg repo_src_file_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $b_found_in_repo_arg b_found_in_repo
  upvar $repo_src_file_arg repo_src_file

  set filename  [file tail $src_file]
  set file_dir  [file dirname $src_file]
  set file_obj  [lindex [get_files -all [list "$src_file"]] 0]
  set xcix_file [get_property core_container $file_obj]
  set core_name [file root [file tail $xcix_file]]

  set parent_comp_file      [get_property parent_composite_file -quiet $file_obj]
  set parent_comp_file_type [get_property file_type [lindex [get_files -all [list "$parent_comp_file"]] 0]]

  set ip_dir {}
  if { ({Block Designs} == $parent_comp_file_type) || ({DSP Design Sources} == $parent_comp_file_type) } {
    set ip_dir [file join [file dirname $xcix_file] $core_name]
  } else {
    set top_ip_file_name {}
    set ip_dir [xcs_get_ip_output_dir_from_parent_composite $src_file top_ip_file_name]
  }
  set hdl_dir_file [xcs_get_sub_file_path $file_dir $ip_dir]
  set repo_src_file [file join $dynamic_repo_dir "ip" $core_name $hdl_dir_file $filename]

  if { [file exists $repo_src_file] } {
    set b_found_in_repo 1
    return $repo_src_file
  }
  return $src_file
}

proc xcs_get_file_type_category { file_type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set type {UNKNOWN}
  switch $file_type {
    {VHDL} -
    {VHDL 2008} {
      set type {VHDL}
    }
    {Verilog} -
    {SystemVerilog} -
    {Verilog Header} -
    {Verilog/SystemVerilog Header} {
      set type {VERILOG}
    }
  }
  return $type
}

proc xcs_get_files_from_block_filesets { filter_type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set file_list [list]
  set filter "FILESET_TYPE == \"BlockSrcs\""
  set used_in_val "simulation"
  set fs_objs [get_filesets -filter $filter]
  if { [llength $fs_objs] > 0 } {
    send_msg_id USF-IES-101 INFO "Finding block fileset files..."
    foreach fs_obj $fs_objs {
      set fs_name [get_property "NAME" $fs_obj]
      send_msg_id USF-IES-070 INFO "Inspecting fileset '$fs_name' for '$filter_type' files...\n"
      #set files [xcs_remove_duplicate_files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $fs_obj] -filter $filter_type]]
      set files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $fs_obj] -filter $filter_type]
      if { [llength $files] == 0 } {
        send_msg_id USF-IES-071 INFO "No files found in '$fs_name'\n"
        continue
      } else {
        foreach file $files {
          lappend file_list $file
        }
      }
    }
  }
  return $file_list
}

proc xcs_get_ip_output_dir_from_parent_composite { src_file top_ip_file_name_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $top_ip_file_name_arg top_ip_file_name
  set comp_file $src_file
  set MAX_PARENT_COMP_LEVELS 10
  set count 0
  while (1) {
    incr count
    if { $count > $MAX_PARENT_COMP_LEVELS } { break }
    set file_obj [lindex [get_files -all -quiet [list "$comp_file"]] 0]
    set props [list_property $file_obj]
    if { [lsearch $props "PARENT_COMPOSITE_FILE"] == -1 } {
      break
    }
    set comp_file [get_property parent_composite_file -quiet $file_obj]
    #puts "+comp_file=$comp_file"
  }
  set top_ip_name [file root [file tail $comp_file]]
  set top_ip_file_name $comp_file

  set root_comp_file_type [get_property file_type [lindex [get_files -all [list "$comp_file"]] 0]]
  if { ({Block Designs} == $root_comp_file_type) || ({DSP Design Sources} == $root_comp_file_type) } {
    set ip_output_dir [file dirname $comp_file]
  } else {
    set ip_output_dir [get_property ip_output_dir [get_ips -all $top_ip_name]]
  }
  return $ip_output_dir
}

proc xcs_get_relative_file_path { file_path_to_convert relative_to } {
  # Summary:
  # Argument Usage:
  # file_path_to_convert:
  # Return Value:

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
  # get the final index till these sub-dirs matched
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

proc xcs_get_sub_file_path { src_file_path dir_path_to_remove } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set src_path_comps [file split [file normalize $src_file_path]]
  set dir_path_comps [file split [file normalize $dir_path_to_remove]]

  set src_path_len [llength $src_path_comps]
  set dir_path_len [llength $dir_path_comps]

  set index 1
  while { [lindex $src_path_comps $index] == [lindex $dir_path_comps $index] } {
    incr index
    if { ($index == $src_path_len) || ($index == $dir_path_len) } {
      break;
    }
  }
  set sub_file_path [join [lrange $src_path_comps $index end] "/"]
  return $sub_file_path
}

proc xcs_get_top_ip_filename { src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top_ip_file {}

  # find file by full path
  set file_obj [lindex [get_files -all -quiet $src_file] 0]

  # not found, try from source filename
  if { {} == $file_obj } {
    set file_obj [lindex [get_files -all -quiet [file tail $src_file]] 0]
  }

  if { {} == $file_obj } {
    return $top_ip_file
  }
  set props [list_property $file_obj]
  # get the hierarchical top level ip file name if parent comp file is defined
  if { [lsearch $props "PARENT_COMPOSITE_FILE"] != -1 } {
    set top_ip_file [xcs_find_top_level_ip_file $src_file]
  }
  return $top_ip_file
}

proc xcs_is_bd_file { src_file bd_file_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $bd_file_arg bd_file
  set b_is_bd 0
  set comp_file $src_file
  set MAX_PARENT_COMP_LEVELS 10
  set count 0
  while (1) {
    incr count
    if { $count > $MAX_PARENT_COMP_LEVELS } { break }
    set file_obj [lindex [get_files -all -quiet [list "$comp_file"]] 0]
    set props [list_property $file_obj]
    if { [lsearch $props "PARENT_COMPOSITE_FILE"] == -1 } {
      break
    }
    set comp_file [get_property parent_composite_file -quiet $file_obj]
  }

  # got top-most file whose parent-comp is empty ... is this BD?
  if { {.bd} == [file extension $comp_file] } {
    set b_is_bd 1
    set bd_file $comp_file
  }
  return $b_is_bd
}

proc xcs_is_core_container { ip_file_name } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set b_is_container 1
  if { [get_property sim.use_central_dir_for_ips [current_project]] } {
    return $b_is_container
  }

  # is this ip core-container? if not return 0 (classic)
  set value [string trim [get_property core_container [get_files -all -quiet ${ip_file_name}]]]
  if { {} == $value } {
    set b_is_container 0
  }
  return $b_is_container
}

proc xcs_is_fileset { tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set spec_list [rdi::get_attr_specs -quiet -object $tcl_obj -regexp .*FILESET_TYPE.*]
  if { [llength $spec_list] > 0 } {
    if {[regexp -nocase {^fileset_type} $spec_list]} {
      return 1
    }
  }
  return 0
}

proc xcs_is_global_include_file { global_files_str file_to_find } {
  # Summary:
  # Argument Usage:
  # Return Value:

  foreach g_file [split $global_files_str { }] {
    set g_file [string trim $g_file {\"}]
    if { [string compare $g_file $file_to_find] == 0 } {
      return true
    }
  }
  return false
}

proc xcs_is_ip { tcl_obj valid_ip_extns } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # check if ip file extension
  if { [lsearch -exact $valid_ip_extns [file extension $tcl_obj]] >= 0 } {
    return 1
  } else {
    # check if IP object
    if {[regexp -nocase {^ip} [get_property [rdi::get_attr_specs CLASS -object $tcl_obj] $tcl_obj]] } {
      return 1
    }
  }
  return 0
}

proc xcs_is_static_ip_lib { library ip_static_libs } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set library [string tolower $library]
  if { [lsearch $ip_static_libs $library] != -1 } {
    return true
  }
  return false
}

proc xcs_make_file_executable { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  if {$::tcl_platform(platform) == "unix"} {
    if {[catch {exec chmod a+x $file} error_msg] } {
      send_msg_id USF-XSim-069 WARNING "Failed to change file permissions to executable ($file): $error_msg\n"
    }
  } else {
    if {[catch {exec attrib /D -R $file} error_msg] } {
      send_msg_id USF-XSim-070 WARNING "Failed to change file permissions to executable ($file): $error_msg\n"
    }
  }
}

proc xcs_remove_duplicate_files { compile_order_files } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set file_list [list]
  set compile_order [list]
  foreach file $compile_order_files {
    set normalized_file_path [file normalize [string map {\\ /} $file]]
    if { [lsearch -exact $file_list $normalized_file_path] == -1 } {
      lappend file_list $normalized_file_path
      lappend compile_order $file
    }
  }
  return $compile_order
}

proc xcs_resolve_incl_dir_property_value { incl_dirs } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set resolved_path {}
  set incl_dirs [string map {\\ /} $incl_dirs]
  set path_elem {} 
  set comps [split $incl_dirs { }]
  foreach elem $comps {
    # path element starts slash (/)? or drive (c:/)?
    if { [string match "/*" $elem] || [regexp {^[a-zA-Z]:} $elem] } {
      if { {} != $path_elem } {
        # previous path is complete now, add hash and append to resolved path string
        set path_elem "$path_elem|"
        append resolved_path $path_elem
      }
      # setup new path
      set path_elem "$elem"
    } else {
      # sub-dir with space, append to current path
      set path_elem "$path_elem $elem"
    }
  }
  append resolved_path $path_elem

  return $resolved_path
}

proc xcs_uniquify_cmd_str { cmd_strs } {
  # Summary: Removes exact duplicate files (same file path)
  # Argument Usage:
  # Return Value:

  set cmd_str_set   [list]
  set uniq_cmd_strs [list]
  foreach str $cmd_strs {
    if { [lsearch -exact $cmd_str_set $str] == -1 } {
      lappend cmd_str_set $str
      lappend uniq_cmd_strs $str
    }
  }
  return $uniq_cmd_strs
}

proc xcs_get_compiled_libraries { clibs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set l_libs [list]
  set file [file normalize [file join $clibs_dir ".cxl.stat"]]
  if { ![file exists $file] } {
    return $l_libs
  }

  set fh 0
  if {[catch {open $file r} fh]} {
    return $l_libs
  }
  set lib_data [split [read $fh] "\n"]
  close $fh

  foreach line $lib_data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; }
    if { [regexp {^#} $line] } { continue; }
    
    set tokens [split $line {,}]
    set library [lindex $tokens 0]
    if { [lsearch -exact $l_libs $library] == -1 } {
      lappend l_libs $library
    }
  }
  return $l_libs
}

proc xcs_get_common_xpm_library {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  return "xpm"
}

proc xcs_get_common_xpm_vhdl_files {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set files [list]
  lappend files [xcs_get_path_from_data "ip/xpm/xpm_VCOMP.vhd"]
  return $files
}

proc xcs_get_path_from_data {path_from_data} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set data_dir [rdi::get_data_dir -quiet -datafile $path_from_data]
  return [file normalize [file join $data_dir $path_from_data]]
}
