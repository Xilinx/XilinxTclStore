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

proc xcs_compile_glbl_file { simulator b_load_glbl b_int_compile_glbl design_files s_simset s_simulation_flow s_netlist_file } {
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

  # TODO: revisit this for pure vhdl, causing failures
  #if { $b_load_glbl } {
  #  return 1
  #}

  if { $b_int_compile_glbl } {
    return 1
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

proc xcs_is_pure_verilog { b_ver b_vhd b_sc b_cpp b_c } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  # is pure verilog?
  if { $b_ver && (!$b_vhd && !$b_sc && !$b_cpp && !$b_c) } {
    return true
  }
  return false
}

proc xcs_is_pure_vhdl { b_ver b_vhd b_sc b_cpp b_c } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  # is pure VHDL?
  if { $b_vhd && (!$b_ver && !$b_sc && !$b_cpp && !$b_c) } {
    return true
  }
  return false
}

proc xcs_is_pure_systemc { b_ver b_vhd b_sc b_cpp b_c } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  # is pure systemC?
  if { $b_sc && (!$b_ver && !$b_vhd && !$cpp && !$b_c) } {
    return true
  }
  return false
}

proc xcs_is_pure_cpp { b_ver b_vhd b_sc b_cpp b_c } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  # is pure cpp?
  if { $b_cpp && (!$b_ver && !$b_vhd && !$b_sc && !$b_c) } {
    return true
  }
  return false
}

proc xcs_is_pure_c { b_ver b_vhd b_sc b_cpp b_c } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  # is pure c?
  if { $b_c && (!$b_ver && !$b_vhd && !$b_sc && !$b_cpp) } {
    return true
  }
  return false
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

proc xcs_is_pure_vhdl_design { design_files } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set b_is_vhdl 0
  foreach file $design_files {
    set type [lindex [split $file {|}] 0]
    if { {VHDL} == $type } { 
      set b_is_vhdl 1
    } else {
      set b_is_vhdl 0
      return $b_is_vhdl
    }
  }
  return $b_is_vhdl
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

proc xcs_contains_systemc_headers {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set filter  "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"SystemC Header\")"
  if { [llength [get_files -all -quiet -filter $filter]] > 0 } {
    return true
  } 
  return false
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

proc xcs_fetch_header_from_export { vh_file b_is_bd dynamic_repo_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
  #
  variable a_sim_cache_all_design_files_obj

  # get the header file object
  set vh_file_obj  {}
  if { [info exists a_sim_cache_all_design_files_obj($vh_file)] } {
    set vh_file_obj $a_sim_cache_all_design_files_obj($vh_file)
  } else {
    set vh_file_obj [lindex [get_files -all -quiet $vh_file] 0]
  }
  set ip_file ""
  # get the ip name from parent composite filename
  set props [list_property -quiet $vh_file_obj]
  if { [lsearch $props "PARENT_COMPOSITE_FILE"] != -1 } {
    set ip_file [get_property PARENT_COMPOSITE_FILE $vh_file_obj]
  } else {
    return $vh_file 
  }

  if { $ip_file eq "" } {
    return $vh_file 
  }

  # fetch the output directory from the IP this header file belongs to
  set ip_filename [file tail $ip_file]
  set ip_name     [file root $ip_filename]
  set output_dir {}
  set ip_obj [lindex [get_ips -quiet -all $ip_name] 0]
  if { "" != $ip_obj } {
    set output_dir [get_property -quiet IP_OUTPUT_DIR $ip_obj]
  } else {
    set output_dir [get_property -quiet NAME [get_files -all $ip_filename]]
    set output_dir [file dirname $output_dir]
  }
  if { [string length $output_dir] == 0 } {
    return $vh_file
  }

  # find out the extra sub-file path from the header source file wrt the output directory value,
  # and construct the output file path
  set vh_filename   [file tail $vh_file]
  set vh_file_dir   [file dirname $vh_file]
  set sub_file_path [xcs_get_sub_file_path $vh_file_dir $output_dir]

  set output_file_path "$output_dir/$sub_file_path"

  if { [regexp -nocase "sources_1/bd" $output_file_path] } {
    # traverse the path
    set dir   [string map {\\ /} $output_file_path]
    set dirs  [split $dir {/}]
    set index [lsearch $dirs "sources_1"]
    incr index
    set bd_path [join [lrange $dirs $index end] "/"]
    set ip_user_vh_file "$dynamic_repo_dir/$bd_path/$vh_filename"
    if { [file exists $ip_user_vh_file] } {
      return $ip_user_vh_file
    }
  }

  # fall-back : construct full repo dynamic file path
  set sub_dir "ip"
  if { $b_is_bd } {
    set sub_dir "bd"
  }
  set ip_user_vh_file [file join $dynamic_repo_dir $sub_dir $ip_name $sub_file_path $vh_filename]
  if { [file exists $ip_user_vh_file] } {
    return $ip_user_vh_file
  }

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
  if { [get_param "project.enableRevisedDirStructure"] } {
    set proj [get_property "NAME" [current_project]]
    set from "/${proj}.srcs/"
    set with "/${proj}.gen/"
    if { [regexp $with $src_ip_file] } {
      regsub -all $from $comp_file $with comp_file
    }
  }
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

proc xcs_find_used_in_values { src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set used_in_values [get_property "USED_IN" $src_file]
  # if only marked for synthesis but multiple files with exact duplicate file paths found in the design, then
  # check if one of these files is marked for simulation. If yes, get the correct used_in values to determine
  # if it's of type static or dynamic
  if { ([llength $used_in_values] == 1) && ("synthesis" == $used_in_values) } {
    foreach s_file_obj [get_files -quiet -all $src_file] {
      set used_in_keys [get_property -quiet "USED_IN" $s_file_obj]
      # is file marked for simulation? (returns index >= 0 if 'simulation' tag found in used_in_keys)
      # e.g used_in_keys = 'synthesis simulation ipstatic'
      if { [lsearch -exact $used_in_keys "simulation"] != -1 } {
        set used_in_values $used_in_keys
        break
      }
    }
  }
  return $used_in_values
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
      set props [list_property -quiet $file_obj]
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

proc xcs_get_noc_libs_for_netlist_sim { sim_flow s_type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set noc_libs [list]
  if { ({post_synth_sim} == $sim_flow) || ({post_impl_sim} == $sim_flow) } {
    if { {functional} == $s_type } {
      #
      # TODO: need to find out if netlist contains NoC components for the cases where design might not be instantiating NoC IP
      #
      if { {} != [xcs_find_ip "noc"] } {
        set noc_ip_libs   [list]
        set uniq_noc_libs [list]
        foreach ip_obj [get_ips -all -quiet] {
          set ipdef [get_property -quiet IPDEF $ip_obj]
          set vlnv_name [xcs_get_library_vlnv_name $ip_obj $ipdef]
          if { ([regexp {^noc_nmu} $vlnv_name]) ||
               ([regexp {^noc_nsu} $vlnv_name]) ||
               ([regexp {^noc_nps} $vlnv_name]) } {

            if { [lsearch -exact $uniq_noc_libs $vlnv_name] == -1 } {
              lappend noc_libs "$vlnv_name"
              lappend uniq_noc_libs $vlnv_name
            }
          }
        }
      }
    }
  }
  return $noc_libs
}

proc xcs_get_bin_path { tool_name path_sep } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set path_value $::env(PATH)
  set bin_path {}
  foreach path [split $path_value $path_sep] {
    set exe_file [file normalize [file join $path $tool_name]]
    #
    # make sure it exists and is of file-type and is not a directory
    #
    if { [file exists $exe_file] && [file isfile $exe_file] && ![file isdirectory $exe_file] } {
      set bin_path $path
      break
    }
  }
  return $bin_path
}

proc xcs_get_bin_paths { tool_name path_sep } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set bin_paths [list]
  set path_value $::env(PATH)
  foreach path [split $path_value $path_sep] {
    set exe_file [file normalize [file join $path $tool_name]]
    #
    # make sure it exists and is of file-type and is not a directory
    #
    if { [file exists $exe_file] && [file isfile $exe_file] && ![file isdirectory $exe_file] } {
      lappend bin_paths $path
    }
  }
  return $bin_paths
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
  if { {} == $ip_dir } {
    return $src_file
  }
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
    if { {} == $ip_dir } {
      return $src_file
    }
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
      set props [list_property -quiet $file_obj]
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

  set ip_output_dir {}
  set root_comp_file_type [get_property file_type $file_obj]
  if { ({Block Designs} == $root_comp_file_type) || ({DSP Design Sources} == $root_comp_file_type) } {
    set ip_output_dir [file dirname $comp_file]
  } else {
    set ips [get_ips -quiet -all $top_ip_name]
    if { {} == $ips } {
      return $ip_output_dir
    }
    set ip_output_dir [get_property ip_output_dir $ips]
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

  set s_file $src_file_path
  set d_file $dir_path_to_remove

  if { [get_param "project.enableRevisedDirStructure"] } {
    set proj [get_property "NAME" [current_project]]
    set from "/${proj}.srcs/"
    set with "/${proj}.gen/"
    if { [regexp $with $s_file] } {
      regsub -all $from $d_file $with d_file
    }
  }

  set src_path_comps [file split [file normalize $s_file]]
  set dir_path_comps [file split [file normalize $d_file]]

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
  set props [list_property -quiet $file_obj]
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
      set props [list_property -quiet $file_obj]
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

proc xcs_get_compiled_libraries { clibs_dir {b_int_sm_lib_ref_debug 0} } {
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

  set failed_ips [list]
  set lib_dirs [list]
  foreach line $lib_data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; }
    if { [regexp {^#} $line] } { continue; }
    
    set tokens [split $line {,}]
    set library [lindex $tokens 0]
    if { [lsearch -exact $l_libs $library] == -1 } {
      set vhd_stat [lindex [split [lindex $tokens 1] {=}] 1]
      set ver_stat [lindex [split [lindex $tokens 2] {=}] 1]
      if { ("pass" == $vhd_stat) && ("pass" == $ver_stat) } {
        lappend l_libs $library
      } else {
        if { ("fail" == $vhd_stat) || ("fail" == $ver_stat) } {
          if { $b_int_sm_lib_ref_debug } {
            lappend failed_ips $library
            lappend lib_dirs "$clibs_dir/$library"
          }
        }
      }
    }
  }

  if { $b_int_sm_lib_ref_debug } {
    set fmt {%-50s%-2s%-100s}
    set sep ":"
    puts "-------------------------------------------------------------------------------------------------------------------------------------------------------"
    puts "Pre-Compiled libraries that failed to compile:-"
    puts "-------------------------------------------------------------------------------------------------------------------------------------------------------"
    foreach ip $failed_ips lib_dir $lib_dirs {
      puts [format $fmt $ip $sep $lib_dir]
      puts "-------------------------------------------------------------------------------------------------------------------------------------------------------"
    }
    puts ""
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

proc xcs_get_libs_from_local_repo { b_pre_compile {b_int_sm_lib_ref_debug 0} } {
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

  variable a_sim_lib_info
  array unset a_sim_lib_info

  set b_libs_referenced_from_locked_ips 0
  set b_libs_referenced_from_local_repo 0

  set lib_info [list]
  set lib_dict [dict create]
  foreach ip_obj [get_ips -all -quiet] {
    if { {} == $ip_obj } { continue }
    set b_is_locked 0
    set b_is_locked [get_property -quiet is_locked $ip_obj]

    # is IP locked? fetch the referenced libraries from this IP
    if { $b_is_locked } {
      foreach file_obj [get_files -quiet -all -of_objects $ip_obj -filter {USED_IN=~"*ipstatic*"}] {
        set lib [get_property library $file_obj]
        if { {xil_defaultlib} == $lib } { continue }
        # add local library to collection
        dict append lib_dict $lib
        if { ![info exists a_sim_lib_info($lib)] } {
          set a_sim_lib_info($ip_obj#$lib) "LOCKED_IP"
        }
        if { !$b_libs_referenced_from_locked_ips } {
          set b_libs_referenced_from_locked_ips 1
        }
      }
    } else {
      #
      # IP is not locked. Is this referenced from local repository?
      #   1. get the IPDEF value of this IP and then the IP def object
      #   2. get the first repository path value from this IP def obj, if any, else continue
      #   3. is tail-end (leaf) dir name is "ip_repo"? if not, continue
      #   4. split the repository path value and search for "IP_HEAD"
      #      - if not found, use this repo path as is
      #      - else get the sub-path starting from "IP_HEAD" till end
      #   5. if install repo dir does not match with the local repo path, then
      #      get the IP object libraries from this local repo 

      # 1. **********************************************************************
      set ip_def_obj [get_ipdefs -quiet -all [get_property -quiet ipdef $ip_obj]]
      if { {} == $ip_def_obj } { continue }

      # 2. **********************************************************************
      set local_repo [lindex [get_property -quiet repository $ip_def_obj] 0]
      if { {} == $local_repo } { continue }
      set local_repo [string map {\\ /} $local_repo]

      # 3. **********************************************************************
      set ip_repo_sub_dir [file tail $local_repo]
      if { {ip_repo} != $ip_repo_sub_dir } {
        continue
      }

      # 4. **********************************************************************
      set local_comps [split $local_repo {/}]
      set index [lsearch -exact $local_comps "IP_HEAD"]
      if { $index == -1 } {
        set local_dir $local_repo
      } else {
        set local_dir [join [lrange $local_comps $index end] "/"]
      }
 
      # 5. **********************************************************************
      if { [string equal -nocase $install_dir $local_dir] != 1 } {
        foreach file_obj [get_files -quiet -all -of_objects $ip_obj -filter {USED_IN=~"*ipstatic*"}] {
          set lib [get_property library $file_obj]
          if { {xil_defaultlib} == $lib } { continue }
          # add local library to collection
          dict append lib_dict $lib
          if { ![info exists a_sim_lib_info($lib)] } {
            set a_sim_lib_info($ip_obj#$lib) "CUSTOM_IP"
          }
          if { !$b_libs_referenced_from_local_repo } {
            set b_libs_referenced_from_local_repo 1
          }
        }
      }
    }
  }

  if { ($b_libs_referenced_from_locked_ips || $b_libs_referenced_from_local_repo) && $b_pre_compile } {
    send_msg_id SIM-utils-020 INFO "The project contains locked or custom IPs. The pre-compiled version of these IPs will not be referenced and the sources from these IP libraries will be compiled locally.\n"

    if { $b_int_sm_lib_ref_debug } {
      if { [array size a_sim_lib_info] > 0 } {
        package require struct::matrix
        struct::matrix mt;
        mt add columns 3;
        set lines [list]
        puts "-------------------------------------------------------------------------------------------------------------------------------------------------------"
        puts "Pre-compiled library reference information for locked or custom IPs:-"
        puts "-------------------------------------------------------------------------------------------------------------------------------------------------------"
        lappend lines "IP LIBRARY TYPE"
        lappend lines "-------------------------------------------------------------- ------------------------------------------------------------------------------ ---------"
        foreach {key value} [array get a_sim_lib_info] {
          set ip_info [split $key {#}]
          set ip_name [lindex $ip_info 0]
          set ip_lib  [lindex $ip_info 1]
          set type    $value
          lappend lines "$ip_name $ip_lib $type"
          lappend lines "-------------------------------------------------------------- ------------------------------------------------------------------------------ ---------"
        }
        foreach line $lines {mt add row $line}
        puts [mt format 2string]
        mt destroy
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
  set ip_obj [xcs_find_ip "gt_quad_base"]
  if { {} != $ip_obj } {
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
    set design_prop "XLNX_INTEGER_CELL_SV_PINS"
    if { "1" == [get_property -quiet $design_prop $design_in_memory] } {
      set netlist_extn ".sv"
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
  foreach src_file $data_files {
    set extn [file extension $src_file]
    set filename [file tail $src_file]
    switch -- $extn {
      {.bd} -
      {.png} -
      {.c} -
      {.zip} -
      {.hwh} -
      {.hwdef} -
      {.xml} {
        if { {} != [xcs_cache_result {xcs_get_top_ip_filename $src_file}] } {
          if { [regexp {_addr_map.xml} ${filename}] } {
            # keep these files
          } else {
            continue
          }
        } else {
          # skip other c files
          if { {.c}   == $extn } { continue }
        }
      }
    }

    # skip bd files
    if { ([string match *_bd* $filename])        && ({.tcl} == $extn) } { continue }
    if { ([string match *_changelog* $filename]) && ({.txt} == $extn) } { continue }
    if { {.protoinst} == $extn } { continue }

    # skip mig data files
    set mig_files [list "xsim_run.sh" "ies_run.sh" "xcelium_run.sh" "vcs_run.sh" "readme.txt" "xsim_files.prj" "xsim_options.tcl" "sim.do"]
    if { [lsearch $mig_files $filename] != -1 } {continue}

    # skip system source files
    if { {.cpp} == $extn } { continue }

    set target_file "$export_dir/[file tail $src_file]"

    if { ([get_param project.enableCentralSimRepo]) && ({} != $dynamic_repo_dir) } {
      set mem_init_dir [file normalize "$dynamic_repo_dir/mem_init_files"]
      set data_file [extract_files -force -no_paths -files [list "$src_file"] -base_dir $mem_init_dir]

      if {[catch {file copy -force $data_file $export_dir} error_msg] } {
        send_msg_id SIM-utils-042 WARNING "Failed to copy file '$data_file' to '$export_dir' : $error_msg\n"
      } else {
        send_msg_id SIM-utils-043 INFO "Exported '$target_file'\n"
      }
    } else {
      set data_file [extract_files -force -no_paths -files [list "$src_file"] -base_dir $export_dir]
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
        "SystemC"                      {set compiler "xmsc"}
        "CPP"                          {set compiler "g++"}
        "C"                            {set compiler "gcc"}
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
        "SystemC"                      {set compiler "syscan"}
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
    if { [lsearch -exact [list_property -quiet $file_obj] {IS_USER_DISABLED}] != -1 } {
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

proc xcs_find_sv_pkg_libs { run_dir b_int_sm_lib_ref_debug } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_sv_pkg_libs

  if { $b_int_sm_lib_ref_debug } {
    puts "------------------------------------------------------------------------------------------------------------------------------------------------------"
    puts "Finding IP XML files:-"
    puts "------------------------------------------------------------------------------------------------------------------------------------------------------"
  }
  set tmp_dir "$run_dir/_tmp_ip_comp_"
  set ip_comps [list]
  foreach ip [get_ips -all -quiet] {
    set ip_name [get_property name $ip]
    set ip_file [get_property ip_file $ip]
    set ip_dir [get_property ip_output_dir -quiet $ip]
    # default ip xml file location
    set ip_filename [file rootname $ip_file];append ip_filename ".xml"
    if { [get_param "project.enableRevisedDirStructure"] } {
      set ip_filename "$ip_dir/$ip_name";append ip_filename ".xml"
    }
    
    # find from ip_output_dir
    if { ({} != $ip_dir) && [file exists $ip_dir] } {
      set ipfile [file root [file tail $ip_file]];append ipfile ".xml"
      set ipfile "$ip_dir/$ipfile"
      if { [file exists $ipfile] } {
        set ip_filename $ipfile
      } else {
        send_msg_id SIM-utils-065 WARNING "Failed to find the IP component XML file for '$ip' from IP_OUTPUT_DIR property! (file does not exist:'$ipfile')\n"
      }
    }
    
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
    } else {
      if { $b_int_sm_lib_ref_debug } {
        puts "$ip_filename"
      }
    }
    lappend ip_comps $ip_filename
  }
  if { $b_int_sm_lib_ref_debug } {
    puts "------------------------------------------------------------------------------------------------------------------------------------------------------"
  }

  if { $b_int_sm_lib_ref_debug } {
    puts "System Verilog static sources compiled into IP library:-"
  }

  foreach ip_xml $ip_comps {
    set ip_comp [ipx::open_core -set_current false $ip_xml]
    set vlnv    [get_property vlnv $ip_comp]
    foreach file_group [ipx::get_file_groups -of $ip_comp] {
      set type [get_property type $file_group]
      if { ([string last "simulation" $type] != -1) && ($type != "examples_simulation") } {
        set sub_lib_cores [get_property component_subcores $file_group]
        if { [llength $sub_lib_cores] == 0 } {
          # No sub-cores (find system verilog static sources that are compiled into IP library)
          foreach static_file [ipx::get_files -filter {USED_IN=~"*ipstatic*"} -of $file_group] {
            set file_entry [split $static_file { }]
            lassign $file_entry file_key comp_ref file_group_name file_path
            set ip_file [lindex $file_entry 3]
            set file_type [get_property type [ipx::get_files $ip_file -of_objects $file_group]]
            if { {systemVerilogSource} == $file_type } {
              set library [get_property library_name [ipx::get_files $ip_file -of_objects $file_group]]
              if { ({} != $library) && ({xil_defaultlib} != $library) } {
                if { [lsearch $a_sim_sv_pkg_libs $library] == -1 } {
                  if { $b_int_sm_lib_ref_debug } {
                    puts " + $library"
                  }
                  lappend a_sim_sv_pkg_libs $library
                }
              }
            }
          }
        }
        # reverse the order of sub-cores
        set ordered_sub_cores [list]
        foreach sub_vlnv $sub_lib_cores {
          set ordered_sub_cores [linsert $ordered_sub_cores 0 $sub_vlnv]
        }
        #puts "$vlnv=$ordered_sub_cores"
        foreach sub_vlnv $ordered_sub_cores {
          xcs_extract_sub_core_sv_pkg_libs $sub_vlnv $b_int_sm_lib_ref_debug
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
                if { $b_int_sm_lib_ref_debug } {
                  puts " + $library"
                }
                lappend a_sim_sv_pkg_libs $library
              }
            }
          }
        }
      }
    }
    ipx::unload_core $ip_comp
  }
  if { $b_int_sm_lib_ref_debug } {
    puts "------------------------------------------------------------------------------------------------------------------------------------------------------"
  }

  # delete tmp dir
  if { [file exists $tmp_dir] } {
   [catch {file delete -force $tmp_dir} error_msg]
  }

  if { [get_param "project.compileXilinxVipLocalForDesign"] } {
    # find SV package libraries from the design
    set filter "FILE_TYPE == \"SystemVerilog\""
    foreach sv_file_obj [get_files -quiet -compile_order sources -used_in simulation -of_objects [current_fileset -simset] -filter $filter] {
      if { [lsearch -exact [list_property -quiet $sv_file_obj] {LIBRARY}] != -1 } {
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
    if { {} == $data_dir } {
      if { [info exists ::env(VIVADO)] } {
        set xv $::env(VIVADO)
        if { ({} != $xv) && ([file exists $xv]) } {
          set data_dir "$xv/data"
        }
      }
    }
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
  set xv_dir [rdi::get_data_dir -quiet -datafile "xilinx_vip"]
  if { {} == $xv_dir } {
    if { [info exists ::env(VIVADO)] } {
      set xv $::env(VIVADO)
      if { ({} != $xv) && ([file exists $xv]) } {
        set xv_dir "$xv/data/xilinx_vip"
      }
    }
  } else {
    set xv_dir "$xv_dir/xilinx_vip"
  }
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

proc xcs_extract_sub_core_sv_pkg_libs { vlnv b_int_sm_lib_ref_debug } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_sv_pkg_libs
  set ip_def  [get_ipdefs -quiet -all -vlnv $vlnv]
  if { "" == $ip_def } {
    return
  }
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
        xcs_extract_sub_core_sv_pkg_libs $sub_vlnv $b_int_sm_lib_ref_debug
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
              if { $b_int_sm_lib_ref_debug } {
                puts " + $library"
              }
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

proc xcs_write_pipe_exit { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:

  puts $fh "set -Eeuo pipefail"
}

proc xcs_write_exit_code { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:

  #puts $fh "_EXIT_STAT_=\$?\nif \[ \$_EXIT_STAT_ -ne 0 \]; then exit \$_EXIT_STAT_; fi\n"
  puts $fh ""
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
        if { [lsearch -exact [list_property -quiet $file] {IS_USER_DISABLED}] != -1 } {
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
  set copyright    [lindex $version_info 2]
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

proc xcs_get_c_incl_dirs { simulator launch_dir boost_dir c_filter s_ip_user_files_dir b_xport_src_files b_absolute_path { ref_dir "true" } } {
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
    set sc_header_file [xcs_fetch_header_from_export $file true $s_ip_user_files_dir]
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

  # add boost header references for include dir
  if { ("xsim" == $simulator) || ("xcelium" == $simulator) } {
    set boost_dir "%xv_boost_lib_path%"
    if {$::tcl_platform(platform) == "unix"} {
      set boost_dir "\$xv_boost_lib_path"
    }
  }
  lappend incl_dirs "$boost_dir"

  return $incl_dirs
}

proc xcs_get_sc_libs { {b_int_sm_lib_ref_debug 0} } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # find referenced libraries from IP
  set prop_name "systemc_libraries"
  set ref_libs            [list]
  set uniq_ref_libs       [list]
  set v_ip_names          [list]
  set v_ip_defs           [list]
  set v_allowed_sim_types [list]
  set v_tlm_types         [list]
  set v_sysc_libs         [list]

  foreach ip_obj [get_ips -quiet -all] {
    if { ([lsearch -exact [list_property -quiet $ip_obj] {SYSTEMC_LIBRARIES}] != -1) && ([lsearch -exact [list_property -quiet $ip_obj] {SELECTED_SIM_MODEL}] != -1) } {
      set ip_name           [get_property -quiet name               $ip_obj]
      set ip_def            [get_property -quiet ipdef              $ip_obj]
      set allowed_sim_types [get_property -quiet allowed_sim_types  $ip_obj]
      set tlm_type          [get_property -quiet selected_sim_model $ip_obj]
      set sysc_libs         [get_property -quiet $prop_name         $ip_obj]
      set ip_def            [lindex [split $ip_def {:}] 2]
      lappend v_ip_names $ip_name;lappend v_ip_defs $ip_def;lappend v_allowed_sim_types $allowed_sim_types;lappend v_tlm_types $tlm_type;lappend v_sysc_libs $sysc_libs
      if { [string equal -nocase $tlm_type "tlm"] == 1 } {
        if { $b_int_sm_lib_ref_debug } {
          #puts " +$ip_name:$ip_def:$tlm_type:$sysc_libs"
        }
        foreach lib [get_property -quiet $prop_name $ip_obj] {
          if { [lsearch -exact $uniq_ref_libs $lib] == -1 } {
            lappend uniq_ref_libs $lib
            lappend ref_libs $lib
          }
        }
      }
    }
  }
  set fmt {%-50s%-2s%-30s%-2s%-20s%-2s%-10s%-2s%-20s}
  set sep ":"
  if { $b_int_sm_lib_ref_debug } {
    puts "-------------------------------------------------------------------------------------------------------------------------------------------------------------"
    puts " IP                                                 IPDEF                           Allowed Types         Selected    SystemC Libraries"
    puts "-------------------------------------------------------------------------------------------------------------------------------------------------------------"
    foreach name $v_ip_names def $v_ip_defs sim_type $v_allowed_sim_types tlm_type $v_tlm_types sys_lib $v_sysc_libs {
      puts [format $fmt $name $sep $def $sep $sim_type $sep $tlm_type $sep $sys_lib]
      puts "-------------------------------------------------------------------------------------------------------------------------------------------------------------"
    }
    puts "\nLibraries referenced from IP's"
    puts "------------------------------"
    foreach sc_lib $ref_libs {
      puts " + $sc_lib" 
    }
    puts "------------------------------"
  }
  return $ref_libs
}

proc xcs_find_ip { name } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set null_ip_obj {}
  foreach ip_obj [get_ips -all -quiet] {
    set ipdef [get_property -quiet IPDEF $ip_obj]
    set ip_name [lindex [split $ipdef ":"] 2]
    if { [string first $name $ip_name] != -1} {
      return $ip_obj
    }
  }
  return $null_ip_obj
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

proc xcs_get_c_files { c_filter {b_csim_compile_order 0} } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  set c_files [list]
  if { $b_csim_compile_order } {
    foreach file_obj [get_files -quiet -compile_order sources -used_in simulation -filter $c_filter -of_objects [current_fileset -simset]] {
      lappend c_files $file_obj
    }
  } else {
    foreach file_obj [get_files -quiet -all -filter $c_filter] {
      if { [lsearch -exact [list_property -quiet $file_obj] {PARENT_COMPOSITE_FILE}] != -1 } {
        set comp_file [get_property parent_composite_file -quiet $file_obj]
        if { "" == $comp_file } {
          continue
        }
        set file_extn [file extension $comp_file]
        if { (".xci" == $file_extn) } {
          xcs_add_c_files_from_xci $comp_file $c_filter c_files
        } elseif { (".bd" == $file_extn) } {
          set bd_file_name [file tail $comp_file]
          set bd_obj [get_files -quiet -all $bd_file_name]
          if { "" != $bd_obj } {
            if { [lsearch -exact [list_property -quiet $bd_obj] {PARENT_COMPOSITE_FILE}] != -1 } {
              set comp_file [get_property parent_composite_file -quiet $bd_obj]
              if { "" != $comp_file } {
                set file_extn [file extension $comp_file]
                if { (".xci" == $file_extn) } {
                  xcs_add_c_files_from_xci $comp_file $c_filter c_files
                }
              }
            } else {
              # this is top level BD for this SystemC/CPP/C file, so add it
              lappend c_files $file_obj
            }
          } else {
            # this is top level BD for this SystemC/CPP/C file, so add it
            lappend c_files $file_obj
          }
        }
      } else {
        lappend c_files $file_obj
      }
    }
  }
  return $c_files
}

proc xcs_add_c_files_from_xci { comp_file c_filter c_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $c_files_arg c_files

  set ip_name [file root [file tail $comp_file]]
  set ip [get_ips -quiet -all $ip_name]
  if { "" != $ip } {
    set selected_sim_model [string tolower [get_property -quiet selected_sim_model $ip]]
    if { "tlm" == $selected_sim_model } {
      foreach ip_file_obj [get_files -quiet -all -filter $c_filter -of_objects $ip] {
        set used_in_values [get_property "USED_IN" $ip_file_obj]
        if { [lsearch -exact $used_in_values "ipstatic"] != -1 } {
          continue;
        }
        set c_files [concat $c_files $ip_file_obj]
      }
    }
  }
}

proc xcs_contains_C_files {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set c_filter  "(USED_IN_SIMULATION == 1) && ((FILE_TYPE == \"SystemC\") || (FILE_TYPE == \"CPP\") || (FILE_TYPE == \"C\"))"
  if { [llength [get_files -quiet -all -filter $c_filter ]] > 0 } {
    return true
  }
  return false
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
    if { ![file exists $file] } {
      send_msg_id SIM-utils-060 WARNING "File does not exist:'$file'\n"
      continue
    }
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
    if { {} == $ip_dir } {
      return $src_file
    }
  } else {
    return $src_file
  }
  
  set hdl_dir_file [xcs_get_sub_file_path $file_dir $ip_dir]
  set repo_target_dir [file join $dynamic_repo_dir "bd" $core_name $hdl_dir_file]
  set repo_src_file "$repo_target_dir/$filename"

  if { [file exists $repo_src_file] } {
    set b_found_in_repo 1
    [catch {file copy -force $src_file $repo_target_dir} error_msg]
    return $repo_src_file
  }
  return $src_file
}

proc xcs_fetch_lib_info { simulator clibs_dir b_int_sm_lib_ref_debug } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_cache_lib_info
  variable a_sim_cache_lib_type_info

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

    set library     {}
    set type        {}
    set ldlibs_sysc {}
    set ldlibs_cpp  {}
    set ldlibs_c    {}

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
      } elseif { "Link_SYSTEMC" == $tag } {
        set ldlibs_sysc $value
      } elseif { "Link_CPP" == $tag } {
        set ldlibs_cpp $value
      } elseif { "Link_C" == $tag } {
        set ldlibs_c $value
      }

      # add to library type database
      if { {} != $library } {
        set a_sim_cache_lib_type_info($library) $type
      }
    }
    # SystemC#xtlm#noc_v1_0_0,common_cpp_v1_0#xyz_v1_0
    set array_value "$type#$ldlibs_sysc#$ldlibs_cpp#$ldlibs_c"

    # add the linked libraries to library type database
    xcs_add_library_type_to_database $array_value

    set a_sim_cache_lib_info($library) $array_value
  }

  # print library type information
  if { $b_int_sm_lib_ref_debug } {
    xcs_print_shared_lib_type_info
  }
}

proc xcs_add_library_type_to_database { value } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_cache_lib_type_info

  # SystemC#xtlm#noc_v1_0_0,common_cpp_v1_0#xyz_v1_0
  set values        [split $value "#"]
  set sysc_libs_str [lindex $values 1]
  set cpp_libs_str  [lindex $values 2]
  set c_libs_str    [lindex $values 3]

  set sysc_libs [split $sysc_libs_str {,}]
  foreach library $sysc_libs {
    if { "empty" == $library } { break }
    set a_sim_cache_lib_type_info($library) "SystemC"
  }
  set cpp_libs [split $cpp_libs_str {,}]
  foreach library $cpp_libs {
    if { "empty" == $library } { break }
    set a_sim_cache_lib_type_info($library) "CPP"
  }
  set c_libs [split $c_libs_str {,}]
  foreach library $c_libs {
    if { "empty" == $library } { break }
    set a_sim_cache_lib_type_info($library) "C"
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

proc xcs_find_shared_lib_paths { simulator clibs_dir custom_sm_lib_dir b_int_sm_lib_ref_debug sp_cpt_dir_arg sp_ext_dir_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $sp_cpt_dir_arg sp_cpt_dir
  upvar $sp_ext_dir_arg sp_ext_dir
 
  # any library referenced in IP?
  set lib_coln [xcs_get_sc_libs $b_int_sm_lib_ref_debug]
  if { [llength $lib_coln] == 0 } {
    return
  }

  # store library existence information (used for reporting critical warning, if shared library not found)
  # set it to false and mark it true once found from the available search paths
  variable a_ip_lib_ref_coln
  foreach sc_lib $lib_coln {
    if { ![info exists a_ip_lib_ref_coln($sc_lib)] } {
      set a_ip_lib_ref_coln($sc_lib) false
    }
  }

  # target directory paths to search for
  set target_paths [xcs_get_target_sm_paths $simulator $clibs_dir $custom_sm_lib_dir $b_int_sm_lib_ref_debug sp_cpt_dir sp_ext_dir]

  # construct target paths string
  set target_paths_str [join $target_paths "\n"]

  # additional linked libraries
  set linked_libs           [list]
  set uniq_linked_libs      [list]
  set processed_shared_libs [list]

  variable a_shared_library_path_coln
  variable a_shared_library_mapping_path_coln
  variable a_sim_cache_lib_info

  set extn "dll"
  if {$::tcl_platform(platform) == "unix"} {
    set extn "so"
  }
  
  # Iterate over the shared library collection found from the packaged IPs in the design (systemc_libraries) and
  # search for this shared library from the known paths. Also find the linked libraries that were referenced in
  # the dat file for a given library that was packaged in IP.
  foreach library $lib_coln {
    # target shared library name to search for
    set shared_libname "lib${library}.${extn}"
   
    # set protobuf static lib for xcelium
    if { ("xcelium" == $simulator) && ("protobuf" == $library) } {
      set shared_libname "lib${library}.a"
    }

    # is systemc library?
    set b_is_systemc_library [xcs_is_sc_library $library]

    if { $b_int_sm_lib_ref_debug } {
      puts "\nFinding shared library '$shared_libname'..."
    }
    # iterate over target paths to search for this library name
    foreach path $target_paths {
      #set path [file normalize $path]
      set path [regsub -all {[\[\]]} $path {/}]

      # is this shared library already processed from a given path? 
      if { [lsearch -exact $processed_shared_libs $shared_libname] != -1 } { continue; }

      if { $b_int_sm_lib_ref_debug } {
        puts " + Library search path:$path"
      }
      set lib_dir_path_found ""
      if { [get_param "project.optimizeScriptGenForSimulation"] } {
        set lib_dir "$path/$library"
        if { [file exists $lib_dir] && [file isdirectory $lib_dir] } {
          set sh_file_path "$lib_dir/$shared_libname"
          if { $b_is_systemc_library } {
            if { {questa} == $simulator } {
              set gcc_version [get_param "simulator.${simulator}.gcc.version"]
              if {$::tcl_platform(platform) == "unix"} {
                set sh_file_path "$lib_dir/_sc/linux_x86_64_gcc-${gcc_version}/systemc.so"
                if { $b_int_sm_lib_ref_debug } {
                  puts "  + Shared lib path:$sh_file_path"
                }
              }
            }
          }
  
          if { $b_int_sm_lib_ref_debug } {
            if { [file exists $sh_file_path] } {
              puts "  -----------------------------------------------------------------------------------------------------------"
              puts "  + Library found -> $sh_file_path"
              puts "  -----------------------------------------------------------------------------------------------------------"
            }
          }
  
          if { [file exists $sh_file_path] } {
            if { ![info exists a_shared_library_path_coln($shared_libname)] } {
              set a_shared_library_path_coln($shared_libname) $lib_dir
              set lib_path_dir [file dirname $lib_dir]
              set a_shared_library_mapping_path_coln($library) $lib_path_dir
              # mark library found from path
              if { [info exists a_ip_lib_ref_coln($library)] } {
                set a_ip_lib_ref_coln($library) true
              }
              if { $b_int_sm_lib_ref_debug } {
                puts "  + Added '$shared_libname:$lib_dir' to collection" 
              }
              lappend processed_shared_libs $shared_libname
              set lib_dir_path_found $lib_dir
            }
          }
        }
      } else {
        foreach lib_dir [glob -nocomplain -directory $path *] {
          if { ![file isdirectory $lib_dir] } { continue; }

          # make sure we deal with the right shared library path (library=xtlm, path=/tmp/xtlm)
          set lib_leaf_dir_name [file tail $lib_dir]
          if { $library != $lib_leaf_dir_name } {
            continue
          }
          set sh_file_path "$lib_dir/$shared_libname"
          if { $b_is_systemc_library } {
            if { {questa} == $simulator } {
              set gcc_version [get_param "simulator.${simulator}.gcc.version"]
              if {$::tcl_platform(platform) == "unix"} {
                set sh_file_path "$lib_dir/_sc/linux_x86_64_gcc-${gcc_version}/systemc.so"
                if { $b_int_sm_lib_ref_debug } {
                  puts "  + Shared lib path:$sh_file_path"
                }
              }
            }
          }
  
          if { $b_int_sm_lib_ref_debug } {
            if { [file exists $sh_file_path] } {
              puts "  -----------------------------------------------------------------------------------------------------------"
              puts "  + Library found -> $sh_file_path"
              puts "  -----------------------------------------------------------------------------------------------------------"
            }
          }
  
          if { [file exists $sh_file_path] } {
            if { ![info exists a_shared_library_path_coln($shared_libname)] } {
              set a_shared_library_path_coln($shared_libname) $lib_dir
              set lib_path_dir [file dirname $lib_dir]
              set a_shared_library_mapping_path_coln($library) $lib_path_dir
              # mark library found from path
              if { [info exists a_ip_lib_ref_coln($library)] } {
                set a_ip_lib_ref_coln($library) true
              }
              if { $b_int_sm_lib_ref_debug } {
                puts "  + Added '$shared_libname:$lib_dir' to collection"
              }
              lappend processed_shared_libs $shared_libname
              set lib_dir_path_found $lib_dir
              break;
            }
          }
        }
      }

      if { $lib_dir_path_found != "" } {
        # get any dependent libraries if any from this shared library dir
        set dat_file "$lib_dir_path_found/.cxl.lib_info.dat"
        if { [file exists $dat_file] } {
          # any dependent library info fetched from .cxl.lib_info.dat?
          if { [info exists a_sim_cache_lib_info($library)] } {
            # "SystemC#xtlm#common_cpp_v1_0,proto_v1_0#xyz_v1_0"
            set values [split $a_sim_cache_lib_info($library) {#}]
            set values_len [llength $values]
            # make sure we have some data to process
            if { $values_len > 1 } {
              set tag [lindex $values 0]

              # get the systemC linked libraries
              if { ("SystemC" == $tag) || ("C" == $tag) || ("CPP" == $tag)} {

                # process systemC linked libraries (xtlm)
                # "SystemC#xtlm#common_cpp_v1_0,proto_v1_0#xyz_v1_0"
                set libs [split [lindex $values 1] {,}]
                if { [llength $libs] > 0 } {
                  foreach lib $libs {
                    if { "empty" == $lib } { continue }
                    if { [lsearch -exact $uniq_linked_libs $lib] == -1 } {
                      # is linked library already part of search collection?
                      if { [lsearch -exact $lib_coln $lib] != -1 } {
                        if { $b_int_sm_lib_ref_debug } {
                          puts "    + Skip linked library (already in collection):$lib"
                        }
                        continue;
                      }
  
                      lappend linked_libs $lib
                      lappend uniq_linked_libs $lib
                      if { $b_int_sm_lib_ref_debug } {
                        puts "    + Added linked library:$lib"
                      }
                      #send_msg_id SIM-utils-001 STATUS "Added '$lib' for processing\n"
                    }
                  }
                }

                # process cpp linked libraries (common_cpp_v1_0,proto_v1_0)
                # "SystemC#xtlm#common_cpp_v1_0,proto_v1_0#xyz_v1_0"
                set libs [split [lindex $values 2] {,}]
                if { [llength $libs] > 0 } {
                  foreach lib $libs {
                    if { "empty" == $lib } { continue }
                    if { [lsearch -exact $uniq_linked_libs $lib] == -1 } {
                      # is linked library already part of search collection?
                      if { [lsearch -exact $lib_coln $lib] != -1 } {
                        if { $b_int_sm_lib_ref_debug } {
                          puts "    + Skip linked library (already in collection):$lib"
                        }
                        continue;
                      }
  
                      lappend linked_libs $lib
                      lappend uniq_linked_libs $lib
                      if { $b_int_sm_lib_ref_debug } {
                        puts "    + Added linked library:$lib"
                      }
                      #send_msg_id SIM-utils-001 STATUS "Added '$lib' for processing\n"
                    }
                  }
                }

                # process C linked libraries (xyz_v1_0)
                # "SystemC#xtlm#common_cpp_v1_0,proto_v1_0#xyz_v1_0"
                set libs [split [lindex $values 3] {,}]
                if { [llength $libs] > 0 } {
                  foreach lib $libs {
                    if { "empty" == $lib } { continue }
                    if { [lsearch -exact $uniq_linked_libs $lib] == -1 } {
                      # is linked library already part of search collection?
                      if { [lsearch -exact $lib_coln $lib] != -1 } {
                        if { $b_int_sm_lib_ref_debug } {
                          puts "    + Skip linked library (already in collection):$lib"
                        }
                        continue;
                      }
  
                      lappend linked_libs $lib
                      lappend uniq_linked_libs $lib
                      if { $b_int_sm_lib_ref_debug } {
                        puts "    + Added linked library:$lib"
                      }
                      #send_msg_id SIM-utils-001 STATUS "Added '$lib' for processing\n"
                    }
                  }
                }
              }
            }
          }
        } else {
          if { ("protobuf" == $library) } {
            # pre-compiled libraries that don't have dat file
          } else {
            if { $b_int_sm_lib_ref_debug } {
              puts "    + error: file does not exist '$dat_file'"
            }
            send_msg_id SIM-utils-064 ERROR "The data information file for the '$library' library does not exist! '$dat_file' (this file is generated by compile_simlib tcl command). Please check if compilation errors were reported in compile_simlib.log file.\n"
          }
        }
      }
    }
  }

  if { $b_int_sm_lib_ref_debug } {
    puts "\nProcessing linked libraries..."
  }
  # find shared library paths for the linked libraries
  foreach library $linked_libs {
    # is systemc library?
    set b_is_systemc_library [xcs_is_sc_library $library]

    # target shared library name to search for
    set shared_libname "lib${library}.${extn}"
    if { $b_int_sm_lib_ref_debug } {
      puts " + Finding linked shared library:$shared_libname"
    }
    # iterate over target paths to search for this library name
    foreach path $target_paths {
      #set path [file normalize $path]
      set path [regsub -all {[\[\]]} $path {/}]
      foreach lib_dir [glob -nocomplain -directory $path *] {
        set sh_file_path "$lib_dir/$shared_libname"
        if { $b_is_systemc_library } {
          if { {questa} == $simulator } {
            set gcc_version [get_param "simulator.${simulator}.gcc.version"]
            if {$::tcl_platform(platform) == "unix"} {
              set sh_file_path "$lib_dir/_sc/linux_x86_64_gcc-${gcc_version}/systemc.so"
            }
          }
        }

        if { [file exists $sh_file_path] } {
          if { ![info exists a_shared_library_path_coln($shared_libname)] } {
            set a_shared_library_path_coln($shared_libname) $lib_dir
            set lib_path_dir [file dirname $lib_dir]
            set a_shared_library_mapping_path_coln($library) $lib_path_dir
            # mark library found from path
            if { [info exists a_ip_lib_ref_coln($library)] } {
              set a_ip_lib_ref_coln($library) true
            }
            if { $b_int_sm_lib_ref_debug } {
              puts "  + Library found -> $sh_file_path"
              puts "  + Added '$shared_libname:$lib_dir' to collection" 
            }
          }
        }
      }
    }
  }

  # print critical warning for missing libraries
  foreach {key value} [array get a_ip_lib_ref_coln] {
    set ip_lib_name  $key
    set ip_lib_found $value
    if { {false} == $ip_lib_found } {
      send_msg_id SIM-utils-061 "CRITICAL WARNING" "Failed to find the pre-compiled library for '$ip_lib_name' IP from the following search paths:-\n"
      foreach tp $target_paths {
        send_msg_id SIM-utils-062 STATUS "  '$tp'"
      }
      send_msg_id SIM-utils-063 STATUS "Please verify if this is a valid IP name ('$ip_lib_name') or was compiled successfully and the shared library for this IP exist in the search paths."
    }
  }


  # print extracted shared library information
  if { $b_int_sm_lib_ref_debug } {
    xcs_print_shared_lib_info
  }
}

proc xsc_get_simmodel_compile_order { } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_shared_library_path_coln 

  set sm_order [list]

  # get simmodel list referenced in the design
  set lib_names [list]
  foreach {key value} [array get a_shared_library_path_coln] {
    set shared_lib_name $key
    set lib_name [file root $shared_lib_name]
    set lib_name [string trimleft $lib_name {lib}]
    lappend lib_names $lib_name
  }

  # find compile order and construct order for the simmodels referenced in the design
  set compile_order_file [xcs_get_path_from_data "systemc/simlibs/compile_order.dat"]
  set fh 0
  if { [catch {open $compile_order_file r} fh] } {
    send_msg_id SIM-utils-068 WARNING "Failed to open file for read! '$compile_order_file'\n"
    return $sm_order
  }
  set data [split [read $fh] "\n"]
  close $fh
  foreach line $data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; }
    if { [regexp {^#} $line] } { continue; }
    set lib_name $line
    if { {xtlm} == $lib_name } {
      set index [lsearch -exact $lib_names $lib_name]
    } else {
      set index [lsearch -regexp $lib_names $lib_name]
    }
    if { {-1} != $index } {
      set sm_lib [lindex $lib_names $index]
      lappend sm_order $sm_lib
    }
  }
  return $sm_order
} 

proc xsc_find_lib_path_for_simmodel { simmodel } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_shared_library_path_coln 
  set lib_path {}
  foreach {key value} [array get a_shared_library_path_coln] {
    set shared_lib_name $key
    set lib_name [file root $shared_lib_name]
    set lib_name [string trimleft $lib_name {lib}]
    if { $simmodel == $lib_name } {
      set lib_path $value
      return $lib_path
    }
  }
}

proc xsc_find_dependent_simmodel_libraries { library sysc_dep_libs_arg cpp_dep_libs_arg c_dep_libs_arg  } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_cache_lib_info

  upvar $sysc_dep_libs_arg sysc_dep_libs
  upvar $cpp_dep_libs_arg  cpp_dep_libs
  upvar $c_dep_libs_arg    c_dep_libs

  # any dependent library info fetched from .cxl.lib_info.dat?
  if { [info exists a_sim_cache_lib_info($library)] } {
    # SystemC#empty#common_cpp_v1_0#empty
    set values    [split $a_sim_cache_lib_info($library) {#}]
  
    set lib_type  [lindex $values 0];# SystemC, CPP, C
    set sysc_libs [lindex $values 1];# empty or list of systemc dep libs
    set cpp_libs  [lindex $values 2];# empty or list of cpp dep libs
    set c_libs    [lindex $values 3];# empty or list of c dep libs
  
    if { "empty" != $sysc_libs } { set sysc_dep_libs [split $sysc_libs ","] }
    if { "empty" != $cpp_libs  } { set cpp_dep_libs  [split $cpp_libs  ","] }
    if { "empty" != $c_libs    } { set c_dep_libs    [split $c_libs    ","] }
  }
}

proc xcs_is_sc_library { library } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_sim_cache_lib_type_info
  if { {} == $library } {
    return 0
  }

  if { [info exists a_sim_cache_lib_type_info($library)] } {
    if { "SystemC" == $a_sim_cache_lib_type_info($library) } {
      return 1
    }
  }
  return 0
}

proc xcs_is_cpp_library { library } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_sim_cache_lib_type_info
  if { {} == $library } {
    return 0
  }

  if { [info exists a_sim_cache_lib_type_info($library)] } {
    if { "CPP" == $a_sim_cache_lib_type_info($library) } {
      return 1
    }
  }
  return 0
}

proc xcs_is_c_library { library } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_sim_cache_lib_type_info
  if { {} == $library } {
    return 0
  }

  if { [info exists a_sim_cache_lib_type_info($library)] } {
    if { "C" == $a_sim_cache_lib_type_info($library) } {
      return 1
    }
  }
  return 0
}

proc xcs_get_target_sm_paths { simulator clibs_dir custom_sm_lib_dir b_int_sm_lib_ref_debug sp_cpt_dir_arg sp_ext_dir_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $sp_cpt_dir_arg sp_cpt_dir
  upvar $sp_ext_dir_arg sp_ext_dir

  set target_paths [list]

  set sm_cpt_dir [xcs_get_simmodel_dir $simulator "cpt"]
  if { $b_int_sm_lib_ref_debug } {
    puts "(DEBUG) - simmodel protected sub-dir: $sm_cpt_dir"
  }
  set cpt_dir [rdi::get_data_dir -quiet -datafile "simmodels/$simulator"]
  # is custom protected sim-model path specified?
  set param "simulator.customSimModelRootDir"
  set custom_cpt_dir ""
  [catch {set custom_cpt_dir [get_param $param]} err]
  if { {} != $custom_cpt_dir } {
    if { [file exists $custom_cpt_dir] } {
      set custom_dir "$custom_cpt_dir/data"
      if { [file exists $custom_dir] } {
        set cpt_dir $custom_dir
      }
    } else {
      send_msg_id SIM-utils-066 WARNING "The path specified with the '$param' does not exist! Using libraries from default install location.\n"
    }
  }

  # default protected dir
  set tp "$cpt_dir/$sm_cpt_dir"
  if { $b_int_sm_lib_ref_debug } {
    puts "(DEBUG) - protected (default) : $tp"
  }
  if { ([file exists $tp]) && ([file isdirectory $tp]) } {
    lappend target_paths $tp
  } else {
    # fallback
    if { "xsim" == $simulator } {
      set tp [file dirname $clibs_dir]
      set tp "$tp/$sm_cpt_dir"
      if { ([file exists $tp]) && ([file isdirectory $tp]) } {
        if { $b_int_sm_lib_ref_debug } {
          puts "(DEBUG) - protected (fallback): $tp"
        }
        lappend target_paths $tp
      }
    }
  }

  set sp_cpt_dir $tp

  # default ext dir
  set sm_ext_dir [xcs_get_simmodel_dir $simulator "ext"]
  lappend target_paths "$cpt_dir/$sm_ext_dir"

  set sp_ext_dir "$cpt_dir/$sm_ext_dir"
  if { $b_int_sm_lib_ref_debug } {
    puts "(DEBUG) - protected ext path (default): $sp_ext_dir"
  }

  # add ext utils dir for xcelium static library
  if { "xcelium" == $simulator } {
    lappend target_paths "$cpt_dir/$sm_ext_dir/utils"
  }

  # add ip dir for xsim
  if { "xsim" == $simulator } {
    lappend target_paths "$clibs_dir/ip"
  }

  # prepend custom simmodel library paths, if specified? 
  set sm_lib_path $custom_sm_lib_dir
  if { $sm_lib_path != "" } {
    set custom_paths [list]
    foreach cpath [split $sm_lib_path ":"] {
      if { ($cpath != "") && ([file exists $cpath]) && ([file isdirectory $cpath]) } {
        lappend custom_paths $cpath
      }
    }
    if { [llength $custom_paths] > 0 } {
      set target_paths [concat $custom_paths $target_paths]
    }
  }

  # add compiled library directory
  lappend target_paths "$clibs_dir"

  if { $b_int_sm_lib_ref_debug } {
    puts "-----------------------------------------------------------------------------------------------------------"
    puts "Target paths to search"
    puts "-----------------------------------------------------------------------------------------------------------"
    foreach target_path $target_paths {
      puts "Path: $target_path"
    }
    puts "-----------------------------------------------------------------------------------------------------------"
  }

  return $target_paths
}

proc xcs_print_shared_lib_info { } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_shared_library_path_coln
  set fmt {%-25s%-2s%-80s}
  set sep ":"
  set libs [list]
  set dirs [list]
  foreach {library lib_dir} [array get a_shared_library_path_coln] {
    lappend libs $library
    lappend dirs $lib_dir
  }
  puts "-----------------------------------------------------------------------------------------------------------"
  puts "Extracted shared library path information"
  puts "-----------------------------------------------------------------------------------------------------------"
  foreach lib $libs dir $dirs {
    puts [format $fmt $lib $sep $dir]
  }
  puts "-----------------------------------------------------------------------------------------------------------"
}

proc xcs_print_shared_lib_type_info { } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_cache_lib_type_info
  set fmt {%-50s%-2s%-10s}
  set sep ":"
  set libs [list]
  set types [list]
  foreach {library type} [array get a_sim_cache_lib_type_info] {
    lappend libs $library
    lappend types $type
  }
  puts "--------------------------------------------------------------------"
  puts "Shared libraries:-"
  puts "--------------------------------------------------------------------"
  puts " LIBRARY                                            TYPE"
  puts "--------------------------------------------------------------------"
  foreach lib $libs type $types {
    puts [format $fmt $lib $sep $type]
    puts "--------------------------------------------------------------------"
  }
  puts ""
}

proc xcs_get_simmodel_dir { simulator type } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
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

  # prefix path
  set prefix_dir "simmodels/${simulator}/${sim_version}/${platform}/${gcc_version}"

  # construct path
  set dir {}
  if { "cpt" == $type } {
    set dir "${prefix_dir}/systemc/protected"
  } elseif { "ext" == $type } {
    set dir "${prefix_dir}/ext"
  }
  return $dir
}

proc xcs_resolve_sim_lib_dir { sim_dir src_lib_dir_arg b_cxl_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $b_cxl_arg b_cxl

  # initialize flag
  set b_cxl 0

  # default full path
  set sub_lib_path $src_lib_dir_arg
  
  # is sim dir empty? return default full path
  if { "" == $sim_dir } {
    return $sub_lib_path
  }

  # normalize and split into sub-dirs
  set sim_sub_dirs  [file split [file normalize $sim_dir]]
  set path_sub_dirs [file split [file normalize $sub_lib_path]]

  # sub-dirs length
  set sim_len [llength $sim_sub_dirs]
  set path_len [llength $path_sub_dirs]

  # if sim_dir path equal to or greater than the lib path, no need to resolve
  if { ($sim_len == $path_len) || ($sim_len > $path_len) } {
    return $sub_lib_path
  }

  # increment index for each sub-dir match till end of sim sub-dir
  set index 0
  set b_found_match 0
  while { [lindex $sim_sub_dirs $index] == [lindex $path_sub_dirs $index] } {
    incr index
    # index matches with sim sub-dir length (got exact match of all sim sub-dirs)
    if { $index == $sim_len } {
      set b_found_match 1
      break
    }
  }
 
  # if exact match found, set the remaining library directory path and return it, else return default library path
  if { $b_found_match } {
    set sub_lib_path [join [lrange $path_sub_dirs $index end] "/"]
    set b_cxl 1
  }
  return $sub_lib_path
}

proc xcs_resolve_sim_model_dir { simulator lib_path clib_dir cpt_dir ext_dir b_resolved_arg b_compile_simmodels context } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $b_resolved_arg b_resolved
  
  set b_resolved 0
  set resolved_path {}

  set sub_lib_path [xcs_resolve_sim_lib_dir $clib_dir $lib_path b_resolved]
  if { $b_resolved } {
    if {$::tcl_platform(platform) == "unix"} {
      set resolved_path "\$xv_cxl_lib_path/$sub_lib_path"
      if { $b_compile_simmodels } {
        switch $simulator {
          {xsim} {
            switch $context {
              "obj" {
                if { [string match "ip/*" $sub_lib_path] } {
                  set dirs [split $sub_lib_path {/}]
                  set sub_lib_path [join [lrange $dirs 1 end] "/"]
                }
                set resolved_path "\$xv_cxl_obj_lib_path/$sub_lib_path"
              }
              "include" {
                if { [string match "ip/*" $sub_lib_path] } {
                  set dirs [split $sub_lib_path {/}]
                  set sub_lib_path [join [lrange $dirs 1 end] "/"]
                }
                set resolved_path "\$xv_cxl_lib_path/$sub_lib_path"
              }
            }
          }
        }
      }
    } else {
      set resolved_path "%xv_cxl_lib_path%/$sub_lib_path"
    }
  } else {
    set sub_lib_path [xcs_resolve_sim_lib_dir $cpt_dir $lib_path b_resolved]
    if { $b_resolved } {
      if {$::tcl_platform(platform) == "unix"} {
        set resolved_path "\$xv_cpt_lib_path/$sub_lib_path"
      } else {
        set resolved_path "%xv_cpt_lib_path%/$sub_lib_path"
      }
    } else {
      set sub_lib_path [xcs_resolve_sim_lib_dir $ext_dir $lib_path b_resolved]
      if { $b_resolved } {
        if {$::tcl_platform(platform) == "unix"} {
          set resolved_path "\$xv_ext_lib_path/$sub_lib_path"
        } else {
          set resolved_path "%xv_ext_lib_path%/$sub_lib_path"
        }
      }
    }
  }
  return $resolved_path
}

proc xcs_get_library_vlnv_name { ip_def vlnv } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set library_name {}
  if { ({} == $ip_def) || ({} == $vlnv) } {
    return $library_name
  }

  set values     [split $vlnv {:}]
  set ip_name    [lindex $values 2]
  set rel_ver    [lindex $values 3]

  set rel_values [split $rel_ver {.}]
  set sw_rev     [lindex $rel_values 0]
  set minor_rev  [lindex $rel_values 1]

  set core_rev [get_property -quiet core_revision $ip_def]
  set library_name ${ip_name}_v${sw_rev}_${minor_rev}_${core_rev}

  return $library_name
}

proc xcs_get_boost_library_path {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set boost_incl_dir {}
  set sep ";"
  if {$::tcl_platform(platform) == "unix"} {
    set sep ":"
  }

  if { [info exists ::env(RDI_DATADIR)] } {
    foreach data_dir [split $::env(RDI_DATADIR) $sep] {
      set incl_dir "[file dirname $data_dir]/tps/boost_1_64_0"
      if { [file exists $incl_dir] } {
        set boost_incl_dir $incl_dir
        set boost_incl_dir [regsub -all {[\[\]]} $boost_incl_dir {/}]
        break
      }
    }
  } else {
    send_msg_id SIM-utils-059 WARNING "Failed to get the boost library path (RDI_DATADIR environment variable is not set).\n"
  }
  return $boost_incl_dir
}

proc xcs_get_pre_compiled_shared_objects { simulator clibs_dir vlnv } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set obj_file_paths [list]
  set obj_dir "$clibs_dir/$vlnv"
  if { "vcs" == $simulator } {
    append obj_dir "/sysc"
  }
  foreach obj_file [glob -nocomplain -directory $obj_dir *.o] {
    if { "vcs" == $simulator } {
      set file_name [file root [file tail $obj_file]]
      if { "_stublist" == $file_name } { continue }
    }
    lappend obj_file_paths $obj_file
  }
  
  return $obj_file_paths
}

proc xcs_find_uvm_library { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set uvm_lib_path {}
  set sep ";"
  if {$::tcl_platform(platform) == "unix"} {
    set sep ":"
  }

  if { [info exists ::env(RDI_DATADIR)] } {
    foreach data_dir [split $::env(RDI_DATADIR) $sep] {
      set path "$data_dir/xsim/system_verilog/uvm"
      if { [file exists $path] } {
        set uvm_lib_path $path
        break;
      }
    }
  } else {
    send_msg_id SIM-utils-067 WARNING "Failed to get the uvm library path (RDI_DATADIR environment variable is not set).\n"
  }
  return $uvm_lib_path
}

proc xcs_get_gcc_path { simulator sim_product_name simulator_install_path gcc_install_path gcc_path_arg path_type_arg b_int_sm_lib_ref_debug } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # not required for xsim
  if { "xsim" == $simulator } {
    return true
  }

  upvar $gcc_path_arg gcc_path
  upvar $path_type_arg path_type
  set gcc_path      {}
  set path_type     0
  set resolved_path {}

  # gcc precedence (switch -> property -> PATH (info))

  # 1. if switch specified, use this path
  if { [llength $gcc_install_path] > 0 } {
    if { [xcs_check_gcc_path $gcc_install_path resolved_path] } {
      set gcc_path $resolved_path
      set path_type 1
      return true
    } else {
      [catch {send_msg_id SIM-utils-069 ERROR "GCC compiler path specified with the '-gcc_install_path' switch is either invalid or does not exist! '$gcc_install_path'\n"} err]
      return false
    }
  }

  # 2. if property specified, use this path
  set gcc_prop_dir [get_property -quiet simulator.${simulator}_gcc_install_dir [current_project]]
  if { [llength $gcc_prop_dir] > 0 } {
    if { [xcs_check_gcc_path $gcc_prop_dir resolved_path] } {
      set gcc_path $resolved_path
      set path_type 2
      return true
    } else {
      [catch {send_msg_id SIM-utils-069 ERROR "GCC compiler path specified for the 'simulator.${simulator}_gcc_install_dir' property is either invalid or does not exist! '$gcc_prop_dir'\n"} err]
      return false;
    }
  }

  # 3. if env specified, use this path
  if { [info exists ::env(GCC_SIM_EXE_PATH)] } {
    set gcc_env_dir $::env(GCC_SIM_EXE_PATH)
    if { [llength $gcc_env_dir] > 0 } {
      if { [xcs_check_gcc_path $gcc_env_dir resolved_path] } {
        set gcc_path $resolved_path
        set path_type 3
        return true
      } else {
        [catch {send_msg_id SIM-utils-069 ERROR "GCC compiler path specified with the 'GCC_SIM_EXE_PATH' path environment variable is either invalid or does not exist! '$gcc_env_dir'\n"} err]
        return false;
      }
    }
  }

  set tool_extn {.exe}
  if {$::tcl_platform(platform) == "unix"} {
    set tool_extn {}
  }
  set tool "gcc${tool_extn}"

  # 4. find from simulator install area
  if { {} != $simulator_install_path } {
    set sim_root_dir $simulator_install_path
    set gcc_version  [get_param "simulator.${simulator}.gcc.version"]
    if { {} != $gcc_version } {
      switch $simulator {
        {questa} {
          # fetch tool install dir
          if {$::tcl_platform(platform) == "unix"} {
            set sim_root_dir [file dirname $sim_root_dir]
            # gcc sub-dir wrt install dir
            set gcc_sub_dir  "gcc-${gcc_version}-linux_x86_64/bin"
            set gcc_root_dir "$sim_root_dir/$gcc_sub_dir"
            if { [file exists $gcc_root_dir] } {
              set gcc_exe_file "$gcc_root_dir/$tool" 
              if { ([file exists $gcc_exe_file]) && ([file isfile $gcc_exe_file]) && (![file isdirectory $gcc_exe_file]) } {
                set gcc_path $gcc_root_dir
                set path_type 4
                return true
              }
            }
          }
        }
        {xcelium} {
          # fetch tool install dir
          set sim_root_dir [file dirname $sim_root_dir]
          set sim_root_dir [file dirname $sim_root_dir]
          set sim_root_dir [file dirname $sim_root_dir]
          # gcc sub-dir wrt install dir
          set gcc_sub_dir  "tools/cdsgcc/gcc/${gcc_version}/bin"
          set gcc_root_dir "$sim_root_dir/$gcc_sub_dir"
          if { [file exists $gcc_root_dir] } {
            set gcc_exe_file "$gcc_root_dir/$tool" 
            if { ([file exists $gcc_exe_file]) && ([file isfile $gcc_exe_file]) && (![file isdirectory $gcc_exe_file]) } {
              set gcc_path $gcc_root_dir
              set path_type 4
              return true
            }
          }
        }
      }
    }
  }

  # 5. critical warning (not found from property neither from switch)
  set sim_ver_param "simulator.${simulator}.version"
  set sim_ver [get_param $sim_ver_param]
  send_msg_id SIM-utils-070 "CRITICAL WARNING" "Failed to locate the GNU compiler (g++/gcc) executable path! Please set the path using the -gcc_install_path switch or by setting the simulator.${simulator}_gcc_install_dir project property or by setting the GCC_SIM_EXE_PATH environment variable. Please see 'launch_simulation -help' for more details on setting the path and the recommended GCC version that is applicable for the $sim_product_name $sim_ver simulator version for the current Vivado release.\n"
 
  if { $b_int_sm_lib_ref_debug } {
    set path_sep {;}
    if {$::tcl_platform(platform) == "unix"} { set path_sep {:} }
    set gcc_paths [xcs_get_bin_paths $tool $path_sep]
    if { [llength $gcc_paths] > 0 } {
      puts "---------------------------------------------------------------------"
      puts "GCC compiler path(s) currently set with the PATH environment variable"
      puts "---------------------------------------------------------------------"
      foreach path $gcc_paths {
        puts " <GCC PATH> - $path"
      }
      puts "---------------------------------------------------------------------"
    }
  }
  return false;
}

proc xcs_check_gcc_path { path resolved_path_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $resolved_path_arg resolved_path

  set gcc_path $path
  # setup gcc exe names based on platform
  set tool_extn {.exe}
  if {$::tcl_platform(platform) == "unix"} {
    set tool_extn {}
  }
  set gcc_exe_name   "gcc${tool_extn}"
  set gplus_exe_name "g++${tool_extn}"

  # 1. fix/trim slashes
  set gcc_path [regsub -all {[\[\]]} $gcc_path {/}];
  set gcc_path [string trimright $gcc_path {/}]

  # 2. path does not exist
  if { ![file exists $gcc_path] } {
    return false
  }

  # 3. check last element in path - is /install/bin/gcc or /install/bin/g++?
  set last_element [file tail $gcc_path]
  if { ($last_element == $gcc_exe_name) || ($last_element == $gplus_exe_name) } {
    # get parent dir -> /install/bin
    set gcc_path [file dirname $gcc_path]
  } else {
    # /install/bin
    # add exe name to make sure this is the correct gcc path
    set exe_path "$gcc_path/$gcc_exe_name"
    if { ![file exists $exe_path] } {
      # invalid path - does not point to gcc install dir
      return false
    }
  }
  set resolved_path $gcc_path
  return true
}

proc xcs_get_design_libs { files {b_realign 0} } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set uniq_libs [list]
  set b_contains_default_lib 0

  foreach file $files {
    set fargs     [split $file {|}]
    set type      [lindex $fargs 0]
    set file_type [lindex $fargs 1]
    set library   [lindex $fargs 2]
    if { {} == $library } {
      continue;
    }

    # contains default lib and needs realignment?
    if { $b_realign } {
      if { {xil_defaultlib} == $library } {
        set b_contains_default_lib 1
        continue;
      }
    }

    # add unique library to collection
    if { [lsearch -exact $uniq_libs $library] == -1 } {
      lappend uniq_libs $library
    }
  }

  # insert default library at the beginning
  if { $b_realign } {
    if { $b_contains_default_lib } {
      set uniq_libs [linsert $uniq_libs 0 "xil_defaultlib"]
    }
  }

  return $uniq_libs
}

proc xcs_delete_log_files { log_files launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set log_filelist [list]
  foreach log $log_files { lappend log_filelist "${log}.log" }
  foreach log_file $log_filelist {
    set full_path "$launch_dir/$log_file"
    if { [file exists $full_path] } {
      [catch {file delete -force $full_path} error_msg]
    }
  }
}

proc xcs_write_log_file_cleanup { fh_scr log_files } {
  # Summary:
  # Argument Usage:
  # Return Value:

  puts $fh_scr "# delete log files (if exist)"
  set files [join $log_files " "]
  puts $fh_scr "reset_log()\n\{"
  puts $fh_scr "logs=($files)"
  puts $fh_scr "for (( i=0; i<\$\{#logs\[*\]\}; i++ )); do"
  puts $fh_scr "  file=\"\$\{logs\[i\]\}\""
  puts $fh_scr "  if \[\[ -e \$file \]\]; then"
  puts $fh_scr "    rm -rf \$file"
  puts $fh_scr "  fi"
  puts $fh_scr "done\n\}"
  puts $fh_scr "reset_log"
}
