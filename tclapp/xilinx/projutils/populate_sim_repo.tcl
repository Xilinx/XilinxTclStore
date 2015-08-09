####################################################################################
#
# populate_sim_repo.tcl
#
# Script created on 05/20/2015 by Raj Klair (Xilinx, Inc.)
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::projutils {
  namespace export populate_sim_repo
}

namespace eval ::tclapp::xilinx::projutils {

proc cip_init_vars {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars

  set a_vars(s_xport_dir)             "proj_sim"
  set a_vars(base_dir)                ""
  set a_vars(central_dir)             ""
  set a_vars(mem_dir)                 ""
  set a_vars(scr_dir)                 ""
  set a_vars(ipstatic_source_dir)     ""
  set a_vars(ip_base_dir)             ""
  set a_vars(bd_base_dir)             ""
  set a_vars(ip_user_files_dir)       ""
  set a_vars(b_central_dir_specified) 0
  set a_vars(b_ipstatic_source_dir)   0
  set a_vars(sp_of_objects)           {}
  set a_vars(b_of_objects_specified)    0
  set a_vars(b_is_ip_object_specified)  0
  set a_vars(b_is_fs_object_specified)  0
  set a_vars(b_clean_dir)             0
  set a_vars(b_force)                 0
  set a_vars(s_ip_file_extn)          ".xci"
  set a_vars(b_ips_locked)            0
  set a_vars(b_ips_upto_date)         1
  set a_vars(b_is_managed)            [get_property managed_ip [current_project]]
  set a_vars(fs_obj)                  [current_fileset -simset]

  variable export_coln                [list]

  variable l_valid_ip_extns           [list]
  set l_valid_ip_extns                [list ".xci" ".bd" ".slx"]
  variable l_valid_data_file_extns
  set l_valid_data_file_extns         [list ".mif" ".coe"]

  variable s_mem_filter
  set s_mem_filter                    "FILE_TYPE==\"Data Files\" || FILE_TYPE==\"Memory Initialization Files\" || FILE_TYPE==\"Coefficient Files\""

  variable l_libraries                [list]
}

proc populate_sim_repo {args} {
  # Summary:
  # Generate and populate the central simulation directory for a project. This can also
  # be scoped to work on one or more IPs in the project.
  # Argument Usage:
  # [-of_objects <arg>]: IP,IPI or a fileset
  # [-sim_central_dir <arg>]: Directory path to simulation base directory (for dynamic and other IP non static files)
  # [-ipstatic_source_dir <arg>]: Directory path to the static IP files
  # [-clean_dir]: Delete all IP files from central directory
  # [-force]: Overwrite files 

  # Return Value:
  # list of files that were populated

  # Categories: simulation, xilinxtclstore

  variable a_vars
  variable l_libraries
  variable export_coln
  variable l_valid_ip_extns
  cip_init_vars
  set a_vars(options) [split $args " "]
  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-of_objects"          { incr i;set a_vars(sp_of_objects) [lindex $args $i];set a_vars(b_of_objects_specified) 1 }
      "-sim_central_dir"     { incr i;set a_vars(central_dir) [lindex $args $i];set a_vars(b_central_dir_specified) 1 }
      "-ipstatic_source_dir" { incr i;set a_vars(ipstatic_source_dir) [lindex $args $i];set a_vars(b_ipstatic_source_dir) 1 }
      "-clean_dir"           { set a_vars(b_clean_dir) 1 }
      "-force"               { set a_vars(b_force) 1 }
      default {
        if { [regexp {^-} $option] } {
          send_msg_id populate_sim_repo-Tcl-003 ERROR "Unknown option '$option', please type 'populate_sim_repo -help' for usage info.\n"
          return $export_coln
        }
      }
    }
  }

  cip_set_dirs

  if { ($a_vars(b_clean_dir)) && ($a_vars(b_of_objects_specified))} {
    [catch {send_msg_id populate_sim_repo-Tcl-009 ERROR "The -of_objects switch is not applicable when -clean_dir is specified.\n"} err]
    return $export_coln
  }

  if { $a_vars(b_clean_dir) } {
    cip_clean_central_dirs
    #send_msg_id populate_sim_repo-Tcl-009 INFO "Cleaned up simulation repository.\n"
    return $export_coln
  }

  # default: all ips in project
  if { !$a_vars(b_of_objects_specified) } {
    set a_vars(sp_of_objects) [get_ips -quiet]
  }

  if { $a_vars(b_of_objects_specified) && ({} == $a_vars(sp_of_objects)) } {
    [catch {send_msg_id populate_sim_repo-Tcl-000 ERROR "No objects found specified with the -of_objects switch.\n"} err]
    return $export_coln
  }
  
  # no objects, return
  if { {} == $a_vars(sp_of_objects) } {
    return $export_coln
  }

  cip_create_central_dirs


  # no -of_objects specified
  if { ({} == $a_vars(sp_of_objects)) || ([llength $a_vars(sp_of_objects)] == 1) } {
    set obj $a_vars(sp_of_objects)
    set file_extn [file extension $obj]
    if { {} != $file_extn } {
      if { [lsearch -exact $l_valid_ip_extns ${file_extn}] == -1 } {
        continue
      }
    }
    cip_export_files $obj
  } else {
    foreach obj $a_vars(sp_of_objects) {
      set file_extn [file extension $obj]
      if { {} != $file_extn } {
        if { [lsearch -exact $l_valid_ip_extns ${file_extn}] == -1 } {
          continue
        }
      }
      if { [cip_export_files $obj] } {
        continue
      }
    }
  }

  if { $a_vars(b_ips_locked) } {
    puts ""
    send_msg_id populate_sim_repo-Tcl-045 "WARNING" \
      "Detected IP(s) that are in the locked state. It is strongly recommended that these IP(s) be upgraded and re-generated.\n\
       To upgrade the IP, please see 'upgrade_ip \[get_ips <ip-name>\]' Tcl command.\n"
    puts ""
  }

  if { !$a_vars(b_ips_upto_date) } {
    puts ""
    send_msg_id populate_sim_repo-Tcl-045 "WARNING" \
      "Detected IP(s) that have either not generated simulation products or have subsequently been updated, making the current\n\
       products out-of-date. It is strongly recommended that these IP(s) be re-generated and then this script run again to fully populate the central simulation\n\
       repository. To generate the output products please see 'generate_target' Tcl command.\n"
    puts ""
  }

  #send_msg_id populate_sim_repo-Tcl-009 INFO "Done\n"
  return $export_coln
}

proc cip_export_files { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  #set sp_tcl_obj {}
  #if { [cip_set_target_obj $obj sp_tcl_obj] } {
  #  return
  #}

  #if { ! [cip_is_upto_date $obj] } {
    #return 1
  #}

  if { [cip_export_ip_files $obj] } {
    return 1
  }


  return 0

}

proc cip_set_target_obj { obj sp_tcl_obj_arg } {
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
    set a_vars(b_is_ip_object_specified) [cip_is_ip $obj]
    set a_vars(b_is_fs_object_specified) [cip_is_fileset $obj]
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
        send_msg_id exportsim-Tcl-014 INFO "No IP's found in the current project.\n"
        return 1
      }
      [catch {send_msg_id exportsim-Tcl-015 ERROR "No IP source object specified. Please type 'populate_sim_repo -help' for usage info.\n"} err]
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
          send_msg_id exportsim-Tcl-015 ERROR \
          "Invalid simulation fileset '$fs_of_obj' of type '$fs_type' specified with the -of_objects switch. Please specify a 'current' simulation or design source fileset.\n"
          return 1
        }

        # must work on the current fileset
        if { $fs_of_obj != $fs_active } {
          [catch {send_msg_id exportsim-Tcl-015 ERROR \
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

proc cip_export_ip_files { obj } {
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
          cip_export_bd $bd_file
        } 
      } else {
        set ip_file [get_property IP_FILE [get_ips -all -quiet $obj]]
        set ip [cip_get_ip_name $ip_file]
        # is BD ip? skip
        if { {} != $ip } {
          # no op
        } else {
          #puts ip=$obj
          cip_export_ip $obj
        }
      }
    }
  } else {
    if { {.bd} == $ip_extn } {
      cip_export_bd $obj
    } elseif { ({.xci} == $ip_extn) || ({.xcix} == $ip_extn) } {
      set ip [cip_get_ip_name $obj]
      # is BD ip? skip
      if { {} != $ip } {
        # no op
      } else {
        #puts ip=$obj
        cip_export_ip $obj
      }
    } else {
      puts unknown_extn=$ip_extn
      return 0
    }
  }
  return 0
}

proc cip_export_ip { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  variable export_coln
  variable l_valid_data_file_extns

  set ip_name [file root [file tail $obj]]
  set ip_extn [file extension $obj]
  set b_container [cip_is_core_container $ip_name]
  #puts $ip_name=$b_container
  #
  # static files
  #
  set l_static_files [list]
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
    #send_msg_id populate_sim_repo-Tcl-009 STATUS " + exported IP   (static):'$extracted_file'\n"
    lappend export_coln $extracted_file
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
      set file [extract_files -base_dir ${ip_dir} -no_ip_dir -files $sim_file]
      # cleanup dynamic files for classic ip
      if { [file exists $file] } {
        if {[catch {file delete -force $file} error_msg] } {
          send_msg_id populate_sim_repo-Tcl-010 ERROR "failed to delete file ($file): $error_msg\n"
          return 1
        }
      }
    }
  }

  # templates
  set ip_dir [file normalize [file join $a_vars(ip_user_files_dir) $ip_name]]
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

  cip_export_mem_init_files_for_ip $obj

  return 0
}

proc cip_export_bd { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  variable export_coln
  variable l_valid_data_file_extns

  set ip_name [file root [file tail $obj]]
  set ip_extn [file extension $obj]

  #
  # static files
  #
  set l_static_files [list]
  set l_static_files [get_files -quiet -all -of_objects [get_files -quiet ${ip_name}.bd] -filter {USED_IN=~"*ipstatic*"}]
  foreach src_ip_file $l_static_files {
    set src_ip_file [string map {\\ /} $src_ip_file]
    # /wrk/hdstaff/rvklair/try/projects/demo/ipshared/xilinx.com/xbip_utils_v3_0/4f162624/hdl/xbip_utils_v3_0_vh_rfs.vhd 
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
    # /wrk/hdstaff/rvklair/try/projects/demo/ipshared/xilinx.com/xbip_utils_v3_0
    #puts ip_lib_dir=$ip_lib_dir
    set ip_lib_dir_name [file tail $ip_lib_dir]
 
    # create target library dir
    set target_ip_lib_dir [file join $a_vars(ipstatic_dir) $ip_lib_dir_name]
    if { ![file exists $target_ip_lib_dir] } {
      if {[catch {file mkdir $target_ip_lib_dir} error_msg] } {
        send_msg_id populate_sim_repo-Tcl-009 ERROR "failed to create the directory ($target_ip_lib_dir): $error_msg\n"
        continue
      }
    }
    # /wrk/hdstaff/rvklair/try/projects/demo/project_1/project_1_sim/ipstatic/xbip_utils_v3_0
    #puts target_ip_lib_dir=$target_ip_lib_dir

    # get the sub-dir path after "xilinx.com/xbip_utils_v3_0/4f162624"
    set ip_hdl_dir [join [lrange $comps 0 $index] "/"]
    set ip_hdl_dir "/$ip_hdl_dir"
    # /wrk/hdstaff/rvklair/try/projects/demo/ipshared/xilinx.com/xbip_utils_v3_0/4f162624/hdl
    #puts ip_hdl_dir=$ip_hdl_dir
    incr index

    set ip_hdl_sub_dir [join [lrange $comps $index end] "/"]
    # /4f162624/hdl/xbip_utils_v3_0_vh_rfs.vhd
    #puts ip_hdl_sub_dir=$ip_hdl_sub_dir

    set dst_file [file join $target_ip_lib_dir $ip_hdl_sub_dir]
    # /wrk/hdstaff/rvklair/try/projects/demo/project_1/project_1_sim/ipstatic/xbip_utils_v3_0/hdl/xbip_utils_v3_0_vh_rfs.vhd
    #puts dst_file=$dst_file
    lappend export_coln $dst_file

    if { [file exists $dst_file] } {
      # skip  
    } else { 
      cip_copy_files_recursive $ip_hdl_dir $target_ip_lib_dir
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
    # /wrk/hdstaff/rvklair/try/projects/demo/project_1/project_1.srcs/sources_1/bd/design_1/ip/design_1_cmpy_0_0/demo_tb/tb_design_1_cmpy_0_0.vhd 
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
    # /wrk/hdstaff/rvklair/try/projects/demo/project_1/project_1.srcs/sources_1/bd/design_1 
    #puts ip_lib_dir=$ip_lib_dir

    set target_ip_lib_dir [file join $a_vars(bd_base_dir) ${ip_name}]
    # /wrk/hdstaff/rvklair/try/projects/demo/project_1/project_1_sim/bd/design_1 
    #puts target_ip_lib_dir=$target_ip_lib_dir

    set hdl_dir_file [join [lrange $comps $index end] "/"]
    # ip/design_1_cmpy_0_0/demo_tb/tb_design_1_cmpy_0_0.vhd 
    #puts hdl_dir_file=$hdl_dir_file

    set dst_file [file join $target_ip_lib_dir $hdl_dir_file]
    # /wrk/hdstaff/rvklair/try/projects/demo/project_1/project_1_sim/bd/design_1/ip/design_1_cmpy_0_0/demo_tb/tb_design_1_cmpy_0_0.vhd 
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
            send_msg_id populate_sim_repo-Tcl-009 ERROR "failed to create the directory ($dst): $error_msg\n"
            return 1
          }
        }
      } else {
        set dst_dir [file dirname $dst]
         if {[catch {file copy -force $src $dst_dir} error_msg] } {
          send_msg_id export_ip_files-Tcl-025 WARNING "Failed to copy file '$src' to '$dst_dir' : $error_msg\n"
        }
      }
    }
  }

  cip_export_mem_init_files_for_bd $obj

  return 0
}

proc cip_is_ip { obj } {
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

proc cip_is_fileset { obj } {
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

proc cip_is_core_container { ip_name } {
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

proc cip_copy_files_recursive { src dst } {
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
            send_msg_id export_ip_files-Tcl-025 WARNING "Failed to create directory '$dst_dir' : $error_msg\n"
          }
        }
        cip_copy_files_recursive $file $dst_dir
      } else {
        set filename [file tail $file]
        set dst_file [file join $dst $filename]
        if { ![file exists $dst] } {
          if {[catch {file mkdir $dst} error_msg] } {
            send_msg_id export_ip_files-Tcl-025 WARNING "Failed to create directory '$dst_dir' : $error_msg\n"
          }
        }
        if { ![file exist $dst_file] } {
          if {[catch {file copy -force $file $dst} error_msg] } {
            send_msg_id export_ip_files-Tcl-025 WARNING "Failed to copy file '$file' to '$dst' : $error_msg\n"
          } else {
            #send_msg_id export_ip_files-Tcl-009 STATUS " + Exported file (dynamic):'$dst'\n"
          }
        }
      }
    }
  } else {
    set filename [file tail $src]
    set dst_file [file join $dst $filename]
    if { ![file exist $dst_file] } {
      if {[catch {file copy -force $src $dst} error_msg] } {
        #send_msg_id export_ip_files-Tcl-025 WARNING "Failed to copy file '$src' to '$dst' : $error_msg\n"
      } else {
        #send_msg_id export_ip_files-Tcl-009 STATUS " + Exported file (dynamic):'$dst'\n"
      }
    }
  }
}

proc cip_is_upto_date { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  set ip_name [file root [file tail $obj]]
  set ip_extn [file extension $obj]
  if { {.bd} == $ip_extn } { return 1 }

  set regen_ip [dict create]
  if { ([cip_is_ip $obj]) && ({.xci} == $a_vars(s_ip_file_extn)) } {
    if { {1} == [get_property is_locked [get_ips -all -quiet $ip_name]] } {
      if { 0 == $a_vars(b_ips_locked) } {
        set a_vars(b_ips_locked) 1
      }
      send_msg_id populate_sim_repo-Tcl-045 INFO "IP status: 'LOCKED' - $ip_name"
      return 0
    }
    if { ({0} == [get_property is_enabled [get_files -quiet -all ${ip_name}.xci]]) } {
      send_msg_id populate_sim_repo-Tcl-045 INFO "IP status: 'USER DISABLED' - $ip_name"
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
    send_msg_id populate_sim_repo-Tcl-045 INFO $msg_txt
    return 0
  }
  return 1
}

proc cip_vao_file {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  variable l_libraries
  # vhdl analyze order file
  set vao_file [file normalize [file join $a_vars(ipstatic_dir) "vhdl_analyze_order"]]
  if { [file exists $vao_file] } {
    if {[catch {file delete -force $vao_file} error_msg] } {
      send_msg_id populate_sim_repo-Tcl-010 ERROR "failed to delete file ($vao_file): $error_msg\n"
      return 1
    }
  }
  set fh 0
  if {[catch {open $vao_file w} fh]} {
   send_msg_id populate_sim_repo-Tcl-005 ERROR "failed to open file for write ($vao_file)\n"
   return 1
  }
  foreach lib $l_libraries {
    puts $fh $lib
  }
  close $fh

  return
}

proc cip_create_mem_dir {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  if { ! [file exists $a_vars(mem_dir)] } {
    if {[catch {file mkdir $a_vars(mem_dir)} error_msg] } {
      send_msg_id populate_sim_repo-Tcl-009 ERROR "failed to create the directory ($a_vars(mem_dir)): $error_msg\n"
      return 1
    }
  }
  return 0
}

proc cip_create_central_dirs {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars

  if { ! [file exists $a_vars(base_dir)] } {
    if {[catch {file mkdir $a_vars(base_dir)} error_msg] } {
      send_msg_id populate_sim_repo-Tcl-009 ERROR "failed to create the directory ($a_vars(base_dir)): $error_msg\n"
      return 1
    }
  }


  if { ! [file exists $a_vars(scr_dir)] } {
    if {[catch {file mkdir $a_vars(scr_dir)} error_msg] } {
      send_msg_id populate_sim_repo-Tcl-009 ERROR "failed to create the directory ($a_vars(scr_dir)): $error_msg\n"
      return 1
    }
  }

  if { ! [file exists $a_vars(ipstatic_dir)] } {
    if {[catch {file mkdir $a_vars(ipstatic_dir)} error_msg] } {
      send_msg_id populate_sim_repo-Tcl-009 ERROR "failed to create the directory $a_vars(ipstatic_dir): $error_msg\n"
      return 1
    }
  }

  if { ! [file exists $a_vars(ip_base_dir)] } {
    if {[catch {file mkdir $a_vars(ip_base_dir)} error_msg] } {
      send_msg_id populate_sim_repo-Tcl-009 ERROR "failed to create the directory $a_vars(ip_base_dir): $error_msg\n"
      return 1
    }
  }

  if { ! [file exists $a_vars(bd_base_dir)] } {
    if {[catch {file mkdir $a_vars(bd_base_dir)} error_msg] } {
      send_msg_id populate_sim_repo-Tcl-009 ERROR "failed to create the directory $a_vars(bd_base_dir): $error_msg\n"
      return 1
    }
  }

  if { ! [file exists $a_vars(ip_user_files_dir)] } {
    if {[catch {file mkdir $a_vars(ip_user_files_dir)} error_msg] } {
      send_msg_id populate_sim_repo-Tcl-009 ERROR "failed to create the directory $a_vars(ip_user_files_dir): $error_msg\n"
      return 1
    }
  }
}

proc cip_set_dirs {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars

  # base dir
  set dir [get_property SIM.CENTRAL_DIR [current_project]]
  if { $a_vars(b_central_dir_specified) } {
    set dir $a_vars(central_dir)
  }

  if { {} == $dir } {
    set base_dir $a_vars(s_xport_dir)
  }
  set a_vars(base_dir) [file normalize $dir]

  # ipstatic dir
  set a_vars(ipstatic_dir) [get_property SIM.IPSTATIC.SOURCE_DIR [current_project]]
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

  # ip user files dir
  set a_vars(ip_user_files_dir) [get_property IP.USER_FILES_DIR [current_project]]

  set a_vars(mem_dir) [file normalize [file join $a_vars(base_dir) "mem_init_files"]]
  set a_vars(scr_dir) [file normalize [file join $a_vars(base_dir) "scripts"]]

  # set path separator
  set a_vars(base_dir)     [string map {\\ /} $a_vars(base_dir)]
  set a_vars(ipstatic_dir) [string map {\\ /} $a_vars(ipstatic_dir)]
  set a_vars(mem_dir)      [string map {\\ /} $a_vars(mem_dir)]
  set a_vars(scr_dir)      [string map {\\ /} $a_vars(scr_dir)]
}

proc cip_clean_central_dirs {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars

  if { [file exists $a_vars(base_dir)] } {
    foreach file_path [glob -nocomplain -directory $a_vars(base_dir) *] {
      set file_path [string map {\\ /} $file_path]
      if { $file_path == $a_vars(ip_base_dir) } { continue }
      if { $file_path == $a_vars(bd_base_dir) } { continue }
      if { $file_path == $a_vars(ip_user_files_dir) } { continue }
      if { $file_path == $a_vars(ipstatic_dir) } { continue }
      if { $file_path == $a_vars(mem_dir) } { continue }
      if { $file_path == $a_vars(scr_dir) } { continue }
      if {[catch {file delete -force $file_path} error_msg] } {
        [catch {send_msg_id populate_sim_repo-Tcl-033 ERROR "failed to delete file ($a_vars(file_path)): $error_msg\n"} err]
        return
      }
    }
  }

  if { [file exists $a_vars(mem_dir)] } {
    foreach file_path [glob -nocomplain -directory $a_vars(mem_dir) *] {
      if {[catch {file delete -force $file_path} error_msg] } {
        [catch {send_msg_id populate_sim_repo-Tcl-033 ERROR "failed to delete file ($a_vars(file_path)): $error_msg\n"} err]
        return
      }
    }
    if { [file exists $a_vars(mem_dir)] } {
      if {[catch {file delete -force $a_vars(mem_dir)} error_msg] } {
        [catch {send_msg_id populate_sim_repo-Tcl-033 ERROR "failed to delete file ($a_vars(mem_dir)): $error_msg\n"} err]
        return
      }
    }
  }

  if { [file exists $a_vars(scr_dir)] } {
    foreach file_path [glob -nocomplain -directory $a_vars(scr_dir) *] {
      if {[catch {file delete -force $file_path} error_msg] } {
        [catch {send_msg_id populate_sim_repo-Tcl-033 ERROR "failed to delete file ($a_vars(file_path)): $error_msg\n"} err]
        return
      }
    }
  }

  if { [file exists $a_vars(ipstatic_dir)] } {
    foreach file_path [glob -nocomplain -directory $a_vars(ipstatic_dir) *] {
      if {[catch {file delete -force $file_path} error_msg] } {
        [catch {send_msg_id populate_sim_repo-Tcl-033 ERROR "failed to delete file ($a_vars(file_path)): $error_msg\n"} err]
        return
      }
    }
  }

  if { [file exists $a_vars(ip_base_dir)] } {
    foreach file_path [glob -nocomplain -directory $a_vars(ip_base_dir) *] {
      if {[catch {file delete -force $file_path} error_msg] } {
        [catch {send_msg_id populate_sim_repo-Tcl-033 ERROR "failed to delete file ($a_vars(file_path)): $error_msg\n"} err]
        return
      }
    }
  }

  if { [file exists $a_vars(bd_base_dir)] } {
    foreach file_path [glob -nocomplain -directory $a_vars(bd_base_dir) *] {
      if {[catch {file delete -force $file_path} error_msg] } {
        [catch {send_msg_id populate_sim_repo-Tcl-033 ERROR "failed to delete file ($a_vars(file_path)): $error_msg\n"} err]
        return
      }
    }
  }

  if { [file exists $a_vars(ip_user_files_dir)] } {
    foreach file_path [glob -nocomplain -directory $a_vars(ip_user_files_dir) *] {
      if {[catch {file delete -force $file_path} error_msg] } {
        [catch {send_msg_id populate_sim_repo-Tcl-033 ERROR "failed to delete file ($a_vars(file_path)): $error_msg\n"} err]
        return
      }
    }
  }
}

proc cip_export_mem_init_files_for_ip { obj } {
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
      {.txt} -
      {.xml} {
        if { {} != [cip_get_ip_name $file] } {
          continue
        }
      }
    }
    if { ![file exists $a_vars(mem_dir)] } {
      cip_create_mem_dir
    }
    set file [extract_files -no_paths -files [list "$file"] -base_dir $a_vars(mem_dir)]
    if { {} != $file } {
      #send_msg_id populate_sim_repo-Tcl-009 STATUS " + exported IP (mem_init):'$file'\n"
    }
  }
}

proc cip_export_mem_init_files_for_bd { obj } {
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
      {.txt} -
      {.xml} {
        if { {} != [cip_get_ip_name $file] } {
          continue
        }
      }
    }
    if { ![file exists $a_vars(mem_dir)] } {
      cip_create_mem_dir
    }
    set file [extract_files -no_paths -files [list "$file"] -base_dir $a_vars(mem_dir)]
    if { {} != $file } {
      #send_msg_id populate_sim_repo-Tcl-009 STATUS " + exported IP (mem_init):'$file'\n"
    }
  }
}

proc cip_get_ip_name { src_file } {
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

}
