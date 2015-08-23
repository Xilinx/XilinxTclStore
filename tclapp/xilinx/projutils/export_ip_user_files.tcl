####################################################################################
#
# export_ip_user_files.tcl
#
# Script created on 05/20/2015 by Raj Klair (Xilinx, Inc.)
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::projutils {
  namespace export export_ip_user_files
}

namespace eval ::tclapp::xilinx::projutils {

proc xif_init_vars {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars

  set a_vars(s_xport_dir)             ".ip_user_files"
  set a_vars(base_dir)                ""
  set a_vars(central_dir)             ""
  set a_vars(mem_dir)                 ""
  set a_vars(scr_dir)                 ""
  set a_vars(co_file_list)            ""
  set a_vars(ipstatic_source_dir)     ""
  set a_vars(ip_base_dir)             ""
  set a_vars(bd_base_dir)             ""
  set a_vars(b_central_dir_specified) 0
  set a_vars(b_ipstatic_source_dir)   0
  set a_vars(sp_of_objects)           {}
  set a_vars(b_of_objects_specified)    0
  set a_vars(b_is_ip_object_specified)  0
  set a_vars(b_is_fs_object_specified)  0
  set a_vars(b_no_script)             0
  set a_vars(b_clean_dir)             0
  set a_vars(b_force)                 0
  set a_vars(s_ip_file_extn)          ".xci"
  set a_vars(b_ips_locked)            0
  set a_vars(b_ips_upto_date)         1
  set a_vars(b_is_managed)            [get_property managed_ip [current_project]]
  set a_vars(b_use_static_lib)        [get_property sim.ipstatic.use_precompiled_libs [current_project]]
  set a_vars(fs_obj)                  [current_fileset -simset]

  variable compile_order_data         [list]
  variable export_coln                [list]

  variable l_valid_ip_extns           [list]
  set l_valid_ip_extns                [list ".xci" ".bd" ".slx"]
  variable l_valid_data_file_extns
  set l_valid_data_file_extns         [list ".mif" ".coe"]

  variable s_mem_filter
  set s_mem_filter                    "FILE_TYPE==\"Data Files\" || FILE_TYPE==\"Memory Initialization Files\" || FILE_TYPE==\"Coefficient Files\""

  variable l_libraries                [list]
  
  variable l_ip_info                  [list]
}

proc export_ip_user_files {args} {
  # Summary:
  # Generate and export IP user files from a project. This can be scoped to work on one or more IPs.
  # Argument Usage:
  # [-of_objects <arg>]: IP,IPI or a fileset
  # [-ip_user_files_dir <arg>]: Directory path to simulation base directory (for dynamic and other IP non static files)
  # [-ipstatic_source_dir <arg>]: Directory path to the static IP files
  # [-no_script]: Do not export simulation scripts
  # [-clean_dir]: Delete all IP files from central directory
  # [-force]: Overwrite files 

  # Return Value:
  # list of files that were exported

  # Categories: simulation, xilinxtclstore

  variable a_vars
  variable l_libraries
  variable export_coln
  variable l_valid_ip_extns
  variable l_ip_info
  xif_init_vars
  set a_vars(options) [split $args " "]
  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-of_objects"          { incr i;set a_vars(sp_of_objects) [lindex $args $i];set a_vars(b_of_objects_specified) 1 }
      "-ip_user_files_dir"   { incr i;set a_vars(central_dir) [lindex $args $i];set a_vars(b_central_dir_specified) 1 }
      "-ipstatic_source_dir" { incr i;set a_vars(ipstatic_source_dir) [lindex $args $i];set a_vars(b_ipstatic_source_dir) 1 }
      "-no_script"           { set a_vars(b_no_script) 1 }
      "-clean_dir"           { set a_vars(b_clean_dir) 1 }
      "-force"               { set a_vars(b_force) 1 }
      default {
        if { [regexp {^-} $option] } {
          send_msg_id export_ip_user_files-Tcl-001 ERROR "Unknown option '$option', please type 'export_ip_user_files -help' for usage info.\n"
          return $export_coln
        }
      }
    }
  }

  xif_set_dirs

  if { ($a_vars(b_clean_dir)) && ($a_vars(b_of_objects_specified))} {
    [catch {send_msg_id export_ip_user_files-Tcl-002 ERROR "The -of_objects switch is not applicable when -clean_dir is specified.\n"} err]
    return $export_coln
  }

  if { $a_vars(b_clean_dir) } {
    xif_clean_central_dirs
    #send_msg_id export_ip_user_files-Tcl-003 INFO "Cleaned up simulation repository.\n"
    return $export_coln
  }

  # default: all ips in project
  if { !$a_vars(b_of_objects_specified) } {
    set a_vars(sp_of_objects) [get_ips -quiet]
  }

  if { $a_vars(b_of_objects_specified) && ({} == $a_vars(sp_of_objects)) } {
    [catch {send_msg_id export_ip_user_files-Tcl-004 ERROR "No objects found specified with the -of_objects switch.\n"} err]
    return $export_coln
  }
  
  # no objects, return
  if { {} == $a_vars(sp_of_objects) } {
    return $export_coln
  }

  xif_create_central_dirs

  # no -of_objects specified
  if { ({} == $a_vars(sp_of_objects)) || ([llength $a_vars(sp_of_objects)] == 1) } {
    set obj $a_vars(sp_of_objects)
    set file_extn [file extension $obj]
    if { {} != $file_extn } {
      if { [lsearch -exact $l_valid_ip_extns ${file_extn}] == -1 } {
        continue
      }
    }
    xif_export_files $obj
  } else {
    foreach obj $a_vars(sp_of_objects) {
      set file_extn [file extension $obj]
      if { {} != $file_extn } {
        if { [lsearch -exact $l_valid_ip_extns ${file_extn}] == -1 } {
          continue
        }
      }
      if { [xif_export_files $obj] } {
        continue
      }
    }
  }

  if { $a_vars(b_ips_locked) } {
    puts ""
    send_msg_id export_ip_user_files-Tcl-005 "WARNING" \
      "Detected IP(s) that are in the locked state. It is strongly recommended that these IP(s) be upgraded and re-generated.\n\
       To upgrade the IP, please see 'upgrade_ip \[get_ips <ip-name>\]' Tcl command.\n"
    puts ""
  }

  if { !$a_vars(b_ips_upto_date) } {
    puts ""
    send_msg_id export_ip_user_files-Tcl-006 "WARNING" \
      "Detected IP(s) that have either not generated simulation products or have subsequently been updated, making the current\n\
       products out-of-date. It is strongly recommended that these IP(s) be re-generated and then this script run again to fully export the IP user files\n\
       directory. To generate the output products please see 'generate_target' Tcl command.\n"
    puts ""
  }

  #send_msg_id export_ip_user_files-Tcl-007 INFO "Done\n"
  
  # Call export simulation to generate simulation scripts (default behavior: generate export_simulation scripts)
  if { $a_vars(b_no_script) } {
    # do not export simulation scripts 
  } else {
    foreach ip_info $l_ip_info {
      set ip_name [lindex [split $ip_info {#}] 0]
      set ip_type [lindex [split $ip_info {#}] 1]
      set ip_dir [file normalize [file join $a_vars(base_dir) "sim_scripts"]]
      if { {bd} == $ip_type } {
        export_simulation -of_objects [get_files -quiet -all ${ip_name}.bd] -directory $ip_dir -force
      } else {
        export_simulation -of_objects [get_ips -quiet -all $ip_name] -directory $ip_dir -force
      }
    }
  }
  return $export_coln
}

proc xif_export_files { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  #set sp_tcl_obj {}
  #if { [xif_set_target_obj $obj sp_tcl_obj] } {
  #  return
  #}

  #if { ! [xif_is_upto_date $obj] } {
    #return 1
  #}

  if { [xif_export_ip_files $obj] } {
    return 1
  }

  return 0
}

proc xif_export_ip_files { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  if { {} == $obj } { return 0 }
  #puts obj=$obj

  set ip_extn [file extension $obj]
  # no extension, just ip name
  if { {} == $ip_extn } {
    set ip_name [file root [file tail $obj]]
    set file_obj [get_ips -all -quiet $ip_name]
    # is bd?
    if { [lsearch -exact [list_property $file_obj] {SCOPE}] != -1 } {
      set bd_file [get_property {SCOPE} $file_obj]
      #puts bd_file=$bd_file
      if { {} != $bd_file } {
        set bd_extn [file extension $bd_file]
        if { {.bd} == $bd_extn } {
          #puts bd=$obj
          xif_export_bd $bd_file
        } 
      } else {
        set ip_file [get_property IP_FILE [get_ips -all -quiet $obj]]
        set ip [xif_get_ip_name $ip_file]
        # is BD ip? skip
        if { {} != $ip } {
          # no op
        } else {
          #puts ip=$obj
          xif_export_ip $obj
        }
      }
    }
  } else {
    if { {.bd} == $ip_extn } {
      xif_export_bd $obj
    } elseif { ({.xci} == $ip_extn) || ({.xcix} == $ip_extn) } {
      set ip [xif_get_ip_name $obj]
      # is BD ip? skip
      if { {} != $ip } {
        # no op
      } else {
        #puts ip=$obj
        xif_export_ip $obj
      }
    } else {
      puts unknown_extn=$ip_extn
      return 0
    }
  }
  return 0
}

proc xif_export_ip { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  variable export_coln
  variable l_valid_data_file_extns
  variable l_ip_info

  set ip_name [file root [file tail $obj]]
  set ip_info "${ip_name}#xci"
  lappend l_ip_info $ip_info
  set ip_extn [file extension $obj]
  set b_container [xif_is_core_container $ip_name]
  #puts $ip_name=$b_container

  set l_static_files [list]
  if { $a_vars(b_use_static_lib) } {
    # do not export static files for pre-compiled lib
  } else {
    #
    # static files
    #
    set ip_data [list]
    foreach src_ip_file [get_files -quiet -all -of_objects [get_ips -all -quiet $ip_name] -filter {USED_IN=~"*ipstatic*"}] {
      set filename [file tail $src_ip_file]
      set file_obj [lindex [get_files -quiet -all [list "$src_ip_file"]] 0]
      if { {} == $file_obj } { continue; }
      if { [lsearch -exact [list_property $file_obj] {IS_USER_DISABLED}] != -1 } {
        if { [get_property {IS_USER_DISABLED} $file_obj] } {
          continue;
        }
      }
      lappend l_static_files $src_ip_file
      set extracted_file [extract_files -no_ip_dir -quiet -files [list "$src_ip_file"] -base_dir $a_vars(ipstatic_dir)]
      #send_msg_id export_ip_user_files-Tcl-008 STATUS " + exported IP   (static):'$extracted_file'\n"
      lappend export_coln $extracted_file
    }
  }

  #
  # clean classic dynamic files
  #
  foreach dynamic_file [get_files -quiet -all -of_objects [get_ips -all -quiet $ip_name] -filter {(USED_IN =~ "*simulation*") && (USED_IN !~ "*ipstatic*")}] {
    if { $b_container } { continue }

    # get dynamic file from repo for classic ip
    set file [xif_get_dynamic_sim_file $ip_name $dynamic_file]
    if { {} == $file } { continue }
    if { ![file exists $file] } { continue }

    # is this file same from within core-container?
    if { $file == $dynamic_file } { continue }

    if { [catch {file delete -force $file} _error] } {
      send_msg_id export_ip_user_files-Tcl-009 INFO "failed to remove dynamic simulation file (${file}): $_error\n"
    }

    set parent_dir [file dirname $file]
    if { {} == $parent_dir } { continue }

    if { ![file isdirectory $parent_dir] } { continue }

    set dir_files [glob -nocomplain [file join $parent_dir *]]
    if { [llength $dir_files] != 0 } {
      continue
    }

    # delete empty parent dir
    if { [catch {file delete -force $parent_dir} _error] } {
      send_msg_id export_ip_user_files-Tcl-010 INFO "failed to remove empty dynamic simulation dir (${parent_dir}): $_error\n"
    }
  }

  #
  # dynamic files
  #
  set ip_dir [file normalize [file join $a_vars(ip_base_dir) $ip_name]]
  foreach sim_file [get_files -quiet -all -of_objects [get_ips -all -quiet $ip_name] -filter {USED_IN=~"*simulation*" || USED_IN=~"*_blackbox_stub"}] {
    if { [lsearch $l_static_files $sim_file] != -1 } { continue }
    if { [lsearch -exact $l_valid_data_file_extns [file extension $sim_file]] >= 0 } { continue }
    set file $sim_file
    if { $b_container } {
      if { $a_vars(b_force) } {
        set file [extract_files -base_dir ${ip_dir} -no_ip_dir -force -files $sim_file]
      } else {
        set file [extract_files -base_dir ${ip_dir} -no_ip_dir -files $sim_file]
      }
      lappend export_coln $file
    } else {
      #set file [extract_files -base_dir ${ip_dir} -no_ip_dir -files $sim_file]
      if { [xif_is_bd_ip_file $file] } {
        # do not delete classic bd file
      } else {
        # cleanup dynamic files for classic ip
        #if { [file exists $file] } {
        #  if {[catch {file delete -force $file} error_msg] } {
        #    send_msg_id export_ip_user_files-Tcl-011 ERROR "failed to delete file ($file): $error_msg\n"
        #    return 1
        #  }
        #}
      }
    }
  }

  # templates
  set ip_dir [file normalize [file join $a_vars(base_dir) "ip" $ip_name]]
  foreach template_file [get_files -quiet -all -of [get_ips -all -quiet $ip_name] -filter {FILE_TYPE == "Verilog Template" || FILE_TYPE == "VHDL Template"}] {
    if { [lsearch $l_static_files $template_file] != -1 } { continue }
    set file {}
    if { $a_vars(b_force) } {
      set file [extract_files -base_dir ${ip_dir} -no_ip_dir -force -files $template_file]
    } else {
      set file [extract_files -base_dir ${ip_dir} -no_ip_dir -files $template_file]
    }
    lappend export_coln $file
  }

  xif_export_mem_init_files_for_ip $obj

  return 0
}

proc xif_is_bd_ip_file { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  #puts file=$file
  set b_is_bd_file 0
  #set file_obj [get_files -all $file]
  #if { {} != $file } {
  #  set props [list_property $file_obj]
  #  if { [lsearch $props "PARENT_COMPOSITE_FILE"] != -1 } {
  #    set ip_file [get_property "PARENT_COMPOSITE_FILE" $file_obj]
  #    puts ip_file=$ip_file
  #  }
  #}

  return $b_is_bd_file
}

proc xif_export_bd { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  variable export_coln
  variable l_valid_data_file_extns
  variable l_ip_info

  set ip_name [file root [file tail $obj]]
  set ip_extn [file extension $obj]
  set ip_info "${ip_name}#bd"
  lappend l_ip_info $ip_info

  #
  # static files
  #
  set l_static_files [list]
  set l_static_files [get_files -quiet -all -of_objects [get_files -quiet ${ip_name}.bd] -filter {USED_IN=~"*ipstatic*"}]
  foreach src_ip_file $l_static_files {
    set src_ip_file [string map {\\ /} $src_ip_file]
    # /ipshared/xilinx.com/xbip_utils_v3_0/4f162624/hdl/xbip_utils_v3_0_vh_rfs.vhd 
    #puts src_ip_file=$src_ip_file

    set sub_dirs [list]
    set comps [lrange [split $src_ip_file "/"] 1 end]
    set to_match "xilinx.com"
    set index 0
    foreach comp $comps {
      incr index
      if { $to_match != $comp } continue;
      break
    }
    set file_path_str [join [lrange $comps 0 $index] "/"]
    set ip_lib_dir "/$file_path_str"
    # /demo/ipshared/xilinx.com/xbip_utils_v3_0
    #puts ip_lib_dir=$ip_lib_dir
    set ip_lib_dir_name [file tail $ip_lib_dir]
 
    # create target library dir
    set target_ip_lib_dir [file join $a_vars(ipstatic_dir) $ip_lib_dir_name]
    if { ![file exists $target_ip_lib_dir] } {
      if {[catch {file mkdir $target_ip_lib_dir} error_msg] } {
        send_msg_id export_ip_user_files-Tcl-012 ERROR "failed to create the directory ($target_ip_lib_dir): $error_msg\n"
        continue
      }
    }
    # /demo/project_1/project_1_sim/ipstatic/xbip_utils_v3_0
    #puts target_ip_lib_dir=$target_ip_lib_dir

    # get the sub-dir path after "xilinx.com/xbip_utils_v3_0/4f162624"
    set ip_hdl_dir [join [lrange $comps 0 $index] "/"]
    set ip_hdl_dir "/$ip_hdl_dir"
    # /demo/ipshared/xilinx.com/xbip_utils_v3_0/4f162624/hdl
    #puts ip_hdl_dir=$ip_hdl_dir
    incr index

    set ip_hdl_sub_dir [join [lrange $comps $index end] "/"]
    # /4f162624/hdl/xbip_utils_v3_0_vh_rfs.vhd
    #puts ip_hdl_sub_dir=$ip_hdl_sub_dir

    set dst_file [file join $target_ip_lib_dir $ip_hdl_sub_dir]
    # /demo/project_1/project_1_sim/ipstatic/xbip_utils_v3_0/hdl/xbip_utils_v3_0_vh_rfs.vhd
    #puts dst_file=$dst_file
    lappend export_coln $dst_file

    if { [file exists $dst_file] } {
      # skip  
    } else { 
      xif_copy_files_recursive $ip_hdl_dir $target_ip_lib_dir
    }
  }

  #
  # dynamic files
  #
  foreach src_ip_file [get_files -quiet -all -of_objects [get_files -quiet ${ip_name}.bd] -filter {USED_IN=~"*simulation*"}] {
    if { [lsearch $l_static_files $src_ip_file] != -1 } { continue }
    if { {.xci} == [file extension $src_ip_file] } { continue }
    if { [lsearch -exact $l_valid_data_file_extns [file extension $src_ip_file]] >= 0 } { continue }
    set src_ip_file [string map {\\ /} $src_ip_file]
    # /demo/project_1/project_1.srcs/sources_1/bd/design_1/ip/design_1_cmpy_0_0/demo_tb/tb_design_1_cmpy_0_0.vhd 
    #puts src_ip_file=$src_ip_file
    set sub_dirs [list]
    set comps [lrange [split $src_ip_file "/"] 1 end]
    set to_match "$ip_name"
    set index 0
    foreach comp $comps {
      incr index
      if { $to_match != $comp } continue;
      break
    }
    incr index -1
    set file_path_str [join [lrange $comps 0 $index] "/"]
    set ip_lib_dir "/$file_path_str"
    # /demo/project_1/project_1.srcs/sources_1/bd/design_1 
    #puts ip_lib_dir=$ip_lib_dir

    set target_ip_lib_dir [file join $a_vars(bd_base_dir) ${ip_name}]
    # /demo/project_1/project_1_sim/bd/design_1 
    #puts target_ip_lib_dir=$target_ip_lib_dir

    set hdl_dir_file [join [lrange $comps $index end] "/"]
    # ip/design_1_cmpy_0_0/demo_tb/tb_design_1_cmpy_0_0.vhd 
    #puts hdl_dir_file=$hdl_dir_file

    set dst_file [file join $target_ip_lib_dir $hdl_dir_file]
    # /demo/project_1/project_1_sim/bd/design_1/ip/design_1_cmpy_0_0/demo_tb/tb_design_1_cmpy_0_0.vhd 
    #puts dst_file=$dst_file
    lappend export_coln $dst_file

    # iterate over the hdl_dir_file comps and copy to target
    set sub_dirs [list]
    set comps [lrange [split $hdl_dir_file "/"] 1 end]
    set src $ip_lib_dir
    set dst $target_ip_lib_dir
    foreach comp $comps {
      append src "/";append src $comp
      append dst "/";append dst $comp
      #puts src=$src
      #puts dst=$dst
      if { [file isdirectory $src] } {
        if { ![file exists $dst] } {
          if {[catch {file mkdir $dst} error_msg] } {
            send_msg_id export_ip_user_files-Tcl-013 ERROR "failed to create the directory ($dst): $error_msg\n"
            return 1
          }
        }
      } else {
        set dst_dir [file dirname $dst]
         if {[catch {file copy -force $src $dst_dir} error_msg] } {
          send_msg_id export_ip_user_files-Tcl-014 WARNING "Failed to copy file '$src' to '$dst_dir' : $error_msg\n"
        }
      }
    }
  }

  xif_export_mem_init_files_for_bd $obj

  return 0
}

proc xif_is_ip { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable l_valid_ip_extns 
  if { [lsearch -exact $l_valid_ip_extns [file extension $obj]] >= 0 } {
    return 1
  } else {
    if {[regexp -nocase {^ip} [get_property -quiet [rdi::get_attr_specs CLASS -object $obj] $obj]] } {
      return 1
    }
  }
  return 0
}

proc xif_is_fileset { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set spec_list [rdi::get_attr_specs -quiet -object $obj -regexp .*FILESET_TYPE.*]
  if { [llength $spec_list] > 0 } {
    if {[regexp -nocase {^fileset_type} $spec_list]} {
      return 1
    }
  }
  return 0
}

proc xif_is_core_container { ip_name } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set b_is_container 1
  if { [get_property sim.use_central_dir_for_ips [current_project]] } {
    return $b_is_container
  }

  set value [string trim [get_property core_container [get_files -all -quiet ${ip_name}.xci]]]
  if { {} == $value } {
    set b_is_container 0
  }
  return $b_is_container
}

proc xif_copy_files_recursive { src dst } {
  # Summary:
  # Argument Usage:
  # Return Value:

  if { [file isdirectory $src] } {
    set files [glob -nocomplain -directory $src *]
    foreach file $files {
      if { [file isdirectory $file] } {
        set sub_dir [file tail $file]
        set dst_dir [file join $dst $sub_dir]
        if { ![file exists $dst_dir] } {
          if {[catch {file mkdir $dst_dir} error_msg] } {
            send_msg_id export_ip_user_files-Tcl-015 WARNING "Failed to create directory '$dst_dir' : $error_msg\n"
          }
        }
        xif_copy_files_recursive $file $dst_dir
      } else {
        set filename [file tail $file]
        set dst_file [file join $dst $filename]
        if { ![file exists $dst] } {
          if {[catch {file mkdir $dst} error_msg] } {
            send_msg_id export_ip_user_files-Tcl-016 WARNING "Failed to create directory '$dst_dir' : $error_msg\n"
          }
        }
        if { ![file exist $dst_file] } {
          if { [xif_filter $file] } {
            # filter these files
          } else {
            if {[catch {file copy -force $file $dst} error_msg] } {
              send_msg_id export_ip_user_files-Tcl-017 WARNING "Failed to copy file '$file' to '$dst' : $error_msg\n"
            } else {
              #send_msg_id export_ip_user_files-Tcl-018 STATUS " + Exported file (dynamic):'$dst'\n"
            }
          }
        }
      }
    }
  } else {
    set filename [file tail $src]
    set dst_file [file join $dst $filename]
    if { [xif_filter $file] } {
      # filter these files
    } else {
      if { ![file exist $dst_file] } {
        if {[catch {file copy -force $src $dst} error_msg] } {
          #send_msg_id export_ip_user_files-Tcl-019 WARNING "Failed to copy file '$src' to '$dst' : $error_msg\n"
        } else {
        #send_msg_id export_ip_user_files-Tcl-020 STATUS " + Exported file (dynamic):'$dst'\n"
        }
      }
    }
  }
}

proc xif_filter { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set b_filter 0
  if { {} == $file } { return $b_filter }
  set file_extn [string tolower [file extension $file]]
  switch -- $file_extn {
    {.xdc} -
    {.png} {
      set b_filter 1
    }
  }
  return $b_filter
}

proc xif_is_upto_date { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  set ip_name [file root [file tail $obj]]
  set ip_extn [file extension $obj]
  if { {.bd} == $ip_extn } { return 1 }

  set regen_ip [dict create]
  if { ([xif_is_ip $obj]) && ({.xci} == $a_vars(s_ip_file_extn)) } {
    if { {1} == [get_property is_locked [get_ips -all -quiet $ip_name]] } {
      if { 0 == $a_vars(b_ips_locked) } {
        set a_vars(b_ips_locked) 1
      }
      send_msg_id export_ip_user_files-Tcl-021 INFO "IP status: 'LOCKED' - $ip_name"
      return 0
    }
    if { ({0} == [get_property is_enabled [get_files -quiet -all ${ip_name}.xci]]) } {
      send_msg_id export_ip_user_files-Tcl-022 INFO "IP status: 'USER DISABLED' - $ip_name"
      return 0
    }
    dict set regen_ip $ip_name d_targets [get_property delivered_targets [get_ips -all -quiet $ip_name]]
    dict set regen_ip $ip_name generated [get_property is_ip_generated [get_ips -all -quiet $ip_name]]
    dict set regen_ip $ip_name generated_sim [get_property is_ip_generated_sim [lindex [get_files -all -quiet ${ip_name}.xci] 0]]
    dict set regen_ip $ip_name stale [get_property stale_targets [get_ips -all -quiet $ip_name]]
  }

  set not_generated [list]
  set stale_ips [list]
  dict for {ip regen} $regen_ip {
    dic with regen {
      if { ({} == $d_targets) || ({0} == $generated_sim) } {
        lappend not_generated $ip
      } else {
        if { [llength $stale] > 0 } {
          lappend stale_ips $ip
        }
      }
    }
  }

  set b_not_generated 0
  set b_is_stale 0
  if { [llength $not_generated] > 0} { set b_not_generated 1}
  if { [llength $stale_ips] > 0}     { set b_is_stale 1}

  set msg_txt "IP status: "
  if { $b_not_generated } { append msg_txt "'NOT GENERATED' " }
  if { $b_is_stale }      { append msg_txt "'OUT OF DATE' " }
  append msg_txt "- $ip_name"

  if { $b_not_generated || $b_is_stale } {
    set a_vars(b_ips_upto_date) 0
    send_msg_id export_ip_user_files-Tcl-023 INFO $msg_txt
    return 0
  }
  return 1
}

proc xif_create_mem_dir {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  if { ! [file exists $a_vars(mem_dir)] } {
    if {[catch {file mkdir $a_vars(mem_dir)} error_msg] } {
      send_msg_id export_ip_user_files-Tcl-024 ERROR "failed to create the directory ($a_vars(mem_dir)): $error_msg\n"
      return 1
    }
  }
  return 0
}

proc xif_create_central_dirs {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars

  if { ! [file exists $a_vars(base_dir)] } {
    if {[catch {file mkdir $a_vars(base_dir)} error_msg] } {
      send_msg_id export_ip_user_files-Tcl-025 ERROR "failed to create the directory ($a_vars(base_dir)): $error_msg\n"
      return 1
    }
  }


  #if { ! [file exists $a_vars(scr_dir)] } {
  #  if {[catch {file mkdir $a_vars(scr_dir)} error_msg] } {
  #    send_msg_id export_ip_user_files-Tcl-026 ERROR "failed to create the directory ($a_vars(scr_dir)): $error_msg\n"
  #    return 1
  #  }
  #}

  if { $a_vars(b_use_static_lib) } {
    # do not create static lib dir
  } else {
    if { ! [file exists $a_vars(ipstatic_dir)] } {
      if {[catch {file mkdir $a_vars(ipstatic_dir)} error_msg] } {
        send_msg_id export_ip_user_files-Tcl-027 ERROR "failed to create the directory $a_vars(ipstatic_dir): $error_msg\n"
        return 1
      }
    }
  }

  #if { ! [file exists $a_vars(ip_base_dir)] } {
  #  if {[catch {file mkdir $a_vars(ip_base_dir)} error_msg] } {
  #    send_msg_id export_ip_user_files-Tcl-028 ERROR "failed to create the directory $a_vars(ip_base_dir): $error_msg\n"
  #    return 1
  #  }
  #}

  #if { ! [file exists $a_vars(bd_base_dir)] } {
  #  if {[catch {file mkdir $a_vars(bd_base_dir)} error_msg] } {
  #    send_msg_id export_ip_user_files-Tcl-029 ERROR "failed to create the directory $a_vars(bd_base_dir): $error_msg\n"
  #    return 1
  #  }
  #}
}

proc xif_set_dirs {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars

  # base dir
  set dir [get_property ip.user_files_dir [current_project]]
  if { $a_vars(b_central_dir_specified) } {
    set dir $a_vars(central_dir)
  }

  if { {} == $dir } {
    set base_dir $a_vars(s_xport_dir)
  }
  set a_vars(base_dir) [file normalize $dir]

  # ipstatic dir
  set a_vars(ipstatic_dir) [get_property sim.ipstatic.source_dir [current_project]]
  if { $a_vars(b_ipstatic_source_dir) } {
    set a_vars(ipstatic_dir) [file normalize $a_vars(ipstatic_source_dir)]
  } else {
    if { $a_vars(b_central_dir_specified) } {
      set a_vars(ipstatic_dir) {}
    }
  }

  if { {} == $a_vars(ipstatic_dir) } {
    set a_vars(ipstatic_dir) [file normalize [file join $a_vars(base_dir) "ipstatic"]]
  }

  # ip dir
  set a_vars(ip_base_dir) [file join $a_vars(base_dir) "ip"]

  # bd dir
  set a_vars(bd_base_dir) [file join $a_vars(base_dir) "bd"]

  set a_vars(mem_dir) [file normalize [file join $a_vars(base_dir) "mem_init_files"]]
  set a_vars(scr_dir) [file normalize [file join $a_vars(base_dir) "sim_scripts"]]

  # set path separator
  set a_vars(base_dir)     [string map {\\ /} $a_vars(base_dir)]
  set a_vars(ipstatic_dir) [string map {\\ /} $a_vars(ipstatic_dir)]
  set a_vars(mem_dir)      [string map {\\ /} $a_vars(mem_dir)]
  set a_vars(scr_dir)      [string map {\\ /} $a_vars(scr_dir)]
}

proc xif_clean_central_dirs {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars

  if { [file exists $a_vars(base_dir)] } {
    foreach file_path [glob -nocomplain -directory $a_vars(base_dir) *] {
      set file_path [string map {\\ /} $file_path]
      if { $file_path == $a_vars(ip_base_dir) } { continue }
      if { $file_path == $a_vars(bd_base_dir) } { continue }
      if { $file_path == $a_vars(ipstatic_dir) } { continue }
      if { $file_path == $a_vars(mem_dir) } { continue }
      if { $file_path == $a_vars(scr_dir) } { continue }
      if {[catch {file delete -force $file_path} error_msg] } {
        [catch {send_msg_id export_ip_user_files-Tcl-030 ERROR "failed to delete file ($a_vars(file_path)): $error_msg\n"} err]
        return
      }
    }
  }

  if { [file exists $a_vars(mem_dir)] } {
    foreach file_path [glob -nocomplain -directory $a_vars(mem_dir) *] {
      if {[catch {file delete -force $file_path} error_msg] } {
        [catch {send_msg_id export_ip_user_files-Tcl-031 ERROR "failed to delete file ($a_vars(file_path)): $error_msg\n"} err]
        return
      }
    }
    if { [file exists $a_vars(mem_dir)] } {
      if {[catch {file delete -force $a_vars(mem_dir)} error_msg] } {
        [catch {send_msg_id export_ip_user_files-Tcl-032 ERROR "failed to delete file ($a_vars(mem_dir)): $error_msg\n"} err]
        return
      }
    }
  }

  if { [file exists $a_vars(scr_dir)] } {
    foreach file_path [glob -nocomplain -directory $a_vars(scr_dir) *] {
      if {[catch {file delete -force $file_path} error_msg] } {
        [catch {send_msg_id export_ip_user_files-Tcl-033 ERROR "failed to delete file ($a_vars(file_path)): $error_msg\n"} err]
        return
      }
    }
  }

  if { [file exists $a_vars(ipstatic_dir)] } {
    foreach file_path [glob -nocomplain -directory $a_vars(ipstatic_dir) *] {
      if {[catch {file delete -force $file_path} error_msg] } {
        [catch {send_msg_id export_ip_user_files-Tcl-034 ERROR "failed to delete file ($a_vars(file_path)): $error_msg\n"} err]
        return
      }
    }
  }

  if { [file exists $a_vars(ip_base_dir)] } {
    foreach file_path [glob -nocomplain -directory $a_vars(ip_base_dir) *] {
      if {[catch {file delete -force $file_path} error_msg] } {
        [catch {send_msg_id export_ip_user_files-Tcl-035 ERROR "failed to delete file ($a_vars(file_path)): $error_msg\n"} err]
        return
      }
    }
  }

  if { [file exists $a_vars(bd_base_dir)] } {
    foreach file_path [glob -nocomplain -directory $a_vars(bd_base_dir) *] {
      if {[catch {file delete -force $file_path} error_msg] } {
        [catch {send_msg_id export_ip_user_files-Tcl-036 ERROR "failed to delete file ($a_vars(file_path)): $error_msg\n"} err]
        return
      }
    }
  }
}

proc xif_export_mem_init_files_for_ip { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  set ip_name [file root [file tail $obj]]
  variable s_mem_filter
  foreach file [get_files -quiet -all -of_objects [get_ips -all -quiet $ip_name] -filter $s_mem_filter] {
    set extn [file extension $file]
    switch -- $extn {
      {.zip} -
      {.xml} {
        if { {} != [xif_get_ip_name $file] } {
          continue
        }
      }
    }
    if { ![file exists $a_vars(mem_dir)] } {
      xif_create_mem_dir
    }
    set file [extract_files -no_paths -files [list "$file"] -base_dir $a_vars(mem_dir)]
    if { {} != $file } {
      #send_msg_id export_ip_user_files-Tcl-037 STATUS " + exported IP (mem_init):'$file'\n"
    }
  }
}

proc xif_export_mem_init_files_for_bd { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  set ip_name [file tail $obj]
  variable s_mem_filter
  foreach file [get_files -quiet -all -of_objects [get_files -quiet $ip_name] -filter $s_mem_filter] {
    set extn [file extension $file]
    switch -- $extn {
      {.zip} -
      {.xml} {
        if { {} != [xif_get_ip_name $file] } {
          continue
        }
      }
    }
    if { ![file exists $a_vars(mem_dir)] } {
      xif_create_mem_dir
    }
    set file [extract_files -no_paths -files [list "$file"] -base_dir $a_vars(mem_dir)]
    if { {} != $file } {
      #send_msg_id export_ip_user_files-Tcl-038 STATUS " + exported IP (mem_init):'$file'\n"
    }
  }
}

proc xif_get_ip_name { src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set ip {}
  set file_obj [lindex [get_files -all -quiet $src_file] 0]
  if { {} == $file_obj } {
    set file_obj [lindex [get_files -all -quiet [file tail $src_file]] 0]
  }

  set props [list_property $file_obj]
  if { [lsearch $props "PARENT_COMPOSITE_FILE"] != -1 } {
    set ip [get_property "PARENT_COMPOSITE_FILE" $file_obj]
  }
  return $ip
}

proc xif_set_target_obj { obj sp_tcl_obj_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  variable l_valid_ip_extns
  upvar $sp_tcl_obj_arg sp_tcl_obj
  set sp_tcl_obj 0

  set a_vars(b_is_ip_object_specified) 0
  set a_vars(b_is_fs_object_specified) 0

  if { {} != $obj } {
    set a_vars(b_is_ip_object_specified) [xif_is_ip $obj]
    set a_vars(b_is_fs_object_specified) [xif_is_fileset $obj]
  }

  if { {1} == $a_vars(b_is_ip_object_specified) } {
    set comp_file $obj
    set file_extn [file extension $comp_file]
    if { [lsearch -exact $l_valid_ip_extns ${file_extn}] == -1 } {
      # valid extention not found, set default (.xci)
      set comp_file ${comp_file}$a_vars(s_ip_file_extn)
    } else {
      set a_vars(s_ip_file_extn) $file_extn
    }
    set sp_tcl_obj [get_files -all -quiet [list "$comp_file"]]
    #xps_verify_ip_status
  } else {
    if { $a_vars(b_is_managed) } {
      set ips [get_ips -quiet]
      if {[llength $ips] == 0} {
        send_msg_id export_ip_user_files-Tcl-040 INFO "No IP's found in the current project.\n"
        return 1
      }
      [catch {send_msg_id export_ip_user_files-Tcl-041 ERROR "No IP source object specified. Please type 'export_ip_user_files -help' for usage info.\n"} err]
      return 1
    } else {
      if { $a_vars(b_is_fs_object_specified) } {
        set fs_type [get_property fileset_type [get_filesets $obj]]
        set fs_of_obj [get_property name [get_filesets $obj]]
        set fs_active {}
        if { $fs_type == "DesignSrcs" } {
          set fs_active [get_property name [current_fileset]]
        } elseif { $fs_type == "SimulationSrcs" } {
          set fs_active [get_property name [get_filesets $a_vars(fs_obj)]]
        } else {
          send_msg_id export_ip_user_files-Tcl-042 ERROR \
          "Invalid simulation fileset '$fs_of_obj' of type '$fs_type' specified with the -of_objects switch. Please specify a 'current' simulation or design source fileset.\n"
          return 1
        }

        # must work on the current fileset
        if { $fs_of_obj != $fs_active } {
          [catch {send_msg_id export_ip_user_files-Tcl-043 ERROR \
            "The specified fileset '$fs_of_obj' is not 'current' (current fileset is '$fs_active'). Please set '$fs_of_obj' as current fileset using the 'current_fileset' Tcl command and retry this command.\n"} err]
          return 1
        }

        # -of_objects specifed, set default active source set
        if { $fs_type == "DesignSrcs" } {
          set a_vars(fs_obj) [current_fileset]
          set sp_tcl_obj $a_vars(fs_obj)
          update_compile_order -quiet -fileset $sp_tcl_obj
        } elseif { $fs_type == "SimulationSrcs" } {
          set sp_tcl_obj $a_vars(fs_obj)
          update_compile_order -quiet -fileset $sp_tcl_obj
        }
      } else {
        # no -of_objects specifed, set default active simset
        set sp_tcl_obj $a_vars(fs_obj)
        update_compile_order -quiet -fileset $sp_tcl_obj
      }
    }
  }
  return 0
}

proc xif_get_relative_file_path { file_path_to_convert relative_to } {
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

proc xif_get_dynamic_sim_file { ip_name src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars

  set comps [lrange [split $src_file "/"] 1 end]

  set b_found false
  if { $a_vars(b_is_managed) } {
    # for managed ip get the path from core container ip name (below)
  } else {
    #set to_match "ip/$ip_name"
    set to_match "ip"
    set index 0
    set b_found false
    foreach comp $comps {
      incr index
      if { $to_match != $comp } continue;
      set b_found true
      break
    }
  
    # try ip name
    if { !$b_found } {
      set to_match "$ip_name"
      set index 0
      set b_found false
      foreach comp $comps {
        incr index
        if { $to_match != $comp } continue;
        set b_found true
        break
      }
    }
  }

  if { !$b_found } {
    # get the core container ip name of this source and find from repo area
    set file_obj [lindex [get_files -all -quiet [list "$src_file"]] 0]
    set xcix_file [string trim [get_property core_container $file_obj]]
    if { {} != $xcix_file } {
      set ip_name [file root [file tail $xcix_file]]
      set to_match "$ip_name"
      set index 0
      set b_found false
      foreach comp $comps {
        incr index
        if { $to_match != $comp } continue;
        set b_found true
        break
      }
    }
  }

  if { ! $b_found } {
    return $src_file
  }

  set file_path_str [join [lrange $comps $index end] "/"]
  #puts file_path_str=$file_path_str
  set src_file [file join $a_vars(base_dir) "ip" $file_path_str]
  if { $to_match == $ip_name } {
    set src_file [file join $a_vars(base_dir) "ip" $ip_name $file_path_str]
  }
  #puts out_src_file=$src_file
  return $src_file
}
}
