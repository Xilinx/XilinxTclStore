####################################################################################
#
# export_ip_user_files.tcl
#
# Script created on 05/20/2015 by Raj Klair (Xilinx, Inc.)
#
####################################################################################
package require Vivado 1.2014.1
package require struct::set

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
  set a_vars(scripts_dir)             ""
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
  set a_vars(b_sync)                  0
  set a_vars(b_reset)                 0
  set a_vars(b_force)                 0
  set a_vars(s_ip_file_extn)          ".xci"
  set a_vars(b_ips_locked)            0
  set a_vars(b_ips_upto_date)         1
  set a_vars(b_is_managed)            [get_property managed_ip [current_project]]
  set a_vars(b_use_static_lib)        [get_property sim.use_ip_compiled_libs [current_project]]
  set a_vars(fs_obj)                  [current_fileset -simset]

  variable compile_order_data         [list]

  variable l_valid_ip_extns           [list]
  set l_valid_ip_extns                [list ".xci" ".bd" ".slx"]
  variable l_valid_data_file_extns
  set l_valid_data_file_extns         [list ".mif" ".coe"]

  variable s_mem_filter
  set s_mem_filter                    "FILE_TYPE==\"Data Files\" || FILE_TYPE==\"Memory Initialization Files\" || FILE_TYPE==\"Coefficient Files\""

  variable l_libraries                [list]
  variable l_compiled_libraries       [list]

  # common - imported to <ns>::xcs_* - home is defined in <app>.tcl
  if { ! [info exists ::tclapp::xilinx::projutils::_xcs_defined] } {
    variable home
    source -notrace [file join $home "common" "utils.tcl"] 
  }

  # store cached results
  variable    a_cache_result
  array unset a_cache_result

  variable    a_cache_get_dynamic_sim_file_bd
  array unset a_cache_get_dynamic_sim_file_bd
}


proc export_ip_user_files {args} {
  # Summary:
  # Generate and export IP/IPI user files from a project. This can be scoped to work on one or more IPs.
  # Argument Usage:
  # [-of_objects <arg>]: IP,IPI or a fileset
  # [-ip_user_files_dir <arg>]: Directory path to simulation base directory (for dynamic and other IP non static files)
  # [-ipstatic_source_dir <arg>]: Directory path to the static IP files
  # [-no_script]: Do not export simulation scripts
  # [-sync]: Delete IP/IPI dynamic and simulation script files
  # [-reset]: Delete all IP/IPI static, dynamic and simulation script files
  # [-force]: Overwrite files 

  # Return Value:
  # list of files that were exported

  # Categories: simulation, xilinxtclstore

  variable a_vars
  variable l_libraries
  variable l_valid_ip_extns
  variable l_compiled_libraries
  xif_init_vars

  set a_vars(options) [split $args " "]
  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-of_objects"          { incr i;set a_vars(sp_of_objects) [lindex $args $i];set a_vars(b_of_objects_specified) 1 }
      "-ip_user_files_dir"   { incr i;set a_vars(central_dir) [lindex $args $i];set a_vars(b_central_dir_specified) 1 }
      "-ipstatic_source_dir" { incr i;set a_vars(ipstatic_source_dir) [lindex $args $i];set a_vars(b_ipstatic_source_dir) 1 }
      "-no_script"           { set a_vars(b_no_script) 1 }
      "-sync"                { set a_vars(b_sync) 1 }
      "-reset"               { set a_vars(b_reset) 1 }
      "-force"               { set a_vars(b_force) 1 }
      default {
        if { [regexp {^-} $option] } {
          send_msg_id export_ip_user_files-Tcl-001 ERROR "Unknown option '$option', please type 'export_ip_user_files -help' for usage info.\n"
          return
        }
      }
    }
  }

  xif_set_dirs

  # default: all ips in project
  if { !$a_vars(b_of_objects_specified) } {
    set a_vars(sp_of_objects) [get_ips -quiet]
  }

  if { $a_vars(b_of_objects_specified) && ({} == $a_vars(sp_of_objects)) } {
    [catch {send_msg_id export_ip_user_files-Tcl-004 ERROR "No objects found specified with the -of_objects switch.\n"} err]
    return
  }
  
  # no objects, return
  if { {} == $a_vars(sp_of_objects) } {
    send_msg_id export_ip_user_files-Tcl-002 INFO "No IPs found in the project.\n"
    return
  }

  xif_create_central_dirs
  if { $a_vars(b_use_static_lib) } {
    set simulator [string tolower [get_property target_simulator [current_project]]]
    set clibs_dir [get_property compxlib.${simulator}_compiled_library_dir [current_project]]
    if { ({xsim} == $simulator) && ({} == $clibs_dir) } {
      set dir $::env(XILINX_VIVADO)
      set clibs_dir [file normalize [file join $dir "data/xsim"]]
    }
    set l_compiled_libraries [xcs_get_compiled_libraries $clibs_dir]
  }

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

  # Call export simulation to generate simulation scripts (default behavior: generate export_simulation scripts)
  if { $a_vars(b_no_script) } {
    # do not export simulation scripts 
  } else {
    # -of_objects not specified? generate sim scripts for all ips/bds
    if { !$a_vars(b_of_objects_specified) } {
      foreach ip_file [get_files -quiet -norecurse -pattern *.xci -pattern *.bd] {
        export_simulation -of_objects [get_files -all -quiet $ip_file] -directory $a_vars(scripts_dir) -ip_user_files_dir $a_vars(base_dir) -ipstatic_source_dir $a_vars(ipstatic_dir) -force
      }
    }
  }

  # clear cache
  array unset a_cache_result
  array unset a_cache_get_dynamic_sim_file_bd

  return
}

proc xif_export_simulation { ip_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  # -of_objects specified? generate sim scripts for the specified object
  if { $a_vars(b_of_objects_specified) && (!$a_vars(b_no_script)) } {
    set opt_args [list]
    if { $a_vars(b_use_static_lib) } {
      lappend opt_args -use_ip_compiled_libs
    }
    
    set ip_user_files_dir [get_property ip.user_files_dir [current_project]]
    if { [string length $ip_user_files_dir] > 0 } {
      lappend opt_args "-ip_user_files_dir"
      lappend opt_args "$ip_user_files_dir"
    }
    
    set ipstatic_source_dir [get_property sim.ipstatic.source_dir [current_project]]
    if { [string length $ipstatic_source_dir] > 0 } {
      lappend opt_args -ipstatic_source_dir
      lappend opt_args "$ipstatic_source_dir"
    }
    # TODO: speedup
    eval export_simulation -of_objects [get_files -all -quiet $ip_file] -directory $a_vars(scripts_dir) -force $opt_args
  }
}

proc xif_export_files { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

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
          xif_cache_result {xif_export_bd $bd_file}
          xif_export_simulation $bd_file
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
          xif_export_simulation $ip_file
        }
      }
    }
  } else {
    if { {.bd} == $ip_extn } {
      xif_cache_result {xif_export_bd $obj}
      xif_export_simulation $obj
    } elseif { ({.xci} == $ip_extn) || ({.xcix} == $ip_extn) } {
      set ip [xif_get_ip_name $obj]
      # is BD ip? skip
      if { {} != $ip } {
        # no op
      } else {
        #puts ip=$obj
        xif_export_ip $obj
        xif_export_simulation $obj
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
  variable l_valid_data_file_extns
  variable l_compiled_libraries

  set ip_name [file root [file tail $obj]]
  set ip_extn [file extension $obj]
  set b_container [xcs_is_core_container ${ip_name}.xci]
  #puts $ip_name=$b_container

  set l_static_files [list]
  set l_static_files_to_delete [list]
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

    set extracted_static_file_path {}

    if { $a_vars(b_use_static_lib) } {
      set file_type {}
      if { [lsearch -exact [list_property $file_obj] {FILE_TYPE}] != -1 } {
        set file_type [get_property file_type $file_obj]
      }
      if { ({Verilog Header} == $file_type) || ({Verilog/SystemVerilog Header} == $file_type) } {
        # consider verilog header files always for pre-compile flow
      } else {
        # is compiled library available from clibs? continue, else extract to ip_user_files dir
        if { [lsearch -exact [list_property $file_obj] {LIBRARY}] != -1 } {
          set library [get_property library $file_obj]
          if { [lsearch -exact $l_compiled_libraries $library] != -1 } {
            # This is causing performance issues (in case the file was present in ipstatic dir from previous run)
            #set extracted_static_file_path [xif_get_extracted_static_file_path $src_ip_file]
            #lappend l_static_files_to_delete $extracted_static_file_path
            continue
          }
        }
      }
    }

    lappend l_static_files $src_ip_file
    # not extracted yet? extract it
    if { {} == $extracted_static_file_path } {
      set extracted_static_file_path [xif_get_extracted_static_file_path $src_ip_file]
    }

    # if reset requested, delete IP file from ipstatic
    if { $a_vars(b_reset) } {
      if { [file exists $extracted_static_file_path] } {
        if { [catch {file delete -force $extracted_static_file_path} _error] } {
          #send_msg_id export_ip_user_files-Tcl-003 INFO "Failed to remove static simulation file (${extracted_static_file_path}): $_error\n"
        } else {
          #send_msg_id export_ip_user_files-Tcl-009 INFO "Deleted static file:$extracted_static_file_path\n"
        }
      }
    }
  }

  # delete pre-compiled static files from ip_user_files
  foreach static_file $l_static_files_to_delete {
    set repo_file [file normalize $static_file]
    if { [file exists $repo_file] } {
      if { [catch {file delete -force $repo_file} _error] } {
        send_msg_id export_ip_user_files-Tcl-003 INFO "Failed to remove static simulation file (${repo_file}): $_error\n"
      } else {
        #send_msg_id export_ip_user_files-Tcl-009 INFO "Deleted static file:$repo_file\n"
      }
    }
  }

  if { $a_vars(b_use_static_lib) } {
    xif_delete_empty_dirs $a_vars(ipstatic_dir)
  }

  # set ip instance dir <ip_user_files>/ip/<ip_instance>
  set ip_inst_dir [file normalize [file join $a_vars(ip_base_dir) $ip_name]]

  # delete dynamic files (ONLY) for non-container ips
  if { $b_container } {
    # no op
  } else {
    set empty_dirs [list]
    # classic ip (non-container) - remove dynamic files
    foreach dynamic_file_obj [get_files -quiet -all -of_objects [get_ips -all -quiet $ip_name] -filter {(USED_IN =~ "*simulation*") && (USED_IN !~ "*ipstatic*")}] {
      # puts dynamic_file_obj=$dynamic_file_obj
      set repo_file [xif_get_dynamic_sim_file $ip_name $dynamic_file_obj]
      # repo file not found? continue
      if { {} == $repo_file } {
        continue
      }
      # is this repo file path same from within core-container? continue, we don't want to delete source dynamic file
      set repo_file [string map {\\ /} $repo_file]
      set dynamic_file [string map {\\ /} $dynamic_file_obj]
      if { $repo_file == $dynamic_file } {
        continue
      }
      # add directory for cleanup
      set file_dir [file dirname $repo_file]
      lappend empty_dirs $file_dir
      # repo file does not exist? continue
      if { ![file exists $repo_file] } {
        continue
      }
      # delete repo file
      if { [catch {file delete -force $repo_file} _error] } {
        send_msg_id export_ip_user_files-Tcl-003 INFO "Failed to remove dynamic simulation file (${repo_file}): $_error\n"
      } else {
        #send_msg_id export_ip_user_files-Tcl-009 INFO "Deleted dynamic file:$repo_file\n"
      }
    }

    # delete empty dynamic file dirs, if any
    foreach dir $empty_dirs {
      if { [file isdirectory $dir] } {
        set dir_files [glob -nocomplain -directory $dir *]
        if { [llength $dir_files] == 0 } {
          if { [catch {file delete -force $dir} _error] } {
            send_msg_id export_ip_user_files-Tcl-007 INFO "Failed to remove directory:($dir): $_error\n"
          } else {
            #send_msg_id export_ip_user_files-Tcl-009 INFO "Deleted directory:$dir\n"
          }
        }
      }
    }
  }

  # if sync requested delete ip/<ip_instance> and sim_scipts/<ip_instance>
  if { $a_vars(b_sync) || $a_vars(b_reset) } {
    xif_delete_ip_inst_dir $ip_inst_dir $ip_name

    # delete core-container ip inst dir
    foreach sim_file_obj [get_files -quiet -all -of_objects [get_ips -all -quiet $ip_name] -filter {USED_IN=~"*simulation*" || USED_IN=~"*_blackbox_stub"}] {
      if { [lsearch $l_static_files $sim_file_obj] != -1 } { continue }
      if { [lsearch -exact $l_valid_data_file_extns [file extension $sim_file_obj]] >= 0 } { continue }
      if { $b_container } {
        set ip_name [xif_get_dynamic_core_container_ip_name $sim_file_obj $ip_name]
        set ip_inst_dir [file normalize [file join $a_vars(ip_base_dir) $ip_name]]
        xif_delete_ip_inst_dir $ip_inst_dir $ip_name
      }
    }

    # delete sim_scripts, if empty
    if { [file isdirectory $a_vars(scripts_dir)] } {
      set sim_script_dir_files [glob -nocomplain -directory $a_vars(scripts_dir) *]
      #puts sim_script_dir_files=$sim_script_dir_files
      if { [llength $sim_script_dir_files] == 0 } {
        if { [catch {file delete -force $a_vars(scripts_dir)} _error] } {
          send_msg_id export_ip_user_files-Tcl-009 INFO "Failed to remove sim scripts directory:($a_vars(scripts_dir)): $_error\n"
        } else {
          #send_msg_id export_ip_user_files-Tcl-009 INFO "Deleted sim scripts directory:$a_vars(scripts_dir)\n"
        }
      }
    }
  }

  #
  # dynamic files
  #
  if { $a_vars(b_reset) } {
    # no op (for reset, we don't want to refetch the dynamic files. These files will be fetched by generate target or export_ip_user_files flow.)
  } else {
    # for default and sync flow, the dynamic files will be fetched always
    foreach dynamic_file_obj [get_files -quiet -all -of_objects [get_ips -all -quiet $ip_name] -filter {USED_IN=~"*simulation*" || USED_IN=~"*_blackbox_stub"}] {
      if { [lsearch $l_static_files $dynamic_file_obj] != -1 } { continue }
      if { [lsearch -exact $l_valid_data_file_extns [file extension $dynamic_file_obj]] >= 0 } { continue }
      set file $dynamic_file_obj
      if { $b_container } {
        set ip_name [xif_get_dynamic_core_container_ip_name $dynamic_file_obj $ip_name]
        set ip_inst_dir [file normalize [file join $a_vars(ip_base_dir) $ip_name]]
        if { $a_vars(b_force) } {
          set dynamic_file_obj [extract_files -base_dir ${ip_inst_dir} -no_ip_dir -force -files $dynamic_file_obj]
        } else {
          set dynamic_file_obj [extract_files -base_dir ${ip_inst_dir} -no_ip_dir -files $dynamic_file_obj]
        }
      } else {
        #set dynamic_file_obj [extract_files -base_dir ${ip_inst_dir} -no_ip_dir -files $dynamic_file_obj]
        set bd_file {}
        if { [xif_is_bd_ip_file $dynamic_file_obj bd_file] } {
          # do not delete classic bd file
        } else {
          # cleanup dynamic files for classic ip
          #if { [file exists $file] } {
          #  if {[catch {file delete -force $file} error_msg] } {
          #    send_msg_id export_ip_user_files-Tcl-011 ERROR "Failed to delete file ($dynamic_file_obj): $error_msg\n"
          #    return 1
          #  }
          #}
        }
      }
    }

    # templates
    foreach template_file [get_files -quiet -all -of [get_ips -all -quiet $ip_name] -filter {FILE_TYPE == "Verilog Template" || FILE_TYPE == "VHDL Template"}] {
      if { [lsearch $l_static_files $template_file] != -1 } { continue }
      set file {}
      if { $a_vars(b_force) } {
        set file [extract_files -base_dir ${ip_inst_dir} -no_ip_dir -force -files $template_file]
      } else {
        set file [extract_files -base_dir ${ip_inst_dir} -no_ip_dir -files $template_file]
      }
    }

    xif_export_mem_init_files_for_ip $obj
  }

  return 0
}

proc xif_get_extracted_static_file_path { src_ip_file } { 
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars

  set ipstatic_file_path {}

  # get the parent composite file for this static file
  set parent_comp_file [get_property parent_composite_file -quiet [lindex [get_files -all [list "$src_ip_file"]] 0]]

  # calculate destination path
  set ipstatic_file_path [xcs_find_ipstatic_file_path $src_ip_file $parent_comp_file $a_vars(ipstatic_dir)]

  # skip if file exists
  if { ({} != $ipstatic_file_path) && ([file exists $ipstatic_file_path]) } {
    return $ipstatic_file_path
  }

  # if parent composite file is empty, extract to default ipstatic dir (the extracted path is expected to be 
  # correct in this case starting from the library name (e.g fifo_generator_v13_0_0/hdl/fifo_generator_v13_0_rfs.vhd))
  if { {} == $parent_comp_file } {
    set extracted_file [extract_files -no_ip_dir -quiet -files [list "$src_ip_file"] -base_dir $a_vars(ipstatic_dir)]
    #puts extracted_file_no_pc=$extracted_file
    set ipstatic_file_path $extracted_file
  } else {
    # parent composite is not empty, so get the ip output dir of the parent composite and subtract it from source file
    set parent_ip_name [file root [file tail $parent_comp_file]]
    set ip_output_dir [get_property ip_output_dir [get_ips -all $parent_ip_name]]
    #puts src_ip_file=$src_ip_file
	
    # get the source ip file dir
    set src_ip_file_dir [file dirname $src_ip_file]

    # strip the ip_output_dir path from source ip file and prepend static dir 
    set lib_dir [xcs_get_sub_file_path $src_ip_file_dir $ip_output_dir]
    set target_extract_dir [file normalize [file join $a_vars(ipstatic_dir) $lib_dir]]
    #puts target_extract_dir=$target_extract_dir
	
    set extracted_file [extract_files -no_path -quiet -files [list "$src_ip_file"] -base_dir $target_extract_dir]
    #puts extracted_file_with_pc=$extracted_file

    set ipstatic_file_path $extracted_file
  }

  return $ipstatic_file_path
}

proc xif_delete_ip_inst_dir { dir ip_name } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  if { [catch {file delete -force $dir} _error] } {
    send_msg_id export_ip_user_files-Tcl-008 INFO "Failed to remove IP instance directory:(${dir}): $_error\n"
  } else {
    #send_msg_id export_ip_user_files-Tcl-009 INFO "Deleted IP instance directory:$dir\n"
  }

  # sim_scripts/<ip_instance> 
  set ip_inst_scripts_dir [file normalize [file join $a_vars(scripts_dir) $ip_name]]
  if { [catch {file delete -force $ip_inst_scripts_dir} _error] } {
    send_msg_id export_ip_user_files-Tcl-010 INFO "Failed to remove IP instance scripts directory:(${ip_inst_scripts_dir}): $_error\n"
  } else {
    #send_msg_id export_ip_user_files-Tcl-009 INFO "Deleted IP instance scripts directory:$ip_inst_scripts_dir\n"
  }
}

proc xif_get_dynamic_core_container_ip_name { src_file_obj ip_name } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  set xcix_file [get_property core_container $src_file_obj]
  set core_name [file root [file tail $xcix_file]]
  if { {} != $core_name } {
    return $core_name
  }
  return $ip_name
}

proc xif_is_bd_ip_file { src_file_obj bd_file_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set b_is_bd 0
  return 0
  upvar $bd_file_arg bd_file
  
  set MAX_PARENT_COMP_LEVELS 5
  set count 0
  while (1) {
    incr count
    if { $count > $MAX_PARENT_COMP_LEVELS } { break }
    set props [list_property $src_file_obj]
    if { [lsearch $props "PARENT_COMPOSITE_FILE"] == -1 } {
      break
    }
    set parent_file [get_property parent_composite_file -quiet $src_file_obj]
    if { {.bd} == [file extension $parent_file] } {
      set b_is_bd 1
      set bd_file $parent_file
      break
    }
  }
  return $b_is_bd
}

proc xif_export_bd { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  variable l_valid_data_file_extns
  variable l_compiled_libraries

  set ip_name [file root [file tail $obj]]
  set ip_extn [file extension $obj]
  set bd_file [get_files -quiet ${ip_name}.bd]

  set l_static_files_to_delete [list]
  #
  # static files
  #
  set l_static_files [get_files -quiet -all -of_objects $bd_file -filter {USED_IN=~"*ipstatic*"}]
  foreach src_ip_file $l_static_files {
    set filename [file tail $src_ip_file]
    set file_obj $src_ip_file
    if { {} == $file_obj } { continue; }
    if { [lsearch -exact [list_property $file_obj] {IS_USER_DISABLED}] != -1 } {
      if { [get_property {IS_USER_DISABLED} $file_obj] } {
        continue;
      }
    }

    set src_ip_file [string map {\\ /} $src_ip_file]
    # /ipshared/xilinx.com/xbip_utils_v3_0/4f162624/hdl/xbip_utils_v3_0_vh_rfs.vhd 
    #puts src_ip_file=$src_ip_file
  
    set comps [lrange [split $src_ip_file "/"] 0 end]
    set to_match "xilinx.com"
    set index 0
    set b_found [xcs_find_comp comps index $to_match]
    if { !$b_found } {
      set to_match "user_company"
      set b_found [xcs_find_comp comps index $to_match]
    }
    if { !$b_found } {
      continue;
    }

    set extracted_static_file_path {}

    if { $a_vars(b_use_static_lib) } {
      set file_type {}
      if { [lsearch -exact [list_property $file_obj] {FILE_TYPE}] != -1 } {
        set file_type [get_property file_type $file_obj]
      }
      if { ({Verilog Header} == $file_type) || ({Verilog/SystemVerilog Header} == $file_type) } {
        # consider verilog header files always for pre-compile flow
      } else {
        # is compiled library available from clibs? continue, else extract to ip_user_files dir
        if { [lsearch -exact [list_property $file_obj] {LIBRARY}] != -1 } {
          set library [get_property library $file_obj]
          if { [lsearch -exact $l_compiled_libraries $library] != -1 } {
            # This is causing performance issues (in case the file was present in ipstatic dir from previous run)
            #set extracted_static_file_path [xif_get_extracted_static_file_path_bd $comps $index]
            #lappend l_static_files_to_delete $extracted_static_file_path
            continue
          }
        }
      }
    }

    # not extracted yet? extract it
    if { {} == $extracted_static_file_path } {
      set extracted_static_file_path [xif_get_extracted_static_file_path_bd $comps $index]
    }

    # if reset requested, delete IPI file from ipstatic
    if { $a_vars(b_reset) } {
      if { [file exists $extracted_static_file_path] } {
        if { [catch {file delete -force $extracted_static_file_path} _error] } {
          #send_msg_id export_ip_user_files-Tcl-003 INFO "Failed to remove static simulation file (${extracted_static_file_path}): $_error\n"
        } else {
          #send_msg_id export_ip_user_files-Tcl-009 INFO "Deleted static file:$extracted_static_file_path\n"
        }
      }
    }
  }

  # delete pre-compiled static files from ip_user_files
  foreach static_file $l_static_files_to_delete {
    set repo_file [file normalize $static_file]
    if { [file exists $repo_file] } {
      if { [catch {file delete -force $repo_file} _error] } {
        send_msg_id export_ip_user_files-Tcl-003 INFO "Failed to remove static simulation file (${repo_file}): $_error\n"
      } else {
        #send_msg_id export_ip_user_files-Tcl-009 INFO "Deleted static file:$repo_file\n"
      }
    }
  }

  if { $a_vars(b_use_static_lib) } {
    xif_delete_empty_dirs $a_vars(ipstatic_dir)
  }

  # set bd instance dir <ip_user_files>/bd/<ip_instance>
  set bd_inst_dir [file normalize [file join $a_vars(bd_base_dir) $ip_name]]

  # if sync requested delete bd/<bd_instance> and sim_scipts/<bd_instance>
  if { $a_vars(b_sync) || $a_vars(b_reset) } {
    if { [catch {file delete -force $bd_inst_dir} _error] } {
      send_msg_id export_ip_user_files-Tcl-009 INFO "Failed to remove BD instance dirrectory:(${bd_inst_dir}): $_error\n"
    } else {
      #send_msg_id export_ip_user_files-Tcl-009 INFO "Deleted BD instance directory:$bd_inst_dir\n"
    }
    # sim_scripts/<bd_instance> 
    set bd_inst_scripts_dir [file normalize [file join $a_vars(scripts_dir) $ip_name]]
    if { [catch {file delete -force $bd_inst_scripts_dir} _error] } {
      send_msg_id export_ip_user_files-Tcl-009 INFO "Failed to remove BD instance scripts dirrectory:(${bd_inst_scripts_dir}): $_error\n"
    } else {
      #send_msg_id export_ip_user_files-Tcl-009 INFO "Deleted BD instance scripts directory:$bd_inst_scripts_dir\n"
    }
    # delete sim_scripts, if empty
    if { [file isdirectory $a_vars(scripts_dir)] } {
      set sim_script_dir_files [glob -nocomplain -directory $a_vars(scripts_dir) *]
      #puts sim_script_dir_files=$sim_script_dir_files
      if { [llength $sim_script_dir_files] == 0 } {
        if { [catch {file delete -force $a_vars(scripts_dir)} _error] } {
          send_msg_id export_ip_user_files-Tcl-009 INFO "Failed to remove sim scripts dirrectory:($a_vars(scripts_dir)): $_error\n"
        } else {
          #send_msg_id export_ip_user_files-Tcl-009 INFO "Deleted sim scripts directory:$a_vars(scripts_dir)\n"
        }
      }
    }
  }

  #
  # dynamic files
  #
  if { $a_vars(b_reset) } {
    # no op (for reset, we don't want to refetch the dynamic files. These files will be fetched by generate target or export_ip_user_files flow.)
  } else {
    # for default and sync flow, the dynamic files will be fetched always
    foreach dynamic_file [get_files -quiet -all -of_objects $bd_file -filter {USED_IN=~"*simulation*"}] {
      if { [lsearch $l_static_files $dynamic_file] != -1 } { continue }
      if { {.xci} == [file extension $dynamic_file] } { continue }
      if { [lsearch -exact $l_valid_data_file_extns [file extension $dynamic_file]] >= 0 } { continue }
      set dynamic_file [string map {\\ /} $dynamic_file]
      #puts dynamic_file=$dynamic_file
  
      set hdl_dir_file {}
      set ip_lib_dir {}
      set target_ip_lib_dir {}
      set repo_file [xif_get_dynamic_sim_file_bd $ip_name $dynamic_file hdl_dir_file ip_lib_dir target_ip_lib_dir]
  
      # iterate over the hdl_dir_file comps and copy to target
      set comps [lrange [split $hdl_dir_file "/"] 1 end]
      set src   $ip_lib_dir
      set dst   $target_ip_lib_dir
      foreach comp $comps {
        append src "/";append src $comp
        append dst "/";append dst $comp
        #puts src=$src
        #puts dst=$dst
        if { [file isdirectory $src] } {
          if { ![file exists $dst] } {
            if {[catch {file mkdir $dst} error_msg] } {
              send_msg_id export_ip_user_files-Tcl-013 ERROR "Failed to create the directory ($dst): $error_msg\n"
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
  }

  return 0
}

proc xif_get_extracted_static_file_path_bd { comps index } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars

  set file_path_str [join [lrange $comps 0 $index] "/"]
  set ip_lib_dir "$file_path_str"

  # /demo/ipshared/xilinx.com/xbip_utils_v3_0
  #puts ip_lib_dir=$ip_lib_dir
  set ip_lib_dir_name [file tail $ip_lib_dir]
   
  # create target library dir
  set target_ip_lib_dir [file join $a_vars(ipstatic_dir) $ip_lib_dir_name]
  if { ![file exists $target_ip_lib_dir] } {
    if {[catch {file mkdir $target_ip_lib_dir} error_msg] } {
      send_msg_id export_ip_user_files-Tcl-012 ERROR "Failed to create the directory ($target_ip_lib_dir): $error_msg\n"
      continue
    }
  }
  # /demo/project_1/project_1_sim/ipstatic/xbip_utils_v3_0
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

  set dst_file [file join $target_ip_lib_dir $ip_hdl_sub_dir]
  # /demo/project_1/project_1_sim/ipstatic/xbip_utils_v3_0/hdl/xbip_utils_v3_0_vh_rfs.vhd
  #puts dst_file=$dst_file

  xif_copy_bd_static_files_recursive $ip_hdl_dir $target_ip_lib_dir

  return $dst_file
}

proc xif_delete_empty_dirs { root_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set dir_files [glob -nocomplain -directory $root_dir *]
  if { [llength $dir_files] == 0 } {
    [catch {file delete -force $root_dir} error_msg]
    return
  }

  set b_empty true
  # find and delete empty dirs
  foreach dir $dir_files {
    if { [xif_is_empty_dir $dir] } {
      if { [catch {file delete -force $dir} _error] } {
        send_msg_id export_ip_user_files-Tcl-009 INFO "Failed to remove dirrectory:($dir): $_error\n"
      }
    } else {
      if { $b_empty } {
        set b_empty false
      }
    }
  }

  if { $b_empty } {
    # just in case something is present, cleanup
    foreach file [glob -nocomplain -directory $root_dir *] {
      [catch {file delete -force $file} error_msg]
    }
    [catch {file delete -force $root_dir} error_msg]
  }
}

proc xif_is_empty_dir { dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  if { [file isdirectory $dir] } {
    set files [glob -nocomplain -directory $dir *]

    # any files in this dir?
    if { [llength $files] == 0 } {
      return true
    }

    foreach file $files {
      if { [file isdirectory $file] } {
        return [xif_is_empty_dir $file]
      } else {
        return false
      }
    }
  }
  return true 
}

proc xif_get_dynamic_sim_file_bd { ip_name dynamic_file hdl_dir_file_arg ip_lib_dir_arg target_ip_lib_dir_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_cache_get_dynamic_sim_file_bd
  variable a_vars
  upvar $hdl_dir_file_arg hdl_dir_file
  upvar $ip_lib_dir_arg ip_lib_dir
  upvar $target_ip_lib_dir_arg target_ip_lib_dir

  # cache hash, _ prepend supports empty args
  set s_hash "_${ip_name}-${dynamic_file}"

  if { [info exists a_cache_get_dynamic_sim_file_bd($s_hash)] } {
    set hdl_dir_file      $a_cache_get_dynamic_sim_file_bd("${s_hash}-hdl_dir_file") 
    set ip_lib_dir        $a_cache_get_dynamic_sim_file_bd("${s_hash}-ip_lib_dir") 
    set target_ip_lib_dir $a_cache_get_dynamic_sim_file_bd("${s_hash}-target_ip_lib_dir")
    
    return $a_cache_get_dynamic_sim_file_bd($s_hash) 
  }

  # dynamic_file: /demo/project_1/project_1.srcs/sources_1/bd/design_1/ip/design_1_cmpy_0_0/demo_tb/tb_design_1_cmpy_0_0.vhd 
  set full_comps [lrange [split $dynamic_file "/"] 0 end]
  set comps [lrange $full_comps 1 end]

  set to_match "$ip_name"
  set index 0
  set b_found [xcs_find_comp comps index $to_match]

  #incr index -1
  set file_path_str [join [lrange $full_comps 0 $index] "/"]

  set ip_lib_dir "$file_path_str"
  set a_cache_get_dynamic_sim_file_bd("${s_hash}-ip_lib_dir") $ip_lib_dir
  # ip_lib_dir: /demo/project_1/project_1.srcs/sources_1/bd/design_1 
  #puts ip_lib_dir=$ip_lib_dir

  set target_ip_lib_dir [file join $a_vars(bd_base_dir) ${ip_name}]
  set a_cache_get_dynamic_sim_file_bd("${s_hash}-target_ip_lib_dir") $target_ip_lib_dir
  # target_ip_lib_dir: /demo/project_1/project_1.ip_user_files/bd/design_1
  #puts target_ip_lib_dir=$target_ip_lib_dir

  set hdl_dir_file [join [lrange $full_comps $index end] "/"]
  set a_cache_get_dynamic_sim_file_bd("${s_hash}-hdl_dir_file") $hdl_dir_file
  # hdl_dir_file: ip/design_1_cmpy_0_0/demo_tb/tb_design_1_cmpy_0_0.vhd 
  #puts hdl_dir_file=$hdl_dir_file

  set repo_file [file join $a_vars(bd_base_dir) $hdl_dir_file]
  # repo_file: /demo/project_1/project_1.ip_user_files/bd/design_1/ip/design_1_cmpy_0_0/demo_tb/tb_design_1_cmpy_0_0.vhd 
  #puts repo_file=$repo_file

  return [set a_cache_get_dynamic_sim_file_bd($s_hash) $repo_file]
}

proc xif_copy_bd_static_files_recursive { src dst } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
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
        xif_copy_bd_static_files_recursive $file $dst_dir
      } else {
        set filename [file tail $file]
        set dst_file [file join $dst $filename]
        if { ![file exists $dst] } {
          if {[catch {file mkdir $dst} error_msg] } {
            send_msg_id export_ip_user_files-Tcl-016 WARNING "Failed to create directory '$dst_dir' : $error_msg\n"
          }
        }

        if { [xif_filter $file] } {
          # filter these files
        } else {
          if { (![file exist $dst_file]) || $a_vars(b_force) } {
            if {[catch {file copy -force $file $dst} error_msg] } {
              send_msg_id export_ip_user_files-Tcl-017 WARNING "Failed to copy file '$file' to '$dst' : $error_msg\n"
            } else {
              #send_msg_id export_ip_user_files-Tcl-018 STATUS " + Exported file:'$dst_file'\n"
            }
          }
        }
      }
    }
  } else {
    set filename [file tail $src]
    set dst_file [file join $dst $filename]
    if { [xif_filter $src] } {
      # filter these files
    } else {
      if { (![file exist $dst_file]) || $a_vars(b_force) } {
        if {[catch {file copy -force $src $dst} error_msg] } {
          send_msg_id export_ip_user_files-Tcl-019 WARNING "Failed to copy file '$src' to '$dst' : $error_msg\n"
        } else {
          #send_msg_id export_ip_user_files-Tcl-020 STATUS " + Exported file:'$dst_file'\n"
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

proc xif_create_mem_dir {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  if { ! [file exists $a_vars(mem_dir)] } {
    if {[catch {file mkdir $a_vars(mem_dir)} error_msg] } {
      send_msg_id export_ip_user_files-Tcl-024 ERROR "Failed to create the directory ($a_vars(mem_dir)): $error_msg\n"
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
      send_msg_id export_ip_user_files-Tcl-025 ERROR "Failed to create the directory ($a_vars(base_dir)): $error_msg\n"
      return 1
    }
  }


  #if { ! [file exists $a_vars(scripts_dir)] } {
  #  if {[catch {file mkdir $a_vars(scripts_dir)} error_msg] } {
  #    send_msg_id export_ip_user_files-Tcl-026 ERROR "Failed to create the directory ($a_vars(scripts_dir)): $error_msg\n"
  #    return 1
  #  }
  #}

  if { $a_vars(b_use_static_lib) } {
    # do not create static lib dir
  } else {
    if { ! [file exists $a_vars(ipstatic_dir)] } {
      if {[catch {file mkdir $a_vars(ipstatic_dir)} error_msg] } {
        send_msg_id export_ip_user_files-Tcl-027 ERROR "Failed to create the directory $a_vars(ipstatic_dir): $error_msg\n"
        return 1
      }
    }
  }

  #if { ! [file exists $a_vars(ip_base_dir)] } {
  #  if {[catch {file mkdir $a_vars(ip_base_dir)} error_msg] } {
  #    send_msg_id export_ip_user_files-Tcl-028 ERROR "Failed to create the directory $a_vars(ip_base_dir): $error_msg\n"
  #    return 1
  #  }
  #}

  #if { ! [file exists $a_vars(bd_base_dir)] } {
  #  if {[catch {file mkdir $a_vars(bd_base_dir)} error_msg] } {
  #    send_msg_id export_ip_user_files-Tcl-029 ERROR "Failed to create the directory $a_vars(bd_base_dir): $error_msg\n"
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
    set dir $a_vars(s_xport_dir)
  }
  set a_vars(base_dir) [file normalize $dir]

  # create readme
  # make sure the base dir exists, if not created
  if { ![file exists $a_vars(base_dir)] } {
    if {[catch {file mkdir $a_vars(base_dir)} error_msg] } {
      send_msg_id export_ip_user_files-Tcl-012 ERROR "Failed to create the directory ($a_vars(base_dir)): $error_msg\n"
    }
  }

  if { [file isdirectory $a_vars(base_dir)] } {
    set readme_file "$a_vars(base_dir)/README.txt"
    if { ![file exists $readme_file] } {
      set fh 0
      if {[catch {open $readme_file w} fh]} {
        send_msg_id export_ip_user_files-Tcl-030 ERROR "failed to open file to write ($readme_file)\n"
      } else {
        puts $fh "The files in this directory structure are automatically generated and managed by Vivado. Editing these files is not recommended."
        close $fh
      }
    }
  } else {  
    if {[catch {file mkdir $a_vars(base_dir)} error_msg] } {
      send_msg_id export_ip_user_files-Tcl-012 ERROR "Failed to create the directory ($a_vars(base_dir)): $error_msg\n"
    }
  }

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
  set a_vars(scripts_dir) [file normalize [file join $a_vars(base_dir) "sim_scripts"]]

  # set path separator
  set a_vars(base_dir)     [string map {\\ /} $a_vars(base_dir)]
  set a_vars(ipstatic_dir) [string map {\\ /} $a_vars(ipstatic_dir)]
  set a_vars(mem_dir)      [string map {\\ /} $a_vars(mem_dir)]
  set a_vars(scripts_dir)      [string map {\\ /} $a_vars(scripts_dir)]
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
    set file [extract_files -no_paths -force -files [list "$file"] -base_dir $a_vars(mem_dir)]
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

proc xif_get_dynamic_sim_file { ip_name src_file_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars

  if { ! [xif_valid_object_types $src_file_obj "file"] } {
    send_msg_id export_ip_user_files-Tcl-045 ERROR "[lindex [info level [info level]] 0] - only accepts 'file' type objects"
  }

  set comps [lrange [split $src_file_obj "/"] 1 end]
  set index 0
  set b_found false
  set to_match {}
  if { $a_vars(b_is_managed) } {
    # for managed ip get the path from core container ip name (below)
  } else {
    set to_match "ip"
    set b_found [xcs_find_comp comps index $to_match]
    # try ip name
    if { !$b_found } {
      set to_match "$ip_name"
      set b_found [xcs_find_comp comps index $to_match]
    }
  }

  if { !$b_found } {
    # get the core container ip name of this source and find from repo area
    set xcix_file [string trim [get_property core_container $src_file_obj]]
    if { {} == $xcix_file } {
      set comp_file [get_property parent_composite_file -quiet $src_file_obj]
      set ip_name [file root [file tail $comp_file]]
    } else {
      set ip_name [file root [file tail $xcix_file]]
    }
    set to_match "$ip_name"
    set b_found [xcs_find_comp comps index $to_match]
  }

  if { ! $b_found } {
    return $src_file_obj
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

proc xif_cache_result {args} {
  # Summary:
  # Will return already generated results if they exists else it will run the command
  # NOTICE: The xif_cache_result command can only be used with procs that _do_not_ use upvar
  #         If you need to cache a proc that leverages upvar, then see a_cache_get_dynamic_sim_file_bd
  # Argument Usage:
  # Return Value:
  variable a_cache_result

  set cache_hash [regsub -all {[\[\]]} $args {|}]; # replace "[" and "]" with "|"
  set cache_hash [uplevel expr \"$cache_hash\"]

  # Validation - for every call we compare the cache to the actual values
  #puts "XIF_CACHE_ARGS: '${args}'"
  #puts "XIF_CACHE_HASH: '${cache_hash}'"

  #if { [info exists a_cache_result($cache_hash)] } {
  #  #puts " CACHE_EXISTS"
  #  set old $a_cache_result($cache_hash)
  #  set a_cache_result($cache_hash) [uplevel eval $args]
  #  if { "$a_cache_result($cache_hash)" != "$old" } {
  #    error "CACHE_VALIDATION: difference detected, halting flow\n OLD: ${old}\n NEW: $a_cache_result($cache_hash)"
  #  }
  #  return $a_cache_result($cache_hash) 
  #}

  # NOTE: to disable caching (with this proc) comment out this line:
  if { [info exists a_cache_result($cache_hash)] } {
    return $a_cache_result($cache_hash)
  }

  return [set a_cache_result($cache_hash) [uplevel eval $args]]
}


proc xif_valid_object_types { objs allowedTypes } {
  if { [llength $objs] == 0 } {
    return true; # Zero objects is considered a passing condition
  }
  # TODO: more efficient way than throw/catch?
  if { [catch {get_property CLASS $objs} objTypes] } {
    #set message "[lindex [info level [info level]] 0] - only accepts first-class Tcl objects (CLASS property is expected to exist), received: '[join $objs ',\ ']'"
    #puts $message
    #send_msg_id export_ip_user_files-Tcl-044 ERROR $message
    #error $message
    return false
  }
  set nonAllowedObjTypes [struct::set difference [lsort -unique ${objTypes}] [lsort -unique ${allowedTypes}]]
  if { [llength $nonAllowedObjTypes] > 0 } {
    #set message "[lindex [info level [info level]] 0] - only accepts '[join $allowedTypes ',\ ' ]' type objects, received '[join $nonAllowedObjTypes ',\ ']'"
    #puts $message
    #send_msg_id export_ip_user_files-Tcl-045 ERROR $message
    #error $message
    return false
  }
  return true
}
}
