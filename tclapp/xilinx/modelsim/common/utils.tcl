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

proc xcs_create_fs_options_spec { simulator opts } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # create properties on the fileset object
  foreach { row } $opts  {
    set name  [lindex $row 0]
    set type  [lindex $row 1]
    set value [lindex $row 2]
    set desc  [lindex $row 3]

    # setup property name
    set prop_name "${simulator}.${name}"

    set prop_name [string tolower $prop_name]

    # is registered already?
    if { [xcs_is_option_registered_on_simulator $prop_name $simulator] } {
      continue;
    }

    # is enum type?
    if { {enum} == $type } {
      set e_value   [lindex $value 0]
      set e_default [lindex $value 1]
      set e_values  [lindex $value 2]
      # create enum property
      create_property -name "${prop_name}" -type $type -description $desc -enum_values $e_values -default_value $e_default -class fileset -no_register
    } elseif { {file} == $type } {
      set f_extns   [lindex $row 4]
      set f_desc    [lindex $row 5]
      # create file property
      set v_default $value
      create_property -name "${prop_name}" -type $type -description $desc -default_value $v_default -file_types $f_extns -display_text $f_desc -class fileset -no_register
    } else {
      set v_default $value
      create_property -name "${prop_name}" -type $type -description $desc -default_value $v_default -class fileset -no_register
    }
  }
  return 0
}

proc xcs_set_fs_options { fs_obj simulator opts } {
  # Summary:
  # Argument Usage:
  # Return Value:

  foreach { row } $opts  {
    set name  [lindex $row 0]
    set type  [lindex $row 1]
    set value [lindex $row 2]
    set desc  [lindex $row 3]

    set prop_name "${simulator}.${name}"

    # is registered already?
    if { [xcs_is_option_registered_on_simulator $prop_name $simulator] } {
      continue;
    }

    # is enum type?
    if { {enum} == $type } {
      set e_value   [lindex $value 0]
      set e_default [lindex $value 1]
      set e_values  [lindex $value 2]
      set_property -name "${prop_name}" -value $e_value -objects ${fs_obj}
    } else {
      set v_default $value
      set_property -name "${prop_name}" -value $value -objects ${fs_obj}
    }
  }
  return 0
}

proc xcs_is_option_registered_on_simulator { prop_name simulator } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set str_1 [string tolower $prop_name]
  # get registered options from simulator for the current simset
  foreach option_name [get_property "REGISTERED_OPTIONS" [get_simulators $simulator]] {
    set str_2 [string tolower $option_name]
    if { [string compare $str_1 $str_2] == 0 } {
      return true
    }
  }
  return false
}

proc xcs_extract_ip_files { b_extract_ip_sim_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $b_extract_ip_sim_files_arg b_extract_ip_sim_files

  if { ![get_property corecontainer.enable [current_project]] } {
    return
  }
  set b_extract_ip_sim_files [get_property extract_ip_sim_files [current_project]]
  if { $b_extract_ip_sim_files } {
    foreach ip [get_ips -all -quiet] {
      set xci_ip_name "${ip}.xci"
      set xcix_ip_name "${ip}.xcix"
      set xcix_file_path [get_property core_container [get_files -quiet -all ${xci_ip_name}]]
      if { {} != $xcix_file_path } {
        [catch {rdi::extract_ip_sim_files -of_objects [get_files -quiet -all ${xcix_ip_name}]} err]
      }
    }
  }
}

proc xcs_set_ref_dir { fh b_absolute_path s_launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # setup source dir var
  puts $fh "# directory path for design sources and include directories (if any) wrt this path"
  if { $b_absolute_path } {
    puts $fh "origin_dir=\"$s_launch_dir\""
  } else {
    puts $fh "origin_dir=\".\""
  }
  puts $fh ""
}

proc xcs_compile_glbl_file { simulator b_load_glbl design_files s_simset s_simulation_flow s_netlist_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set fs_obj      [get_filesets $s_simset]
  set target_lang [get_property "TARGET_LANGUAGE" [current_project]]
  set flow        $s_simulation_flow
  if { [xcs_contains_verilog $design_files $s_simulation_flow $s_netlist_file] } {
    if { $b_load_glbl } {
      return 1
    }
    return 0
  } elseif { [xcs_glbl_dependency_for_xpm] } {
    if { $b_load_glbl } {
      return 1
    }
    return 0
  }

  # target lang is vhdl and glbl is added as top for post-implementation and post-synthesis and load glbl set (default)
  if { ((({VHDL} == $target_lang) || ({VHDL 2008} == $target_lang)) && (({post_synth_sim} == $flow) || ({post_impl_sim} == $flow)) && $b_load_glbl) } {
    return 1
  }

  switch $simulator {
    {ies} -
    {xcelium} -
    {vcs} {
      if { ({post_synth_sim} == $flow) || ({post_impl_sim} == $flow) } {
        return 1
      }
    }
  }
  return 0
}

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

  if { [xcs_glbl_dependency_for_xpm] } {
    if { !$b_verilog_srcs } {
      set b_verilog_srcs 1
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
    send_msg_id SIM-utils-001 WARNING "Failed to copy glbl file '$src_glbl_file' to '$run_dir' : $error_msg\n"
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
  set output_dir    [get_property -quiet IP_OUTPUT_DIR [lindex [get_ips -quiet -all $ip_name] 0]]
  if { [string length $output_dir] == 0 } {
    return $vh_file
  }

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
  set comp_dir_len [llength $comp_file_dirs]

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

proc xcs_fetch_ip_static_header_file { file vh_file_obj ipstatic_dir ip_repo_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # fetch verilog header files from ip_user_files/ipstatic, if param is false (old behavior)
  if { ![get_param project.includeIPStaticVHFileDirsFromRepo] } {
    return [xcs_fetch_ip_static_file $file $vh_file_obj $ipstatic_dir]
  }

  variable a_sim_cache_ip_repo_header_files

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
  set comp_dir_len [llength $comp_file_dirs]

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

  set dst_cip_file {}
  # find and cache ip header file from repository, if it exist
  set vh_file_name [file tail $src_ip_file]
  set ip_lib_dir_name [lindex [split $lib_file_path "/"] 0]
  set repo_lib_dir "$ip_repo_dir/$ip_lib_dir_name"
  if { [file exists $repo_lib_dir] } {
    set vh_file_key "${repo_lib_dir}#$vh_file_name"
    if { [info exists a_sim_cache_ip_repo_header_files($vh_file_key)] } {
      set dst_cip_file $a_sim_cache_ip_repo_header_files($vh_file_key)
    } else {
      set dst_cip_file [xcs_get_ip_header_file_from_repo $ip_repo_dir $ip_lib_dir_name $vh_file_name]
      if { ({} != $dst_cip_file) && [file exist $dst_cip_file] } {
        set a_sim_cache_ip_repo_header_files($vh_file_key) $dst_cip_file
        return $dst_cip_file
      }
    }
  }
  if { ({} != $dst_cip_file) && [file exist $dst_cip_file] } {
    return $dst_cip_file
  }
  
  #
  # file not found from repository, calculate from ipstatic dir now
  #
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

proc xcs_find_file_from_compile_order { ip_name src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable l_compile_order_files_uniq

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

  foreach file $l_compile_order_files_uniq {
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

proc xcs_find_ipstatic_file_path { file_obj src_ip_file parent_comp_file ipstatic_dir} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set dest_file {}
  set filename [file tail $src_ip_file]
  if { {} == $file_obj } {
    set file_obj [lindex [get_files -quiet -all [list "$src_ip_file"]] 0]
  }
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

  variable a_sim_cache_all_design_files_obj
  variable a_sim_cache_parent_comp_files

  set comp_file $src_file
  #puts "-----\n  +$src_file"
  set MAX_PARENT_COMP_LEVELS 10
  set count 0
  while (1) {
    incr count
    if { $count > $MAX_PARENT_COMP_LEVELS } { break }
    set file_obj  {}
    if { [info exists a_sim_cache_all_design_files_obj($comp_file)] } {
      set file_obj $a_sim_cache_all_design_files_obj($comp_file)
    } else {
      set file_obj [lindex [get_files -all -quiet [list "$comp_file"]] 0]
    }
    if { {} == $file_obj } {
      # try from filename
      set file_name [file tail $comp_file]
      set file_obj [lindex [get_files -all "$file_name"] 0]
      set comp_file $file_obj
    }
    if { [info exists a_sim_cache_parent_comp_files($comp_file)] } {
      break
    } else {
      set props [list_property $file_obj]
      if { [lsearch $props "PARENT_COMPOSITE_FILE"] == -1 } {
        set a_sim_cache_parent_comp_files($comp_file) true
        break
      }
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
      send_msg_id SIM-utils-002 INFO "Generating simulation products for IP '$ip_name'...\n"
      set delivered_targets [get_property delivered_targets [get_ips -all -quiet ${ip_name}]]
      if { [regexp -nocase {simulation} $delivered_targets] } {
        generate_target {simulation} [get_files [list "$comp_file"]] -force
      }
    } else {
      send_msg_id SIM-utils-003 INFO "IP '$ip_name' is upto date for simulation\n"
    }
  } elseif { [get_property "GENERATE_SYNTH_CHECKPOINT" $comp_file] } {
    # make sure ip is up-to-date
    if { ![get_property "IS_IP_GENERATED" $comp_file] } { 
      generate_target {all} [get_files [list "$comp_file"]] -force
      send_msg_id SIM-utils-004 INFO "Generating functional netlist for IP '$ip_name'...\n"
      xcs_generate_ip_netlist $comp_file runs_to_launch
    } else {
      send_msg_id SIM-utils-005 INFO "IP '$ip_name' is upto date for all products\n"
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
    send_msg_id SIM-utils-006 WARNING "$error_msg\n"
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
    send_msg_id SIM-utils-007 INFO "Generate synth checkpoint is 'false':$comp_file\n"
    # if synth checkpoint read-only, return
    if { [get_property "IS_IP_SYNTH_CHECKPOINT_READONLY" $comp_file_obj] } {
      send_msg_id SIM-utils-008 WARNING "Synth checkpoint property is 'readonly' ... skipping:$comp_file\n"
      return
    }
    # set property to create a DCP/structural simulation file
    send_msg_id SIM-utils-009 INFO "Setting synth checkpoint for generating simulation netlist:$comp_file\n"
    set_property "GENERATE_SYNTH_CHECKPOINT" true $comp_file_obj
  } else {
    send_msg_id SIM-utils-010 INFO "Generate synth checkpoint is set:$comp_file\n"
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
    send_msg_id SIM-utils-011 INFO "Block-fileset created:$block_fs_obj"
    # set fileset top
    set comp_file_top [get_property "IP_TOP" $comp_file_obj]
    set_property "TOP" $comp_file_top [get_filesets $ip_basename]
    # move sub-design to block-fileset
    send_msg_id SIM-utils-012 INFO "Moving ip composite source(s) to '$ip_basename' fileset"
    move_files -fileset [get_filesets $ip_basename] [get_files -of_objects [get_filesets $comp_file_fs] $src_file] 
  }
  if { {BlockSrcs} != [get_property "FILESET_TYPE" $block_fs_obj] } {
    send_msg_id SIM-utils-013 ERROR "Given source file is not associated with a design source fileset.\n"
    return 1
  }
  # construct block-fileset run for the netlist
  set run_name $ip_basename;append run_name "_synth_1"
  if { ![get_property "IS_INITIALIZED" [get_runs $run_name]] } {
    reset_run $run_name
  }
  lappend runs_to_launch $run_name
  send_msg_id SIM-utils-014 INFO "Run scheduled for '$ip_basename':$run_name\n"
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

  variable a_sim_cache_all_design_files_obj

  set filename  [file tail $src_file]
  set file_dir  [file dirname $src_file]
  set file_obj  {}

  if { [info exists a_sim_cache_all_design_files_obj($src_file)] } {
    set file_obj $a_sim_cache_all_design_files_obj($src_file)
  } else {
    set file_obj [lindex [get_files -all [list "$src_file"]] 0]
  }

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

  variable a_sim_cache_all_design_files_obj

  set filename  [file tail $src_file]
  set file_dir  [file dirname $src_file]
  set file_obj  {}

  if { [info exists a_sim_cache_all_design_files_obj($src_file)] } {
    set file_obj $a_sim_cache_all_design_files_obj($src_file)
  } else {
    set file_obj [lindex [get_files -all [list "$src_file"]] 0]
  }

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
    {SystemC} {
      set type {SYSTEMC}
    }
    {CPP} {
      set type {CPP}
    }
    {C} {
      set type {C}
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
    send_msg_id SIM-utils-015 INFO "Finding block fileset files..."
    foreach fs_obj $fs_objs {
      set fs_name [get_property "NAME" $fs_obj]
      send_msg_id SIM-utils-016 INFO "Inspecting fileset '$fs_name' for '$filter_type' files...\n"
      #set files [xcs_remove_duplicate_files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $fs_obj] -filter $filter_type]]
      set files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $fs_obj] -filter $filter_type]
      if { [llength $files] == 0 } {
        send_msg_id SIM-utils-017 INFO "No files found in '$fs_name'\n"
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
  variable a_sim_cache_all_design_files_obj
  variable a_sim_cache_parent_comp_files
  set comp_file $src_file
  set MAX_PARENT_COMP_LEVELS 10
  set count 0
  while (1) {
    incr count
    if { $count > $MAX_PARENT_COMP_LEVELS } { break }
    set file_obj  {}
    if { [info exists a_sim_cache_all_design_files_obj($comp_file)] } {
      set file_obj $a_sim_cache_all_design_files_obj($comp_file)
    } else {
      set file_obj [lindex [get_files -all -quiet [list "$comp_file"]] 0]
    }
    if { [info exists a_sim_cache_parent_comp_files($comp_file)] } {
      break
    } else {
      set props [list_property $file_obj]
      if { [lsearch $props "PARENT_COMPOSITE_FILE"] == -1 } {
        set a_sim_cache_parent_comp_files($comp_file) true
        break
      }
    }
    set comp_file [get_property parent_composite_file -quiet $file_obj]
    #puts "+comp_file=$comp_file"
  }
  set top_ip_name [file root [file tail $comp_file]]
  set top_ip_file_name $comp_file


  set file_obj  {}
  if { [info exists a_sim_cache_all_design_files_obj($comp_file)] } {
    set file_obj $a_sim_cache_all_design_files_obj($comp_file)
  } else {
    set file_obj [lindex [get_files -all [list "$comp_file"]] 0]
  }

  set root_comp_file_type [get_property file_type $file_obj]
  if { ({Block Designs} == $root_comp_file_type) || ({DSP Design Sources} == $root_comp_file_type) } {
    set ip_output_dir [file dirname $comp_file]
  } else {
    set ip_output_dir [get_property ip_output_dir [get_ips -all $top_ip_name]]
  }
  return $ip_output_dir
}

proc xcs_resolve_file_path { file_dir_path_to_convert launch_dir } {
  # Summary: Make file path relative to ref_dir if relative component found
  # Argument Usage:
  # file_dir_path_to_convert: input file to make relative to specfied path
  # Return Value:
  # Relative path wrt the path specified

  set ref_dir [file normalize [string map {\\ /} $launch_dir]]
  set ref_comps [lrange [split $ref_dir "/"] 1 end]
  set file_comps [lrange [split [file normalize [string map {\\ /} $file_dir_path_to_convert]] "/"] 1 end]
  set index 1
  while { [lindex $ref_comps $index] == [lindex $file_comps $index] } {
    incr index
  }
  # is file path within reference dir? return relative path
  if { $index == [llength $ref_comps] } {
    return [xcs_get_relative_file_path $file_dir_path_to_convert $ref_dir]
  }
  # return absolute
  return $file_dir_path_to_convert
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

  variable a_sim_cache_all_design_files_obj

  set top_ip_file {}

  # find file by full path
  set file_obj  {}
  if { [info exists a_sim_cache_all_design_files_obj($src_file)] } {
    set file_obj $a_sim_cache_all_design_files_obj($src_file)
  } else {
    set file_obj [lindex [get_files -all -quiet $src_file] 0]
  }

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

proc xcs_is_bd_file { src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_cache_all_design_files_obj
  variable a_sim_cache_parent_comp_files
  set comp_file $src_file
  set MAX_PARENT_COMP_LEVELS 10
  set count 0
  while (1) {
    incr count
    if { $count > $MAX_PARENT_COMP_LEVELS } { break }
    set file_obj  {}
    if { [info exists a_sim_cache_all_design_files_obj($comp_file)] } {
      set file_obj $a_sim_cache_all_design_files_obj($comp_file)
    } else {
      set file_obj [lindex [get_files -all -quiet [list "$comp_file"]] 0]
    }
    if { [info exists a_sim_cache_parent_comp_files($comp_file)] } {
      break
    } else {
      set props [list_property $file_obj]
      if { [lsearch $props "PARENT_COMPOSITE_FILE"] == -1 } {
        set a_sim_cache_parent_comp_files($comp_file) true
        break
      }
    }
    set comp_file [get_property parent_composite_file -quiet $file_obj]
  }

  # got top-most file whose parent-comp is empty ... is this BD?
  if { {.bd} == [file extension $comp_file] } {
    return 1
  }
  return 0
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

proc xcs_is_local_ip_lib { library local_libs } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set library [string tolower $library]
  if { [lsearch -exact $local_libs $library] != -1 } {
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
      send_msg_id SIM-utils-018 WARNING "Failed to change file permissions to executable ($file): $error_msg\n"
    }
  } else {
    if {[catch {exec attrib /D -R $file} error_msg] } {
      send_msg_id SIM-utils-019 WARNING "Failed to change file permissions to executable ($file): $error_msg\n"
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

  set cmd_dict [dict create]
  foreach str $cmd_strs {
    dict append cmd_dict $str
  }
  return [dict keys $cmd_dict]
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
  # is override param dir specified?
  set ip_dir [get_param "project.xpm.overrideIPDir"]
  if { ({} != $ip_dir) && [file exists $ip_dir] } {
    set comp_file "$ip_dir/xpm_VCOMP.vhd"
    if { ![file exists $comp_file] } {
      set file [xcs_get_path_from_data "ip/xpm/xpm_VCOMP.vhd"]
      send_msg_id SIM-utils-020 WARNING "The component file does not exist! '$comp_file'. Using default: '$file'\n"
      set comp_file $file
    }
    lappend files $comp_file
  } else {
    lappend files [xcs_get_path_from_data "ip/xpm/xpm_VCOMP.vhd"]
  }
  return $files
}

proc xcs_get_path_from_data {path_from_data} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set data_dir [rdi::get_data_dir -quiet -datafile $path_from_data]
  return [file normalize [file join $data_dir $path_from_data]]
}

proc xcs_get_libs_from_local_repo {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  # get the xilinx installed ip repo location (IP_HEAD/customer/vivado/data/ip)
  set install_repo [file normalize [file join [rdi::get_data_dir -quiet -datafile "ip"] "ip"]]
  set install_comps [split [string map {\\ /} $install_repo] {/}]
  set index [lsearch -exact $install_comps "IP_HEAD"]
  if { $index == -1 } {
    set install_dir $install_repo
  } else {
    set install_dir [join [lrange $install_comps $index end] "/"]
  }

  set lib_dict [dict create]
  foreach ip_obj [get_ips -all -quiet] {
    if { {} == $ip_obj } { continue }
    # is ip in locked state? compile files from this ip locally
    set b_is_locked 0
    set b_is_locked [get_property -quiet is_locked $ip_obj]
    if { $b_is_locked } {
      foreach file_obj [get_files -quiet -all -of_objects $ip_obj -filter {USED_IN=~"*ipstatic*"}] {
        set lib [get_property library $file_obj]
        if { {xil_defaultlib} == $lib } { continue }
        dict append lib_dict $lib
      }
    } else {
      # is this ip from local repo? compile files from this ip locally
      set ip_def_obj [get_ipdefs -quiet -all [get_property -quiet ipdef $ip_obj]]
      if { {} == $ip_def_obj } { continue }
      
      # fetch the first repo path currently and get the IP_HEAD sub_dir
      set local_repo [lindex [get_property -quiet repository $ip_def_obj] 0]
      if { {} == $local_repo } { continue }
      set local_repo [string map {\\ /} $local_repo]

      # continue if local ip repo sub_dir not found
      set ip_repo_sub_dir [file tail $local_repo]
      if { {ip_repo} != $ip_repo_sub_dir } {
        continue
      }

      set local_comps [split $local_repo {/}]
      set index [lsearch -exact $local_comps "IP_HEAD"]
      if { $index == -1 } {
        set local_dir $local_repo
      } else {
        set local_dir [join [lrange $local_comps $index end] "/"]
      }
  
      # if install ip_head sub-dir doesnot match with local ip repo path, filter libraries for this ip to be processed locally
      if { [string equal -nocase $install_dir $local_dir] != 1 } {
        foreach file_obj [get_files -quiet -all -of_objects $ip_obj -filter {USED_IN=~"*ipstatic*"}] {
          set lib [get_property library $file_obj]
          if { {xil_defaultlib} == $lib } { continue }
          dict append lib_dict $lib
        }
      }
    }
  }
  return [dict keys $lib_dict]
}

proc xcs_cache_result {args} {
  # Summary: Return calculated results if they exists else execute the command args
  #          NOTE: do not use this for procs containing upvars (in general), but to
  #          cache a proc that use upvar, see (a_cache_get_dynamic_sim_file_bd)
  # Argument Usage:
  # Return Value:
  variable a_sim_cache_result

  # replace "[" and "]" with "|"
  set cache_hash [regsub -all {[\[\]]} $args {|}];
  set cache_hash [uplevel expr \"$cache_hash\"]

  # Verify cache with the actual values
  #puts "CACHE_ARGS=${args}"
  #puts "CACHE_HASH=${cache_hash}"
  #if { [info exists a_sim_cache_result($cache_hash)] } {
  #  #puts " CACHE_EXISTS"
  #  set old $a_sim_cache_result($cache_hash)
  #  set a_sim_cache_result($cache_hash) [uplevel eval $args]
  #  if { "$a_sim_cache_result($cache_hash)" != "$old" } {
  #    error "CACHE_VALIDATION: difference detected, halting flow\n OLD: ${old}\n NEW: $a_sim_cache_result($cache_hash)"
  #  }
  #  return $a_sim_cache_result($cache_hash)
  #}

  # NOTE: to disable caching (with this proc) comment this block
  if { [info exists a_sim_cache_result($cache_hash)] } {
    # return evaluated result
    return $a_sim_cache_result($cache_hash)
  }
  # end NOTE

  # evaluate first time
  return [set a_sim_cache_result($cache_hash) [uplevel eval $args]]
}

proc xcs_is_ip_project {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set fs_filter "FILESET_TYPE == \"SimulationSrcs\" || \
                 FILESET_TYPE == \"DesignSrcs\"     || \
                 FILESET_TYPE == \"BlockSrcs\""

  set ft_filter "FILE_TYPE == \"IP\"                 || \
                 FILE_TYPE == \"IPX\"                || \
                 FILE_TYPE == \"DSP Design Sources\" || \
                 FILE_TYPE == \"Block Designs\""

  foreach fs_obj [get_filesets -quiet -filter $fs_filter] {
    set ip_files [get_files -quiet -all -of_objects $fs_obj -filter $ft_filter]
    if { [llength $ip_files] > 0 } {
      return true
    }
  }
  return false
}

proc xcs_find_files { src_files_arg tcl_obj filter dir b_absolute_path in_fs_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable l_valid_ip_extns
  upvar $src_files_arg src_files

  if { [xcs_is_ip $tcl_obj $l_valid_ip_extns] } {
    set ip_name [file tail $tcl_obj]
    foreach file [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $filter] {
      set file [file normalize $file]
      if { $b_absolute_path } {
        set file "[xcs_resolve_file_path $file $dir]"
      } else {
        set file "[xcs_get_relative_file_path $file $dir]"
      }
      lappend src_files $file
    }
  } elseif { [xcs_is_fileset $tcl_obj] } {
    set filesets [list]
    lappend filesets $in_fs_obj
    set linked_src_set {}
    if { ({SimulationSrcs} == [get_property fileset_type [get_filesets $in_fs_obj]]) } {
      set linked_src_set [get_property "SOURCE_SET" [get_filesets $in_fs_obj]]
    }
    if { {} != $linked_src_set } {
      lappend filesets $linked_src_set
    }

    # add block filesets
    set blk_filter "FILESET_TYPE == \"BlockSrcs\""
    foreach blk_fs_obj [get_filesets -filter $blk_filter] {
      lappend filesets $blk_fs_obj
    }

    foreach fs_obj $filesets {
      foreach file [get_files -quiet -of_objects [get_filesets $fs_obj] -filter $filter] {
        set file [file normalize $file]
        if { $b_absolute_path } {
          set file "[xcs_resolve_file_path $file $dir]"
        } else {
          set file "[xcs_get_relative_file_path $file $dir]"
        }
        lappend src_files $file
      }
    }
  }
}

proc xcs_is_embedded_flow {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable s_embedded_files_filter
  set embedded_files [get_files -all -quiet -filter $s_embedded_files_filter]
  if { [llength $embedded_files] > 0 } {
    return 1
  }

  # check if gt_quad_base present
  if { [xcs_find_ip "gt_quad_base"] } {
    return 1
  }
  return 0
}

proc xcs_get_netlist_filename { s_sim_top s_simulation_flow s_type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set filename $s_sim_top
  switch -regexp -- $s_simulation_flow {
    {behav_sim} {
      set filename [append filename "_behav"]
    }
    {post_synth_sim} -
    {post_impl_sim} {
      switch -regexp -- $s_type {
        {functional} { set filename [append filename "_func"] }
        {timing}     { set filename [append filename "_time"] }
      }
    }
  }
  switch -regexp -- $s_simulation_flow {
    {post_synth_sim} { set filename [append filename "_synth"] }
    {post_impl_sim}  { set filename [append filename "_impl"] }
  }
  return $filename
}

proc xcs_get_netlist_writer_cmd_args { s_simset s_type extn } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set fs_obj                 [get_filesets $s_simset]
  set nl_cell                [get_property "NL.CELL" $fs_obj]
  set nl_incl_unisim_models  [get_property "NL.INCL_UNISIM_MODELS" $fs_obj]
  set nl_rename_top          [get_property "NL.RENAME_TOP" $fs_obj]
  set nl_sdf_anno            [get_property "NL.SDF_ANNO" $fs_obj]
  set nl_write_all_overrides [get_property "NL.WRITE_ALL_OVERRIDES" $fs_obj]
  set args                   [list]

  if { {} != $nl_cell } {
    lappend args "-cell"
    lappend args $nl_cell
  }

  if { $nl_write_all_overrides } {
    lappend args "-write_all_overrides"
  }

  if { {} != $nl_rename_top } {
    if { {.v} == $extn } {
      lappend args "-rename_top"
      lappend args $nl_rename_top
    } elseif { {.vhd} == $extn } {
      lappend args "-rename_top"
      lappend args $nl_rename_top
    }
  }

  if { ({timing} == $s_type) } {
    if { $nl_sdf_anno } {
      lappend args "-sdf_anno true"
    } else {
      lappend args "-sdf_anno false"
    }
  }

  if { $nl_incl_unisim_models } {
    lappend args "-include_unisim"
  }
  lappend args "-force"
  set cmd_args [join $args " "]

  return $cmd_args
}

proc xcs_get_netlist_extn { s_type warning } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set extn {.v}
  set target_lang [get_property "TARGET_LANGUAGE" [current_project]]
  if { {VHDL} == $target_lang } {
    set extn {.vhd}
  }

  if { (({VHDL} == $target_lang) && ({timing} == $s_type)) } {
    set extn {.v}
    if { $warning } {
      send_msg_id SIM-utils-020 INFO "The target language is set to VHDL, it is not supported for simulation type '$s_type', using Verilog instead.\n"
    }
  }
  return $extn
}

proc xcs_get_sdf_writer_cmd_args { s_simset } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set fs_obj            [get_filesets $s_simset]
  set nl_cell           [get_property "NL.CELL" $fs_obj]
  set nl_rename_top     [get_property "NL.RENAME_TOP" $fs_obj]
  set nl_process_corner [get_property "NL.PROCESS_CORNER" $fs_obj]
  set args              [list]

  if { {} != $nl_cell } {
    lappend args "-cell"
    lappend args $nl_cell
  }

  lappend args "-process_corner"
  lappend args $nl_process_corner

  if { {} != $nl_rename_top } {
    lappend "-rename_top_module"
    lappend args $nl_rename_top
  }

  lappend args "-force"

  set cmd_args [join $args " "]
  return $cmd_args
}

proc xcs_write_design_netlist { s_simset s_simulation_flow s_type s_sim_top s_launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set s_netlist_file {}

  # is behavioral?, return
  if { {behav_sim} == $s_simulation_flow } {
    return $s_netlist_file
  }

  set extn [xcs_get_netlist_extn $s_type 1]

  # generate netlist
  set net_file {}
  set sdf_filename [xcs_get_netlist_filename $s_sim_top $s_simulation_flow $s_type];append sdf_filename ".sdf"
  set sdf_file [file normalize "$s_launch_dir/$sdf_filename"]

  set netlist_cmd_args [xcs_get_netlist_writer_cmd_args $s_simset $s_type $extn]
  set sdf_cmd_args     [xcs_get_sdf_writer_cmd_args $s_simset]
  set design_mode      [get_property DESIGN_MODE [current_fileset]]

  # check run results status
  switch -regexp -- $s_simulation_flow {
    {post_synth_sim} {
      if { {RTL} == $design_mode } {
        if { [get_param "project.checkRunResultsForUnifiedSim"] } {
          set synth_run [current_run -synthesis]
          set status [get_property "STATUS" $synth_run]
          if { ([regexp -nocase {^synth_design complete} $status] != 1) } {
            send_msg_id SIM-utils-021 ERROR \
               "Synthesis results not available! Please run 'Synthesis' from the GUI or execute 'launch_runs <synth>' command from the Tcl console and retry this operation.\n"
            return $s_netlist_file
          }
        }
      }

      if { {RTL} == $design_mode } {
        set synth_run [current_run -synthesis]
        set netlist $synth_run

        # is design for the current synth run already opened in memory?
        set synth_design [get_designs -quiet $synth_run]
        if { {} != $synth_design } {
          # design already opened, set it current
          current_design $synth_design
        } else {
          if { [catch {open_run $synth_run -name $netlist} open_err] } {
            #send_msg_id SIM-utils-022 WARNING "open_run failed:$open_err"
          } else {
            current_design $netlist
          }
        }
      } elseif { {GateLvl} == $design_mode } {
        set netlist "netlist_1"

        # is design already opened in memory?
        set synth_design [get_designs -quiet $netlist]
        if { {} != $synth_design } {
          # design already opened, set it current
          current_design $synth_design
        } else {
          # open the design
          link_design -name $netlist
        }
      } else {
        send_msg_id SIM-utils-023 ERROR "Unsupported design mode found while opening the design for netlist generation!\n"
        return $s_netlist_file
      }

      set design_in_memory [current_design]
      send_msg_id SIM-utils-024 INFO "Writing simulation netlist file for design '$design_in_memory'..."

      # write netlist/sdf
      set net_file [xcs_get_netlist_file $design_in_memory $s_launch_dir $extn $s_sim_top $s_simulation_flow $s_type]
      set wv_args "-nolib $netlist_cmd_args -file \"$net_file\""
      if { {functional} == $s_type } {
        set wv_args "-mode funcsim $wv_args"
      } elseif { {timing} == $s_type } {
        set wv_args "-mode timesim $wv_args"
      }

      if { {.v} == $extn } {
        send_msg_id SIM-utils-025 INFO "write_verilog $wv_args"
        eval "write_verilog $wv_args"
      } else {
        send_msg_id SIM-utils-026 INFO "write_vhdl $wv_args"
        eval "write_vhdl $wv_args"
      }

      if { {timing} == $s_type } {
        send_msg_id SIM-utils-027 INFO "Writing SDF file..."
        set ws_args "-mode timesim $sdf_cmd_args -file \"$sdf_file\""
        send_msg_id SIM-utils-028 INFO "write_sdf $ws_args"
        eval "write_sdf $ws_args"
      }
      set s_netlist_file $net_file
    }
    {post_impl_sim} {
      set impl_run [current_run -implementation]
      set netlist $impl_run
      if { [get_param "project.checkRunResultsForUnifiedSim"] } {
        if { ![get_property can_open_results $impl_run] } {
          send_msg_id SIM-utils-029 ERROR \
             "Implementation results not available! Please run 'Implementation' from the GUI or execute 'launch_runs <impl>' command from the Tcl console and retry this operation.\n"
          return $s_netlist_file
        }
      }

      # is design for the current impl run already opened in memory?
      set impl_design [get_designs -quiet $impl_run]
      if { {} != $impl_design } {
        # design already opened, set it current
        current_design $impl_design
      } else {
        if { [catch {open_run $impl_run -name $netlist} open_err] } {
          #send_msg_id SIM-utils-030 WARNING "open_run failed:$open_err"
        } else {
          current_design $impl_run
        }
      }

      set design_in_memory [current_design]
      send_msg_id SIM-utils-031 INFO "Writing simulation netlist file for design '$design_in_memory'..."

      # write netlist/sdf
      set net_file [xcs_get_netlist_file $design_in_memory $s_launch_dir $extn $s_sim_top $s_simulation_flow $s_type]
      set wv_args "-nolib $netlist_cmd_args -file \"$net_file\""
      if { {functional} == $s_type } {
        set wv_args "-mode funcsim $wv_args"
      } elseif { {timing} == $s_type } {
        set wv_args "-mode timesim $wv_args"
      }

      if { {.v} == $extn } {
        send_msg_id SIM-utils-032 INFO "write_verilog $wv_args"
        eval "write_verilog $wv_args"
      } else {
        send_msg_id SIM-utils-033 INFO "write_vhdl $wv_args"
        eval "write_vhdl $wv_args"
      }

      if { {timing} == $s_type } {
        send_msg_id SIM-utils-034 INFO "Writing SDF file..."
        set ws_args "-mode timesim $sdf_cmd_args -file \"$sdf_file\""
        send_msg_id SIM-utils-035 INFO "write_sdf $ws_args"
        eval "write_sdf $ws_args"
      }

      set s_netlist_file $net_file
    }
  }

  if { [file exist $net_file] } {
    send_msg_id SIM-utils-036 INFO "Netlist generated:$net_file"
  }

  if { [file exist $sdf_file] } {
    send_msg_id SIM-utils-037 INFO "SDF generated:$sdf_file"
  }

  return $s_netlist_file
}

proc xcs_get_netlist_file { design_in_memory s_launch_dir extn s_sim_top s_simulation_flow s_type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set net_filename [xcs_get_netlist_filename $s_sim_top $s_simulation_flow $s_type];
  if { {.v} == $extn } {
    set netlist_extn $extn
    # contain SV construct?
    set design_prop "XLNX_REAL_CELL_SV_PINS"
    if { [lsearch -exact [list_property $design_in_memory] "$design_prop"] != -1 } {
      if { [get_property -quiet $design_prop $design_in_memory] } {
        set netlist_extn ".sv"
      }
    }
    append net_filename "$netlist_extn"
  } else {
    append net_filename "$extn"
  }
  set net_file [file normalize "$s_launch_dir/$net_filename"]
  return $net_file
}

proc xcs_fetch_ipi_static_file { src_file_obj file ipstatic_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set src_ip_file $file

  set comps [lrange [split $src_ip_file "/"] 0 end]
  set to_match "xilinx.com"
  set index 0
  set b_found [xcs_find_comp comps index $to_match]
  if { !$b_found } {
    set to_match "user_company"
    set b_found [xcs_find_comp comps index $to_match]
  }
  if { !$b_found } {
    set index -1
    set library [get_property -quiet library $src_file_obj]
    if { {} != $library } {
      set index [lsearch -exact $comps $library]
    }
    if { ({} == $library) || (-1 == $index) } {
      return $src_ip_file
    }
  }

  set file_path_str [join [lrange $comps 0 $index] "/"]
  set ip_lib_dir "$file_path_str"

  #puts ip_lib_dir=$ip_lib_dir
  set ip_lib_dir_name [file tail $ip_lib_dir]
  set target_ip_lib_dir "$ipstatic_dir/$ip_lib_dir_name"
  #puts target_ip_lib_dir=$target_ip_lib_dir

  # get the sub-dir path after "xilinx.com/xbip_utils_v3_0"
  set ip_hdl_dir [join [lrange $comps 0 $index] "/"]
  set ip_hdl_dir "$ip_hdl_dir"
  # /demo/ipshared/xilinx.com/xbip_utils_v3_0/hdl
  #puts ip_hdl_dir=$ip_hdl_dir
  incr index

  set ip_hdl_sub_dir [join [lrange $comps $index end] "/"]
  # /hdl/xbip_utils_v3_0_vh_rfs.vhd
  #puts ip_hdl_sub_dir=$ip_hdl_sub_dir

  set dst_cip_file "$target_ip_lib_dir/$ip_hdl_sub_dir"
  #puts dst_cip_file=$dst_cip_file

  # repo static file does not exist? maybe generate_target or export_ip_user_files was not executed, fall-back to project src file
  if { ![file exists $dst_cip_file] } {
    return $src_ip_file
  }

  return $dst_cip_file
}

proc xcs_fetch_ipi_static_header_file { src_file_obj file ipstatic_dir ip_repo_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # fetch verilog header files from ip_user_files/ipstatic, if param is false (old behavior)
  if { ![get_param project.includeIPStaticVHFileDirsFromRepo] } {
    return [xcs_fetch_ipi_static_file $src_file_obj $file $ipstatic_dir]
  }

  variable a_sim_cache_ip_repo_header_files

  set src_ip_file $file

  set comps [lrange [split $src_ip_file "/"] 0 end]
  set to_match "xilinx.com"
  set index 0
  set b_found [xcs_find_comp comps index $to_match]
  if { !$b_found } {
    set to_match "user_company"
    set b_found [xcs_find_comp comps index $to_match]
  }
  if { !$b_found } {
    set index -1
    set library [get_property -quiet library $src_file_obj]
    if { {} != $library } {
      set index [lsearch -exact $comps $library]
    }
    if { ({} == $library) || (-1 == $index) } {
      return $src_ip_file
    }
  }

  set file_path_str [join [lrange $comps 0 $index] "/"]
  set ip_lib_dir "$file_path_str"

  #puts ip_lib_dir=$ip_lib_dir
  set ip_lib_dir_name [file tail $ip_lib_dir]

  set dst_cip_file {}
  # find and cache ip header file from repository, if it exist
  set vh_file_name [file tail $src_ip_file]
  set repo_lib_dir "$ip_repo_dir/$ip_lib_dir_name"
  if { [file exists $repo_lib_dir] } {
    set vh_file_key "${repo_lib_dir}#$vh_file_name"
    if { [info exists a_sim_cache_ip_repo_header_files($vh_file_key)] } {
      set dst_cip_file $a_sim_cache_ip_repo_header_files($vh_file_key)
    } else {
      set dst_cip_file [xcs_get_ip_header_file_from_repo $ip_repo_dir $ip_lib_dir_name $vh_file_name]
      if { ({} != $dst_cip_file) && [file exist $dst_cip_file] } {
        set a_sim_cache_ip_repo_header_files($vh_file_key) $dst_cip_file
        return $dst_cip_file
      }
    }
  }
  if { ({} != $dst_cip_file) && [file exist $dst_cip_file] } {
    return $dst_cip_file
  }
  
  #
  # file not found from repository, calculate from ipstatic dir now
  #
  set target_ip_lib_dir "$ipstatic_dir/$ip_lib_dir_name"
  #puts target_ip_lib_dir=$target_ip_lib_dir

  # get the sub-dir path after "xilinx.com/xbip_utils_v3_0"
  set ip_hdl_dir [join [lrange $comps 0 $index] "/"]
  set ip_hdl_dir "$ip_hdl_dir"
  # /demo/ipshared/xilinx.com/xbip_utils_v3_0/hdl
  #puts ip_hdl_dir=$ip_hdl_dir
  incr index

  set ip_hdl_sub_dir [join [lrange $comps $index end] "/"]
  # /hdl/xbip_utils_v3_0_vh_rfs.vhd
  #puts ip_hdl_sub_dir=$ip_hdl_sub_dir

  set dst_cip_file "$target_ip_lib_dir/$ip_hdl_sub_dir"
  #puts dst_cip_file=$dst_cip_file

  # repo static file does not exist? maybe generate_target or export_ip_user_files was not executed, fall-back to project src file
  if { ![file exists $dst_cip_file] } {
    return $src_ip_file
  }

  return $dst_cip_file
}

proc xcs_set_simulation_flow { s_simset s_mode s_type s_flow_dir_key_arg s_simulation_flow_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $s_flow_dir_key_arg s_flow_dir_key
  upvar $s_simulation_flow_arg s_simulation_flow

  set fs_obj [get_filesets $s_simset]

  set simulation_flow {unknown}
  set type_dir        {timing}

  if { {behavioral} == $s_mode } {
    if { ({functional} == $s_type) || ({timing} == $s_type) } {
      send_msg_id SIM-utils-038 ERROR "Invalid simulation type '$s_type' specified. Please see 'launch_simulation -help' for more details.\n"
      return 1
    }

    set simulation_flow "behav_sim"
    set s_flow_dir_key "behav"

    # set simulation and netlist mode on simset
    set_property sim_mode "behavioral" $fs_obj

  } elseif { {post-synthesis} == $s_mode } {
    if { ({functional} != $s_type) && ({timing} != $s_type) } {
      send_msg_id SIM-utils-039 ERROR "Invalid simulation type '$s_type' specified. Please see 'launch_simulation -help' for more details.\n"
      return 1
    }

    set simulation_flow "post_synth_sim"
    if { {functional} == $s_type } {
      set type_dir "func"
    }
    set s_flow_dir_key "synth/${type_dir}"

    # set simulation and netlist mode on simset
    set_property sim_mode "post-synthesis" $fs_obj
    if { {functional} == $s_type } {
      set_property "NL.MODE" "funcsim" $fs_obj
    }

    if { {timing} == $s_type } {
      set_property "NL.MODE" "timesim" $fs_obj
    }
  } elseif { ({post-implementation} == $s_mode) || ({timing} == $s_mode) } {
    if { ({functional} != $s_type) && ({timing} != $s_type) } {
      send_msg_id SIM-utils-040 ERROR "Invalid simulation type '$s_type' specified. Please see 'launch_simulation -help' for more details.\n"
      return 1
    }

    set simulation_flow "post_impl_sim"
    if { {functional} == $s_type } {
      set type_dir "func"
    }
    set s_flow_dir_key "impl/${type_dir}"

    # set simulation and netlist mode on simset
    set_property sim_mode "post-implementation" $fs_obj
    if { {functional} == $s_type } {
      set_property "NL.MODE" "funcsim" $fs_obj
    }

    if { {timing} == $s_type } {
      set_property "NL.MODE" "timesim" $fs_obj
    }
  } else {
    send_msg_id SIM-utils-041 ERROR "Invalid simulation mode '$s_mode' specified. Please see 'launch_simulation -help' for more details.\n"
    return 1
  }

  set s_simulation_flow $simulation_flow

  return 0
}

proc xcs_export_data_files { export_dir dynamic_repo_dir data_files } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable l_target_simulator
  if { [llength $data_files] == 0 } { return }
  set data_files [xcs_remove_duplicate_files $data_files]
  foreach file $data_files {
    set extn [file extension $file]
    switch -- $extn {
      {.bd} -
      {.png} -
      {.c} -
      {.zip} -
      {.hwh} -
      {.hwdef} -
      {.xml} {
        if { {} != [xcs_cache_result {xcs_get_top_ip_filename $file}] } {
          continue
        }
      }
    }

    set filename [file tail $file]

    # skip bd files
    if { ([string match *_bd* $filename])        && ({.tcl} == $extn) } { continue }
    if { ([string match *_changelog* $filename]) && ({.txt} == $extn) } { continue }
    if { {.protoinst} == $extn } { continue }

    # skip mig data files
    set mig_files [list "xsim_run.sh" "ies_run.sh" "xcelium_run.sh" "vcs_run.sh" "readme.txt" "xsim_files.prj" "xsim_options.tcl" "sim.do"]
    if { [lsearch $mig_files $filename] != -1 } {continue}

    set target_file "$export_dir/[file tail $file]"

    if { ([get_param project.enableCentralSimRepo]) && ({} != $dynamic_repo_dir) } {
      set mem_init_dir [file normalize "$dynamic_repo_dir/mem_init_files"]
      set data_file [extract_files -force -no_paths -files [list "$file"] -base_dir $mem_init_dir]

      if {[catch {file copy -force $data_file $export_dir} error_msg] } {
        send_msg_id SIM-utils-042 WARNING "Failed to copy file '$data_file' to '$export_dir' : $error_msg\n"
      } else {
        send_msg_id SIM-utils-043 INFO "Exported '$target_file'\n"
      }
    } else {
      set data_file [extract_files -force -no_paths -files [list "$file"] -base_dir $export_dir]
      send_msg_id SIM-utils-044 INFO "Exported '$target_file'\n"
    }
  }
}

proc xcs_fs_contains_hdl_source { fs } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable l_valid_ip_extns
  variable l_valid_hdl_extns

  set b_contains_hdl 0
  set tokens [split [find_top -fileset $fs -return_file_paths] { }]
  for {set i 0} {$i < [llength $tokens]} {incr i} {
    set top [string trim [lindex $tokens $i]]
    incr i
    set file [string trim [lindex $tokens $i]]
    if { ({} == $top) || ({} == $file) } { continue; }
    set extn [file extension $file]

    # skip ip's
    if { [lsearch -exact $l_valid_ip_extns $extn] >= 0 } { continue; }

    # check if any HDL sources present in fileset
    if { [lsearch -exact $l_valid_hdl_extns $extn] >= 0 } {
      set b_contains_hdl 1
      break
    }
  }
  return $b_contains_hdl
}

proc xcs_get_top_library { s_simulation_flow sp_tcl_obj fs_obj src_mgmt_mode default_top_library } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable l_valid_ip_extns
  variable l_compile_order_files_uniq

  set tcl_obj $sp_tcl_obj

  set manual_compile_order  [expr {$src_mgmt_mode != "All"}]

  # was -of_objects <ip> specified?, fetch current fileset
  if { [xcs_is_ip $tcl_obj $l_valid_ip_extns] } {
    set tcl_obj $fs_obj
  }

  # 1. get the library associated with the top file from the 'top_lib' property on the fileset
  set fs_top_library [get_property "TOP_LIB" [get_filesets $tcl_obj]]

  # 2. get the library associated with the last file in compile order
  set co_top_library {}
  if { ({behav_sim} == $s_simulation_flow) } {
    set filelist $l_compile_order_files_uniq
    if { [llength $filelist] > 0 } {
      set file_list [get_files -quiet -all [list "[lindex $filelist end]"]]
      if { [llength $file_list] > 0 } {
        set co_top_library [get_property "LIBRARY" [lindex $file_list 0]]
      }
    }
  } elseif { ({post_synth_sim} == $s_simulation_flow) || ({post_impl_sim} == $s_simulation_flow) } {
    set file_list [get_files -quiet -compile_order sources -used_in synthesis_post -of_objects [get_filesets $tcl_obj]]
    if { [llength $file_list] > 0 } {
      set co_top_library [get_property "LIBRARY" [lindex $file_list end]]
    }
  }

  # 3. if default top library is set and the compile order file library is different
  #    than this default, return the compile order file library
  if { {} != $default_top_library } {
    # manual compile order, we just return the file set's top
    if { $manual_compile_order && ({} != $fs_top_library) } {
      return $fs_top_library
    }
    # compile order library is set and is different then the default
    if { ({} != $co_top_library) && ($default_top_library != $co_top_library) } {
      return $co_top_library
    } else {
      # worst case (default is set but compile order file library is empty or we failed to get the library for some reason)
      return $default_top_library
    }
  }

  # 4. default top library is empty at this point
  #    if fileset top library is set and the compile order file library is different
  #    than this default, return the compile order file library
  if { {} != $fs_top_library } {
    # manual compile order, we just return the file set's top
    if { $manual_compile_order } {
      return $fs_top_library
    }
    # compile order library is set and is different then the fileset
    if { ({} != $co_top_library) && ($fs_top_library != $co_top_library) } {
      return $co_top_library
    } else {
      # worst case (fileset library is set but compile order file library is empty or we failed to get the library for some reason)
      return $fs_top_library
    }
  }

  # 5. Both the default and fileset library are empty, return compile order library else xilinx default
  if { {} != $co_top_library } {
    return $co_top_library
  }

  return "xil_defaultlib"
}

proc xcs_export_fs_data_files { s_launch_dir dynamic_repo_dir filter } {
  # Summary: Copy fileset IP data files to output directory
  # Argument Usage:
  # Return Value:

  set data_files [list]
  foreach ip_obj [get_ips -quiet -all] {
    set data_files [concat $data_files [get_files -all -quiet -of_objects $ip_obj -filter $filter]]
  }
  set l_fs [list]
  lappend l_fs [get_filesets -filter "FILESET_TYPE == \"BlockSrcs\""]
  lappend l_fs [current_fileset -srcset]
  lappend l_fs [current_fileset -simset]
  foreach fs_obj $l_fs {
    set data_files [concat $data_files [get_files -all -quiet -of_objects $fs_obj -filter $filter]]
  }
  xcs_export_data_files $s_launch_dir $dynamic_repo_dir $data_files
}

proc xcs_prepare_ip_for_simulation { s_simulation_flow sp_tcl_obj s_launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable l_valid_ip_extns
  #if { [regexp {^post_} $s_simulation_flow] } {
  #  return
  #}
  # list of block filesets and corresponding runs to launch
  set fs_objs        [list]
  set runs_to_launch [list]
  # target object (fileset or ip)
  set target_obj $sp_tcl_obj
  if { [xcs_is_fileset $target_obj] } {
    set fs $target_obj
    # add specified fileset (expected simulation fileset)
    lappend fs_objs $fs
    # add linked source fileset
    if { {SimulationSrcs} == [get_property "FILESET_TYPE" [get_filesets $fs]] } {
      set src_set [get_property "SOURCE_SET" [get_filesets $fs]]
      if { {} != $src_set } {
        lappend fs_objs $src_set
      }
    }
    # add block filesets
    set filter "FILESET_TYPE == \"BlockSrcs\""
    foreach blk_fs_obj [get_filesets -filter $filter] {
      lappend fs_objs $blk_fs_obj
    }
    set ip_filter "FILE_TYPE == \"IP\""
    foreach fs_obj $fs_objs {
      set fs_name [get_property "NAME" [get_filesets $fs_obj]]
      send_msg_id SIM-utils-045 INFO "Inspecting fileset '$fs_name' for IP generation...\n"
      # get ip composite files
      foreach comp_file [get_files -quiet -of_objects [get_filesets $fs_obj] -filter $ip_filter] {
        xcs_generate_comp_file_for_simulation $comp_file runs_to_launch
      }
    }
    # fileset contains embedded sources? generate mem files
    if { [xcs_is_embedded_flow] } {
      send_msg_id SIM-utils-046 INFO "Design contains embedded sources, generating MEM files for simulation...\n"
      generate_mem_files $s_launch_dir
    }
  } elseif { [xcs_is_ip $target_obj $l_valid_ip_extns] } {
    set comp_file $target_obj
    xcs_generate_comp_file_for_simulation $comp_file runs_to_launch
  } else {
    send_msg_id SIM-utils-047 ERROR "Unknown target '$target_obj'!\n"
  }
  # generate functional netlist
  if { [llength $runs_to_launch] > 0 } {
    send_msg_id SIM-utils-048 INFO "Launching block-fileset run '$runs_to_launch'...\n"
    launch_runs $runs_to_launch

    foreach run $runs_to_launch {
      wait_on_run [get_property "NAME" [get_runs $run]]
    }
  }
  # update compile order
  if { {None} != [get_property "SOURCE_MGMT_MODE" [current_project]] } {
    foreach fs $fs_objs {
      if { [xcs_fs_contains_hdl_source $fs] } {
        update_compile_order -fileset [get_filesets $fs]
      }
    }
  }
}

proc xcs_get_compiler_name { simulator file_type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set compiler ""
  switch -exact -- $simulator {
    "xsim" {
      switch -exact -- $file_type {
        "VHDL"                         {set compiler "vhdl"}
        "VHDL 2008"                    {set compiler "vhdl2008"}
        "Verilog"                      -
        "Verilog Header"               -
        "Verilog/SystemVerilog Header" {set compiler "verilog"}
        "SystemVerilog"                {set compiler "sv"}
        "SystemC"                      {set compiler "xsc"}
        "CPP"                          {set compiler "xsc"}
        "C"                            {set compiler "xsc"}
      }
    }
    "modelsim" -
    "questa" {
      switch -exact -- $file_type {
        "VHDL"                         -
        "VHDL 2008"                    {set compiler "vcom"}
        "Verilog"                      -
        "Verilog Header"               -
        "Verilog/SystemVerilog Header" -
        "SystemVerilog"                {set compiler "vlog"}
        "SystemC"                      {set compiler "sccom"}
        "CPP"                          {set compiler "g++"}
        "C"                            {set compiler "gcc"}
      }
    }
    "riviera" -
    "activehdl" {
      switch -exact -- $file_type {
        "VHDL"                         -
        "VHDL 2008"                    {set compiler "vcom"}
        "Verilog"                      -
        "Verilog Header"               -
        "Verilog/SystemVerilog Header" -
        "SystemVerilog"                {set compiler "vlog"}
      }
    }
    "ies" {
      switch -exact -- $file_type {
        "VHDL"                         -
        "VHDL 2008"                    {set compiler "ncvhdl"}
        "Verilog"                      -
        "Verilog Header"               -
        "Verilog/SystemVerilog Header" -
        "SystemVerilog"                {set compiler "ncvlog"}
      }
    }
    "xcelium" {
      switch -exact -- $file_type {
        "VHDL"                         -
        "VHDL 2008"                    {set compiler "xmvhdl"}
        "Verilog"                      -
        "Verilog Header"               -
        "Verilog/SystemVerilog Header" -
        "SystemVerilog"                {set compiler "xmvlog"}
      }
    }
    "vcs" {
      switch -exact -- $file_type {
        "VHDL"                         -
        "VHDL 2008"                    {set compiler "vhdlan"}
        "Verilog"                      -
        "Verilog Header"               -
        "Verilog/SystemVerilog Header" -
        "SystemVerilog"                {set compiler "vlogan"}
        "SystemC"                      {set compiler "g++"}
        "CPP"                          {set compiler "g++"}
        "C"                            {set compiler "gcc"}
      }
    }
    default {
      send_msg_id SIM-utils-049 ERROR "Invalid simulator specified! '$simulator'\n"
    }
  }
  return $compiler
}

proc xcs_resolve_uut_name { simulator uut_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $uut_arg uut
  set uut [string map {\\ /} $uut]
  # prepend slash
  if { ![string match "/*" $uut] } {
    set uut "/$uut"
  }
  switch -exact -- $simulator {
    "xsim" {
      # remove trailing *
      if { [string match "*\*" $uut] } {
        set uut [string trimright $uut {*}]
      }
      # remove trailing /
      if { [string match "*/" $uut] } {
        set uut [string trimright $uut {/}]
      }
    }
    "modelsim" -
    "questa" {
      # append *
      if { [string match "*/" $uut] } {
        set uut "${uut}*"
      }
      # append /*
      if { {/*} != [string range $uut end-1 end] } {
        set uut "${uut}/*"
      }
    }
  }
  return $uut
}

proc xcs_generate_mem_files_for_simulation { sp_tcl_obj s_launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  if { [xcs_is_fileset $sp_tcl_obj] } {
    # fileset contains embedded sources? generate mem files
    if { [xcs_is_embedded_flow] } {
      send_msg_id SIM-utils-050 INFO "Design contains embedded sources, generating MEM files for simulation...\n"
      generate_mem_files $s_launch_dir
    }
  }
}

proc xcs_get_script_extn { simulator } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set scr_extn ".bat"
  if { {unix} == $::tcl_platform(platform) } {
    set scr_extn ".sh"
  }

  switch -exact -- $simulator {
    "ies" -
    "xcelium" -
    "vcs" {
      set scr_extn ".sh"
    }
  }
  return $scr_extn
}

proc xcs_set_sim_tcl_obj { s_comp_file s_simset sp_tcl_obj_arg s_sim_top_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $sp_tcl_obj_arg sp_tcl_obj
  upvar $s_sim_top_arg s_sim_top

  # -of_objects <full-path-to-ip-composite-file>
  if { {} != $s_comp_file } {
    set sp_tcl_obj [get_files -all -quiet [list "$s_comp_file"]]

    # get top based on composite filename
    set s_sim_top [file root [file tail $sp_tcl_obj]]

  } else {
    # specified fileset
    set sp_tcl_obj [get_filesets $s_simset]

    # set current simset if not specified
    if { {} == $sp_tcl_obj } {
      set sp_tcl_obj [current_fileset -simset]
    }

    # get the top for this fileset object
    set s_sim_top [get_property top [get_filesets $sp_tcl_obj]]
  }

  send_msg_id SIM-utils-051 INFO "Simulation object is '$sp_tcl_obj'\n"

  return 0
}

proc xcs_export_fs_non_hdl_data_files { s_simset s_launch_dir dynamic_repo_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable s_non_hdl_data_files_filter
  set data_files [list]

  foreach file_obj [get_files -all -quiet -of_objects [get_filesets $s_simset] -filter $s_non_hdl_data_files_filter] {
    if { [lsearch -exact [list_property $file_obj] {IS_USER_DISABLED}] != -1 } {
      if { [get_property {IS_USER_DISABLED} $file_obj] } {
        continue;
      }
    }
    lappend data_files $file_obj
  }
  xcs_export_data_files $s_launch_dir $dynamic_repo_dir $data_files
}

proc xcs_get_ip_header_file_from_repo { repo_dir ip_lib_dir_name vh_file_name } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set ip_vh_file {}
  set ip_dir "$repo_dir/$ip_lib_dir_name"
  set ip_xml "$ip_dir/component.xml"

  # make sure component.xml exists for the ip in repo dir
  if { ![file exists $ip_xml] } {
    return $ip_vh_file
  }
  # open xml and get the object
  set ip_comp [ipx::open_core -set_current false $ip_xml]
  if { {} == $ip_comp } {
    return $ip_vh_file
  }
  foreach file_group [ipx::get_file_groups -of $ip_comp] {
    set file_group_type [get_property type $file_group]

    # make sure we are dealing with simulation file group only
    if { ([string last "simulation" $file_group_type] != -1) && ($file_group_type != "examples_simulation") } {
      set static_sim_files [ipx::get_files -filter {USED_IN=~"*ipstatic*"} -of $file_group]
      foreach static_file $static_sim_files {
        set file_entry [split $static_file { }]
        lassign $file_entry file_key comp_ref file_group_name ip_file
        set file_type [get_property type [ipx::get_files $ip_file -of_objects $file_group]]

        set b_is_include [get_property is_include [ipx::get_files $ip_file -of_objects $file_group]]
        # make sure we are dealing with verilog type and is marked as include
        if { (({verilogSource} == $file_type) || ({systemVerilogSource} == $file_type)) && $b_is_include } {

          # make sure we are dealing with the exact header file fetched from repository for the given ip source file
          # from project (for locked IPs, the header file name could be different than in repository in which case
          # the file from ipstatic dir will be used and referenced if it exist, else will be referenced from project)

          set repo_vh_file_name [file tail $ip_file]
          if { $repo_vh_file_name == $vh_file_name } {
            set ip_vh_file "$ip_dir/$ip_file"
            return $ip_vh_file
          }
        }
      }
    }
  }
  return $ip_vh_file
}

proc xcs_get_vip_ips {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set vip_ips [list "axi_vip" "axi4stream_vip"]
  return $vip_ips
}

proc xcs_design_contain_sv_ip { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  foreach ip_obj [get_ips -all -quiet] {
    set b_requires_vip [get_property -quiet requires_vip $ip_obj]
    if { $b_requires_vip } {
      return true
    }
  }

  # fallback if property not set
  set vip_ips [xcs_get_vip_ips]
  foreach ip_obj [get_ips -all -quiet] {
    set ipdef [get_property -quiet IPDEF $ip_obj]
    set ip_name [lindex [split $ipdef ":"] 2]
    if { [lsearch -nocase $vip_ips $ip_name] != -1 } {
      return true
    }
  }
  return false
}

proc xcs_find_sv_pkg_libs { run_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_sv_pkg_libs

  set tmp_dir "$run_dir/_tmp_ip_comp_"
  set ip_comps [list]
  foreach ip [get_ips -all -quiet] {
    set ip_file [get_property ip_file $ip]
    set ip_filename [file rootname $ip_file];append ip_filename ".xml"
    if { ![file exists $ip_filename] } {
      # extract files
      set ip_file_obj [get_files -all -quiet $ip_filename]
      if { ({} != $ip_file_obj) && ([file exists $ip_file_obj]) } {
        set ip_filename [extract_files -files [list "$ip_file_obj"] -base_dir "$tmp_dir"]
      }
      if { ![file exists $ip_filename] } {
        send_msg_id SIM-utils-052 WARNING "IP component XML file does not exist: '$ip_filename'\n"
        continue;
      }
    }
    lappend ip_comps $ip_filename
  }

  foreach ip_xml $ip_comps {
    set ip_comp [ipx::open_core -set_current false $ip_xml]
    set vlnv    [get_property vlnv $ip_comp]
    foreach file_group [ipx::get_file_groups -of $ip_comp] {
      set type [get_property type $file_group]
      if { ([string last "simulation" $type] != -1) && ($type != "examples_simulation") } {
        set sub_lib_cores [get_property component_subcores $file_group]
        if { [llength $sub_lib_cores] == 0 } {
          continue
        }
        # reverse the order of sub-cores
        set ordered_sub_cores [list]
        foreach sub_vlnv $sub_lib_cores {
          set ordered_sub_cores [linsert $ordered_sub_cores 0 $sub_vlnv]
        }
        #puts "$vlnv=$ordered_sub_cores"
        foreach sub_vlnv $ordered_sub_cores {
          xcs_extract_sub_core_sv_pkg_libs $sub_vlnv
        }
        foreach static_file [ipx::get_files -filter {USED_IN=~"*ipstatic*"} -of $file_group] {
          set file_entry [split $static_file { }]
          lassign $file_entry file_key comp_ref file_group_name file_path
          set ip_file [lindex $file_entry 3]
          set file_type [get_property type [ipx::get_files $ip_file -of_objects $file_group]]
          if { {systemVerilogSource} == $file_type } {
            set library [get_property library_name [ipx::get_files $ip_file -of_objects $file_group]]
            if { ({} != $library) && ({xil_defaultlib} != $library) } {
              if { [lsearch $a_sim_sv_pkg_libs $library] == -1 } {
                lappend a_sim_sv_pkg_libs $library
              }
            }
          }
        }
      }
    }
    ipx::unload_core $ip_comp
  }

  # delete tmp dir
  if { [file exists $tmp_dir] } {
   [catch {file delete -force $tmp_dir} error_msg]
  }

  if { [get_param "project.compileXilinxVipLocalForDesign"] } {
    # find SV package libraries from the design
    set filter "FILE_TYPE == \"SystemVerilog\""
    foreach sv_file_obj [get_files -quiet -compile_order sources -used_in simulation -of_objects [current_fileset -simset] -filter $filter] {
      if { [lsearch -exact [list_property $sv_file_obj] {LIBRARY}] != -1 } {
        set library [get_property -quiet "LIBRARY" $sv_file_obj]
        if { {} != $library } {
          if { [lsearch -exact $a_sim_sv_pkg_libs $library] == -1 } {
            lappend a_sim_sv_pkg_libs $library
          }
        }
      }
    }
  }

  # add xilinx vip library
  if { [get_param "project.usePreCompiledXilinxVIPLibForSim"] } {
    if { [xcs_design_contain_sv_ip] } {
      lappend a_sim_sv_pkg_libs "xilinx_vip"
    }
  }
}

proc xcs_get_vip_include_dirs {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_sv_pkg_libs
  set incl_dir {}
  if { [llength $a_sim_sv_pkg_libs] > 0 } {
    set data_dir [rdi::get_data_dir -quiet -datafile xilinx_vip]
    set incl_dir "${data_dir}/xilinx_vip/include"
    if { [file exists $incl_dir] } {
      return $incl_dir
    }
  }
  return $incl_dir
}

proc xcs_get_xilinx_vip_files {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_sv_pkg_libs
  set xv_files [list]
  if { [llength $a_sim_sv_pkg_libs] == 0 } {
    return $xv_files
  }
  set xv_dir [file normalize "[rdi::get_data_dir -quiet -datafile "xilinx_vip"]/xilinx_vip"]
  set file "$xv_dir/xilinx_vip_pkg.list.f"
  if { ![file exists $file] } {
    send_msg_id SIM-utils-058 WARNING "File does not exist! '$file'\n"
    return $xv_files
  }
  set fh 0
  if { [catch {open $file r} fh] } {
    send_msg_id SIM-utils-058 WARNING "Failed to open file for read! '$file'\n"
    return $xv_files
  }
  set sv_file_data [split [read $fh] "\n"]
  close $fh
  foreach line $sv_file_data {
    if { [string length $line] == 0 } { continue; }
    if { [regexp {^#} $line] } { continue; }
    set file_path_str [string map {\\ /} $line]
    set replace "XILINX_VIVADO/data/xilinx_vip"
    set with "$xv_dir"
    regsub -all $replace $file_path_str $with file_path_str
    set file_path_str [string trimleft $file_path_str {$}]
    set sv_file_path [string map {\\ /} $file_path_str]
    if { [file exists $sv_file_path] } {
      lappend xv_files $sv_file_path
    }
  }
  return $xv_files
}

proc xcs_get_systemc_include_dir {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_sv_pkg_libs
  set incl_dir {}
  if { [llength $a_sim_sv_pkg_libs] > 0 } {
    set data_dir [rdi::get_data_dir -quiet -datafile "xsim/systemc"]
    set incl_dir "${data_dir}/xsim/systemc"
    if { [file exists $incl_dir] } {
      return $incl_dir
    }
  }
  return $incl_dir
}

proc xcs_extract_sub_core_sv_pkg_libs { vlnv } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_sv_pkg_libs

  set ip_def  [get_ipdefs -quiet -all -vlnv $vlnv]
  set ip_xml  [get_property xml_file_name $ip_def]
  set ip_comp [ipx::open_core -set_current false $ip_xml]

  foreach file_group [ipx::get_file_groups -of $ip_comp] {
    set type [get_property type $file_group]
    if { ([string last "simulation" $type] != -1) && ($type != "examples_simulation") } {
      set sub_lib_cores [get_property component_subcores $file_group]
      set ordered_sub_cores [list]
      foreach sub_vlnv $sub_lib_cores {
        set ordered_sub_cores [linsert $ordered_sub_cores 0 $sub_vlnv]
      }
      #puts " +$vlnv=$ordered_sub_cores"
      foreach sub_vlnv $ordered_sub_cores {
        xcs_extract_sub_core_sv_pkg_libs $sub_vlnv
      }
      foreach static_file [ipx::get_files -filter {USED_IN=~"*ipstatic*"} -of $file_group] {
        set file_entry [split $static_file { }]
        lassign $file_entry file_key comp_ref file_group_name file_path
        set ip_file [lindex $file_entry 3]
        set file_type [get_property type [ipx::get_files $ip_file -of_objects $file_group]]
        if { {systemVerilogSource} == $file_type } {
          set library [get_property library_name [ipx::get_files $ip_file -of_objects $file_group]]
          if { ({} != $library) && ({xil_defaultlib} != $library) } {
            if { [lsearch $a_sim_sv_pkg_libs $library] == -1 } {
              lappend a_sim_sv_pkg_libs $library
            }
          }
        }
      }
    }
  }
}

proc xcs_write_shell_step_fn { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:

  puts $fh "ExecStep()"
  puts $fh "\{"
  puts $fh "\"\$@\""
  puts $fh "RETVAL=\$?"
  puts $fh "if \[ \$RETVAL -ne 0 \]"
  puts $fh "then"
  puts $fh "exit \$RETVAL"
  puts $fh "fi"
  puts $fh "\}"
}

proc xcs_get_platform { fs_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set platform {}
  set os $::tcl_platform(platform)
  set b_32_bit [get_property 32bit $fs_obj]
  if { {windows} == $os } {
    set platform "win64"
    if { $b_32_bit } {
      set platform "win32"
    }
  }

  if { {unix} == $os } {
    set platform "lnx64"
    if { $b_32_bit } {
      set platform "lnx32"
    }
  }
  return $platform
}

proc xcs_xport_data_files { tcl_obj simset top launch_dir dynamic_repo_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable s_data_files_filter
  variable s_non_hdl_data_files_filter
  variable l_valid_ip_extns

  if { [xcs_is_ip $tcl_obj $l_valid_ip_extns] } {
    send_msg_id SIM-utils-053 INFO "Inspecting IP design source files for '$top'...\n"

    # export ip data files to run dir
    if { [get_param "project.copyDataFilesForSim"] } {
      set ip_filter "FILE_TYPE == \"IP\""
      set ip_name [file tail $tcl_obj]
      set data_files [list]
      set data_files [concat $data_files [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $s_data_files_filter]]

      # non-hdl data files
      foreach file [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $s_non_hdl_data_files_filter] {
        if { [lsearch -exact [list_property $file] {IS_USER_DISABLED}] != -1 } {
          if { [get_property {IS_USER_DISABLED} $file] } {
            continue;
          }
        }
        lappend data_files $file
      }
      xcs_export_data_files $launch_dir $dynamic_repo_dir $data_files
    }
  } elseif { [xcs_is_fileset $tcl_obj] } {
    send_msg_id SIM-utils-054 INFO "Inspecting design source files for '$top' in fileset '$tcl_obj'...\n"

    # export all fileset data files to run dir
    if { [get_param "project.copyDataFilesForSim"] } {
      xcs_export_fs_data_files $launch_dir $dynamic_repo_dir $s_data_files_filter
    }

    # export non-hdl data files to run dir
    xcs_export_fs_non_hdl_data_files $simset $launch_dir $dynamic_repo_dir

  } else {
    send_msg_id SIM-utils-055 INFO "Unsupported object source: $tcl_obj\n"
    return 1
  }
}

proc xcs_get_xpm_libraries {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable l_xpm_libraries
  set l_xpm_libraries [list]

  # fetch xpm libraries from project property
  set proj_obj [current_project]
  set prop_xpm_libs [get_property -quiet "XPM_LIBRARIES" $proj_obj]

  # fetch xpm libraries from design graph
  set dg_xpm_libs [auto_detect_xpm -quiet -search_ips -no_set_property]

  # join libraries and add unique to collection
  set all_xpm_libs [concat $prop_xpm_libs $dg_xpm_libs]
  if { [llength $all_xpm_libs] > 0 } {
    foreach lib $all_xpm_libs {
      if { [lsearch $l_xpm_libraries $lib] == -1 } {
        lappend l_xpm_libraries $lib
      }
    }
  }
}

proc xcs_write_tcl_wrapper { tcl_pre_hook tcl_wrapper_file run_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set proj_obj  [current_project]
  set proj_dir  [get_property directory $proj_obj]
  set proj_name [get_property name $proj_obj]

  set proj_file [file normalize [file join $proj_dir $proj_name]]
  append proj_file ".xpr"

  set file [file normalize [file join $run_dir $tcl_wrapper_file]]
  set fh 0
  if { [catch {open $file w} fh] } {
    send_msg_id SIM-utils-056 INFO "Failed to open file for write: $file\n"
    return 1
  }
  puts $fh "################################################################################"
  puts $fh "# File name: $tcl_wrapper_file"
  puts $fh "# Purpose  : This is an internal file that is auto generated by Vivado to source"
  puts $fh "#            the user tcl file."
  puts $fh "################################################################################"
  puts $fh "open_project \"$proj_file\""
  puts $fh "set rc \[catch \{"
  puts $fh "  source -notrace \"$tcl_pre_hook\""
  puts $fh "\} result\]"
  puts $fh "if \{\$rc\} \{"
  puts $fh "  puts \"\$result\""
  puts $fh "  puts \"ERROR: Script failed:\\\"$tcl_pre_hook\\\"\""
  puts $fh "\}"
  puts $fh "close_project"
  close $fh
}

proc xcs_delete_backup_log { tcl_wrapper_file dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  foreach log_file [glob -nocomplain -directory $dir ${tcl_wrapper_file}_*.backup.log] {
    [catch {file delete -force $log_file} error_msg]
  }
}

proc xcs_get_simulator_pretty_name { name } {
  # Summary:
  # Argument Usage:
  # none
  # Return Value:

  set pretty_name {}
  switch -regexp -- $name {
    "xsim"      { set pretty_name "Xilinx Vivado Simulator" }
    "modelsim"  { set pretty_name "Mentor Graphics ModelSim Simulator" }
    "questa"    { set pretty_name "Mentor Graphics Questa Advanced Simulator" }
    "ies"       { set pretty_name "Cadence Incisive Enterprise Simulator" }
    "xcelium"   { set pretty_name "Cadence Xcelium Parallel Simulator" }
    "vcs"       { set pretty_name "Synopsys Verilog Compiler Simulator" }
    "riviera"   { set pretty_name "Aldec Riviera-PRO Simulator" }
    "activehdl" { set pretty_name "Aldec Active-HDL Simulator" }
  }
  return $pretty_name
}

proc xcs_write_script_header { fh step simulator } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set curr_time    [clock format [clock seconds]]
  set version_info [split [version] "\n"]
  set release      [lindex $version_info 0]
  set swbuild      [lindex $version_info 1]
  set copyright    [lindex $version_info 3]
  set product      [lindex [split $release " "] 0]
  set version_id   [join [lrange $release 1 end] " "]
  set simulator    [xcs_get_simulator_pretty_name $simulator]
  set extn ".bat"
  set cmt  "REM"
  if {$::tcl_platform(platform) == "unix"} {
    set extn ".sh"
    set cmt  "#"
  }
  set filename "${step}${extn}"

  set desc {}
  switch -exact -- $step {
    "setup"     { set desc "Script for creating setup files and library mappings" }
    "compile"   { set desc "Script for compiling the simulation design source files" }
    "elaborate" { set desc "Script for elaborating the compiled design" }
    "simulate"  { set desc "Script for simulating the design by launching the simulator" }
  }
  puts $fh "$cmt ****************************************************************************"
  puts $fh "$cmt $product (TM) $version_id"
  puts $fh "$cmt"
  puts $fh "$cmt Filename    : $filename"  
  puts $fh "$cmt Simulator   : $simulator"
  puts $fh "$cmt Description : $desc"
  puts $fh "$cmt"
  puts $fh "$cmt Generated by $product on $curr_time"
  puts $fh "$cmt $swbuild"
  puts $fh "$cmt"
  puts $fh "$cmt $copyright"
  puts $fh "$cmt"
  puts $fh "$cmt usage: $filename"
  puts $fh "$cmt"
  puts $fh "$cmt ****************************************************************************"
}

proc xcs_glbl_dependency_for_xpm {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable l_xpm_libraries

  foreach library $l_xpm_libraries {
    foreach file [rdi::get_xpm_files -library_name $library] {
      set filebase [file root [file tail $file]]
      # xpm_cdc core has depedency on glbl
      if { {xpm_cdc} == $filebase } {
        return 1
      }
    }
  }
  return 0
}

proc xcs_get_c_incl_dirs { simulator launch_dir c_filter s_ip_user_files_dir b_xport_src_files b_absolute_path { ref_dir "true" } } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set incl_dirs [list]
  set uniq_incl_dirs [list]

  foreach file [get_files -all -quiet -filter $c_filter] {
    set file_extn [file extension $file]

    # consider header (.h) files only
    if { {.h} != $file_extn } {
      continue
    }

    set used_in_values [get_property "USED_IN" [lindex [get_files -quiet -all [list "$file"]] 0]]
    # is HLS source?
    if { [lsearch -exact $used_in_values "c_source"] != -1 } {
      continue
    }

    # fetch header file
    set sc_header_file [xcs_fetch_header_from_dynamic $file false $s_ip_user_files_dir]
    set dir [file normalize [file dirname $sc_header_file]]

    # is export_source_files? copy to local incl dir
    if { $b_xport_src_files } {
      set export_dir "$launch_dir/srcs/incl"
      if {[catch {file copy -force $sc_header_file $export_dir} error_msg] } {
        send_msg_id SIM-utils-057 INFO "Failed to copy file '$vh_file' to '$export_dir' : $error_msg\n"
      }
    }

    # make absolute
    if { $b_absolute_path } {
      set dir "[xcs_resolve_file_path $dir $launch_dir]"
    } else {
      if { $ref_dir } {
        if { $b_xport_src_files } {
          set dir "\$ref_dir/incl"
          if { ({modelsim} == $simulator) || ({questa} == $simulator) || ({riviera} == $simulator) || ({activehdl} == $simulator) } {
            set dir "srcs/incl"
          }
        } else {
          if { ({modelsim} == $simulator) || ({questa} == $simulator) || ({riviera} == $simulator) || ({activehdl} == $simulator) } {
            set dir "[xcs_get_relative_file_path $dir $launch_dir]"
          } else {
            set dir "\$ref_dir/[xcs_get_relative_file_path $dir $launch_dir]"
          }
        }
      } else {
        if { $b_xport_src_files } {
          set dir "srcs/incl"
        } else {
          set dir "[xcs_get_relative_file_path $dir $launch_dir]"
        }
      }
    }
    if { [lsearch -exact $uniq_incl_dirs $dir] == -1 } {
      lappend uniq_incl_dirs $dir
      lappend incl_dirs "$dir"
    }
  }
  return $incl_dirs
}

proc xcs_get_sc_libs {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set sc_libs [list]
  set uniq_sc_libs [list]
  # find systemc libraries from IP
  set prop_name "systemc_libraries"
  foreach ip_obj [get_ips -quiet -all] {
    foreach lib [get_property -quiet $prop_name $ip_obj] {
      if { [lsearch -exact $uniq_sc_libs $lib] == -1 } {
        lappend uniq_sc_libs $lib
        lappend sc_libs $lib
      }
    }
  }
  return $sc_libs
}

proc xcs_find_ip { name } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  foreach ip_obj [get_ips -all -quiet] {
    set ipdef [get_property -quiet IPDEF $ip_obj]
    set ip_name [lindex [split $ipdef ":"] 2]
    if { [string first $name $ip_name] != -1} {
      return true
    }
  }
  return false
}

proc xcs_get_shared_ip_libraries { clibs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set shared_ip_libs [list]
  set file [file normalize [file join $clibs_dir ".cxl.stat"]]
  if { ![file exists $file] } {
    return $shared_ip_libs
  }

  set fh 0
  if { [catch {open $file r} fh] } {
    return $shared_ip_libs
  }
  set lib_data [split [read $fh] "\n"]
  close $fh

  foreach line $lib_data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; }
    if { [regexp {^#} $line] } { continue; }
    
    set tokens [split $line {,}]
    set library [string trim [lindex $tokens 0]]
    set shared_lib_token [lindex $tokens 3]
    if { {} != $shared_lib_token } {
      set lib_tokens [split $shared_lib_token {=}]
      set is_shared_lib [string trim [lindex $lib_tokens 1]]
      if { {1} == $is_shared_lib } {
        lappend shared_ip_libs $library
      }
    }
  }
  return $shared_ip_libs
}

proc xcs_get_sc_files { sc_filter } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  set sc_files [list]
  foreach file_obj [get_files -quiet -all -filter $sc_filter] {
    if { [lsearch -exact [list_property $file_obj] {PARENT_COMPOSITE_FILE}] != -1 } {
      set comp_file [get_property parent_composite_file -quiet $file_obj]
      if { "" == $comp_file } {
        continue
      }
      set file_extn [file extension $comp_file]
      if { (".xci" == $file_extn) } {
        set ip_name [file root [file tail $comp_file]]
        set ip [get_ips -quiet -all $ip_name]
        if { "" != $ip } {
          set selected_sim_model [string tolower [get_property -quiet selected_sim_model $ip]]
          if { "tlm" == $selected_sim_model } {
            foreach ip_file_obj [get_files -quiet -all -filter $sc_filter -of_objects $ip] {
              set used_in_values [get_property "USED_IN" $ip_file_obj]
              if { [lsearch -exact $used_in_values "ipstatic"] != -1 } {
                continue;
              }
              set sc_files [concat $sc_files $ip_file_obj]
            }
          }
        }
      } elseif { (".bd" == $file_extn) } {
        lappend sc_files $file_obj
      }
    } else {
      lappend sc_files $file_obj
    }
  }
  return $sc_files
}

proc xcs_get_protoinst_files { dynamic_repo_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set b_found_in_repo false
  set repo_src_file ""
  set filter "FILE_TYPE == \"Protocol Instance\""
  set pinst_files [list]
  foreach file [get_files -quiet -all -filter $filter] {
    set file [xcs_get_file_from_repo $file $dynamic_repo_dir b_found_in_repo repo_src_file]
    if { {} != $file } {
      lappend pinst_files $file
    }
  }
  return $pinst_files
}

proc xcs_get_file_from_repo { src_file dynamic_repo_dir b_found_in_repo_arg repo_src_file_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $b_found_in_repo_arg b_found_in_repo
  upvar $repo_src_file_arg repo_src_file

  variable a_sim_cache_all_design_files_obj

  set filename [file tail $src_file]
  set file_dir [file dirname $src_file]
  set file_obj {}

  if { [info exists a_sim_cache_all_design_files_obj($src_file)] } {
    set file_obj $a_sim_cache_all_design_files_obj($src_file)
  } else {
    set file_obj [lindex [get_files -all [list "$src_file"]] 0]
  }

  set parent_comp_file [get_property -quiet parent_composite_file $file_obj]
  if { {} == $parent_comp_file } {
    return $src_file
  }
  
  set parent_comp_file_type [get_property -quiet file_type [lindex [get_files -all [list "$parent_comp_file"]] 0]]
  set core_name             [file root [file tail $parent_comp_file]]

  set ip_dir {}
  if { ({Block Designs} == $parent_comp_file_type) } {
    set top_ip_file_name {}
    set ip_dir [xcs_get_ip_output_dir_from_parent_composite $src_file top_ip_file_name]
  } else {
    return $src_file
  }
  
  set hdl_dir_file [xcs_get_sub_file_path $file_dir $ip_dir]
  set repo_src_file [file join $dynamic_repo_dir "bd" $core_name $hdl_dir_file $filename]
  if { [file exists $repo_src_file] } {
    set b_found_in_repo 1
    return $repo_src_file
  }
  return $src_file
}

proc xcs_fetch_lib_info { clibs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_cache_lib_info

  if { ![file exists $clibs_dir] } {
    return
  }

  foreach lib_dir [glob -nocomplain -directory $clibs_dir *] {
    set dat_file "$lib_dir/.cxl.lib_info.dat"
    if { ![file exists $dat_file] } { continue; }
    set fh 0
    if { [catch {open $dat_file r} fh] } { continue; }
    set lib_data [split [read $fh] "\n"]
    close $fh

    set library {}
    set type    {}
    set ldlibs  {}

    foreach line $lib_data {
      set line [string trim $line]
      if { [string length $line] == 0 } { continue; }
      if { [regexp {^#} $line] } { continue; }
      set tokens [split $line {:}]
      set tag   [lindex $tokens 0]
      set value [lindex $tokens 1]
      if { "Name" == $tag } {
        set library $value
      } elseif { "Type" == $tag } {
        set type $value
      } elseif { "Link" == $tag } {
        set ldlibs $value
      }
    }
    set array_value "$type#$ldlibs"
    set a_sim_cache_lib_info($library) $array_value
  }
}

proc xcs_get_vivado_release_version {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  # Vivado v201*.*.0 (64-bit)
  set vivado_version [lindex [split [version] "\n"] 0]
  # v201*.*.0
  set version_str [lindex [split $vivado_version " "] 1]
  # 201*.*.0
  set version_str [string trimleft $version_str {v}]
  # 201*.*
  set version [join [lrange [split $version_str {.}] 0 1] {.}]

  return $version
} 

proc xcs_find_shared_lib_paths { simulator clibs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # any library referenced in IP?
  set lib_coln [xcs_get_sc_libs]
  if { [llength $lib_coln] == 0 } {
    return
  }

  # platform and library extension
  set platform "win64"
  set extn     "dll"
  if {$::tcl_platform(platform) == "unix"} {
    set platform "lnx64"
    set extn "so"
  }
  
  # simulator, gcc version, data dir
  set sim_version [get_param "simulator.${simulator}.version"]
  set gcc_version [get_param "simulator.${simulator}.gcc.version"]
  set data_dir    [rdi::get_data_dir -quiet -datafile "simmodels/$simulator"]

  # target directory paths to search for
  set target_paths [list "$data_dir/simmodels/$simulator/$sim_version/$platform/$gcc_version/systemc/protected" \
                         "$data_dir/simmodels/$simulator/$sim_version/$platform/$gcc_version/ext" ]
  # add ip dir for xsim
  if { "xsim" == $simulator } {
    lappend target_paths "$clibs_dir/ip"
  }

  # add compiled library directory
  lappend target_paths "$clibs_dir"

  # additional linked libraries
  set linked_libs [list]

  variable a_shared_library_path_coln
  variable a_sim_cache_lib_info

  foreach library $lib_coln {
    # target shared library name to search for
    set shared_libname "lib${library}.${extn}"

    # iterate over target paths to search for this library name
    foreach path $target_paths {
      set path [file normalize $path]
      set path [regsub -all {[\[\]]} $path {/}]
      foreach lib_dir [glob -nocomplain -directory $path *] {
        if { ![file isdirectory $lib_dir] } { continue; }
        set sh_file_path "$lib_dir/$shared_libname"
        if { [file exists $sh_file_path] } {
          if { ![info exists a_shared_library_path_coln($lib_dir)] } {
            set a_shared_library_path_coln($lib_dir) $shared_libname
          }
        }

        # get any dependent libraries if any from this shared library dir
        set dat_file "$lib_dir/.cxl.lib_info.dat"
        if { ![file exists $dat_file] } { continue; }

        # any dependent library info fetched from .cxl.lib_info.dat?
        if { [info exists a_sim_cache_lib_info($library)] } {
          # "SystemC#common_cpp_v1_0,proto_v1_0"
          set values [split $a_sim_cache_lib_info($library) {#}]

          # make sure we have some data to process
          if { [llength $values] > 1 } {
            set tag  [lindex $values 0]
            set libs [split [lindex $values 1] {,}]
            if { ("SystemC" == $tag) || ("C" == $tag) || ("CPP" == $tag)} {
              if { [llength $libs] > 0 } {
                foreach lib $libs {
                  lappend linked_libs $lib
                  #send_msg_id SIM-utils-001 STATUS "Added '$lib' for processing\n"
                }
              }
            }
          }
        }
      }
    }
  }

  # find shared library paths for the linked libraries
  foreach library $linked_libs {
    # target shared library name to search for
    set shared_libname "lib${library}.${extn}"

    # iterate over target paths to search for this library name
    foreach path $target_paths {
      set path [file normalize $path]
      set path [regsub -all {[\[\]]} $path {/}]
      foreach lib_dir [glob -nocomplain -directory $path *] {
        set sh_file_path "$lib_dir/$shared_libname"
        if { [file exists $sh_file_path] } {
          if { ![info exists a_shared_library_path_coln($lib_dir)] } {
            set a_shared_library_path_coln($lib_dir) $shared_libname
          }
        }
      }
    }
  }
}
