####################################################################################
#
# setup_ip_static_library.tcl
#
# Script created on 08/15/2015 by Raj Klair (Xilinx, Inc.)
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::projutils {
  namespace export setup_ip_static_library
}

namespace eval ::tclapp::xilinx::projutils {

proc isl_init_vars {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_isl_vars
  set a_isl_vars(ipstatic_dir)      [file normalize "ipstatic"]
  set a_isl_vars(b_dir_specified)   0
  set a_isl_vars(b_ip_specified)    0
  set a_isl_vars(b_project_mode)    1
  set a_isl_vars(b_install_mode)    0
  set a_isl_vars(b_no_update_catalog)    0
  set a_isl_vars(b_force)           0
  set a_isl_vars(b_project_switch)  0
  set a_isl_vars(co_file_list)      ""
  set a_isl_vars(ip_incl_dir)       ""

  variable compile_order_data       [list]

  variable l_ip_repo_paths
  set l_ip_repo_paths               [list]
  set a_isl_vars(b_ip_repo_paths_specified)     0

  set l_ips                          [list]
  set a_isl_vars(b_ips_specified)    0

  variable l_static_files
  set l_static_files                [list]

  variable l_valid_data_file_extns
  set l_valid_data_file_extns       [list ".mif" ".coe"]

  set_param tcl.statsThreshold      100

  variable l_valid_ip_extns         [list]
  set l_valid_ip_extns              [list ".xci" ".bd" ".slx"]

  # common - imported to <ns>::xcs_* - home is defined in <app>.tcl
  if { ! [info exists ::tclapp::xilinx::projutils::_xcs_defined] } {
    variable home
    source -notrace [file join $home "common" "utils.tcl"]
  }
}

proc setup_ip_static_library {args} {
  # Summary:
  # Extract IP static files from the project or repository and prepare it for compile_simlib
  # Argument Usage:
  # [-directory <arg>]: Extract static files in the specified directory
  # [-ip_repo_path <arg>]: Extract static files from the specified IP repository path
  # [-ips <arg> = Empty]: Extract static files for the specified IPs only
  # [-project]: Extract static files for the current project
  # [-install]: Extract static files for the IP catalog
  # [-no_update_catalog]: Do no update IP catalog
  # [-force]: Overwrite static files

  # Return Value:
  # None

  # Categories: simulation, xilinxtclstore

  variable a_isl_vars
  variable l_static_files
  variable l_ip_repo_paths
  variable l_ips
  isl_init_vars

  set a_isl_vars(options) [split $args " "]
  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-directory" { incr i;set a_isl_vars(ipstatic_dir) [lindex $args $i];set a_isl_vars(b_dir_specified) 1 }
      "-ip_repo_path" { incr i;set l_ip_repo_paths [lindex $args $i];set a_isl_vars(b_ip_repo_paths_specified)  1 }
      "-ips"       { incr i;set l_ips [lindex $args $i];set a_isl_vars(b_ips_specified)                    1 }
      "-project"   { set a_isl_vars(b_project_mode) 1;set a_isl_vars(b_project_switch)  1 }
      "-install"   { set a_isl_vars(b_install_mode) 1 }
      "-no_update_catalog"   { set a_isl_vars(b_no_update_catalog) 1 }
      "-force"     { set a_isl_vars(b_force) 1 }
      default {
        if { [regexp {^-} $option] } {
          send_msg_id setup_ip_static_library-Tcl-001 ERROR "Unknown option '$option', please type 'setup_ip_static_library -help' for usage info.\n"
        }
      }
    }
  }

  if { $a_isl_vars(b_project_switch) && $a_isl_vars(b_install_mode) } {
    [catch {send_msg_id setup_ip_static_library-Tcl-005 ERROR \
     "Please specify either -project or -install\n"} err]
    return
  }

  if { $a_isl_vars(b_install_mode) || $a_isl_vars(b_ip_repo_paths_specified) } {
    set a_isl_vars(b_project_mode) 0
  }

  if { $a_isl_vars(b_project_mode) } {
    if { {} == [current_project -quiet] } {
      [catch {send_msg_id setup_ip_static_library-Tcl-005 ERROR \
       "No open project. Please create or open a project before executing this command.\n"} err]
      return
    }
  } else {
    if { {} != [current_project -quiet] } {
      [catch {send_msg_id setup_ip_static_library-Tcl-005 ERROR \
       "Detected a project in opened state. Please close this project and re-run this command again.\n"} err]
      return
    }
  }

  if { $a_isl_vars(b_dir_specified) } {
    set a_isl_vars(ipstatic_dir) [file normalize $a_isl_vars(ipstatic_dir)]
  }
  set a_isl_vars(co_file_list) [file join $a_isl_vars(ipstatic_dir) "compile_order.txt"]
    
  if { $a_isl_vars(b_force) } {
    if { [file exists $a_isl_vars(ipstatic_dir)] } {
      foreach file_path [glob -nocomplain -directory $a_isl_vars(ipstatic_dir) *] {
        if {[catch {file delete -force $file_path} error_msg] } {
          [catch {send_msg_id setup_ip_static_library-Tcl-006 ERROR "failed to delete file ($a_isl_vars(file_path)): $error_msg\n"} err]
          return
        }
      }
    }

    if {[catch {file mkdir $a_isl_vars(ipstatic_dir)} error_msg] } {
      send_msg_id setup_ip_static_library-Tcl-007 ERROR "failed to create the directory ($a_isl_vars(ipstatic_dir)): $error_msg\n"
      return 1
    }
  }

  set a_isl_vars(ip_incl_dir) [file join $a_isl_vars(ipstatic_dir) "incl"]
  if { ![file exists $a_isl_vars(ip_incl_dir)] } {
    if {[catch {file mkdir $a_isl_vars(ip_incl_dir)} error_msg] } {
      send_msg_id setup_ip_static_library-Tcl-022 ERROR "failed to create the directory ($a_isl_vars(ip_incl_dir)): $error_msg\n"
    }
  }

  if { $a_isl_vars(b_project_mode) } {
    isl_extract_proj_files
    send_msg_id setup_ip_static_library-Tcl-008 INFO "Library created:$a_isl_vars(ipstatic_dir)\n"
  } elseif { $a_isl_vars(b_install_mode) } {
    isl_extract_install_files
  } elseif { $a_isl_vars(b_ip_repo_paths_specified) } {
    isl_extract_repo_static_files
  }

  return
}

proc isl_extract_proj_files { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_isl_vars
  variable l_ips
  if { [isl_fetch_compile_order_data] } {
    return
  }
  send_msg_id setup_ip_static_library-Tcl-009 INFO "Creating static source library for compile_simlib...\n"
  set ips [get_ips -quiet]
  if { $a_isl_vars(b_ips_specified) } {
    if { [llength $l_ips] > 0 } {
      set ips [list]
      foreach ip $l_ips {
        set ip_name [file root [file tail $ip]]
        lappend ips [get_ips $ip_name]
      }
    } else {
      send_msg_id setup_ip_static_library-Tcl-009 INFO "No IPs found.\n"
      return
    }
  } 
  foreach obj $ips {
    set file_extn [file extension $obj]
    if { {} != $file_extn } {
      if { [lsearch -exact $l_valid_ip_extns ${file_extn}] == -1 } {
        continue
      }
    }
    if { [isl_export_files $obj] } {
      continue
    }
  }
  return
}

proc isl_export_files { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_isl_vars
  if { {} == $obj } { return 0 }

  set ip_extn [file extension $obj]
  # no extension, just ip name
  if { {} == $ip_extn } {
    set ip_name [file root [file tail $obj]]
    set file_obj [get_ips -all -quiet $ip_name]
    # is bd?
    if { [lsearch -exact [list_property $file_obj] {SCOPE}] != -1 } {
      set bd_file [get_property {SCOPE} $file_obj]
      if { {} != $bd_file } {
        set bd_extn [file extension $bd_file]
        if { {.bd} == $bd_extn } {
          isl_export_bd $bd_file
        }
      } else {
        set ip_file [get_property IP_FILE [get_ips -all -quiet $obj]]
        set ip [isl_get_ip_name $ip_file]
        # is BD ip? skip
        if { {} != $ip } {
          # no op
        } else {
          isl_export_ip $obj
        }
      }
    }
  } else {
    if { {.bd} == $ip_extn } {
      isl_export_bd $obj
    } elseif { ({.xci} == $ip_extn) || ({.xcix} == $ip_extn) } {
      set ip [isl_get_ip_name $obj]
      # is BD ip? skip
      if { {} != $ip } {
        # no op
      } else {
        #puts ip=$obj
        isl_export_ip $obj
      }
    } else {
      puts unknown_extn=$ip_extn
      return 0
    }
  }
  return 0
}

proc isl_export_ip { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_isl_vars
  variable l_valid_data_file_extns
  set file_paths [list]
  set ip_libs [list]

  set ip_name [file root [file tail $obj]]
  set ip_info "${ip_name}#xci"
  set ip_extn [file extension $obj]
  set b_container [xcs_is_core_container ${ip_name}.xci]
  #puts $ip_name=$b_container

  set l_static_files [list]
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
    set parent_comp_file [get_property parent_composite_file -quiet [lindex [get_files -all [list "$src_ip_file"]] 0]]
    if { {} == $parent_comp_file } {
      set extracted_file [extract_files -no_ip_dir -quiet -files [list "$src_ip_file"] -base_dir $a_isl_vars(ipstatic_dir)]
    } else {
      set parent_ip_name [file root [file tail $parent_comp_file]]
      set ip_output_dir [get_property ip_output_dir [get_ips -all $parent_ip_name]]
      set src_ip_file_dir [file dirname $src_ip_file]
      set lib_dir [xcs_get_sub_file_path $src_ip_file_dir $ip_output_dir]
      set target_extract_dir [file normalize [file join $a_isl_vars(ipstatic_dir) $lib_dir]]
      set extracted_file [extract_files -no_path -quiet -files [list "$src_ip_file"] -base_dir $target_extract_dir]
    }

    if { [lsearch -exact [list_property $file_obj] {LIBRARY}] != -1 } {
      set library [get_property "LIBRARY" $file_obj]
      if { [lsearch $ip_libs $library] == -1 } {
        lappend ip_libs $library
      }
      set file_type [string tolower [get_property "FILE_TYPE" $file_obj]]
      set ip_file_path $extracted_file
      set data "$library,$ip_file_path,$file_type,static"
      lappend file_paths $ip_file_path,$file_type
      lappend ip_data $data
    }
  }
  isl_create_order_file $ip_data $ip_libs
  isl_copy_incl_file $file_paths
  isl_update_compile_order_data $ip_data
}

proc isl_export_bd { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_isl_vars

  set file_paths [list]
  set ip_libs [list]

  set ip_name [file root [file tail $obj]]
  set ip_extn [file extension $obj]
  set ip_info "${ip_name}#bd"

  #
  # static files
  #
  set l_static_files [list]
  set ip_data [list]
  set l_static_files [get_files -quiet -all -of_objects [get_files -quiet ${ip_name}.bd] -filter {USED_IN=~"*ipstatic*"}]
  foreach src_ip_file $l_static_files {
    set file_obj [lindex [get_files -quiet -all [list "$src_ip_file"]] 0]
    set library {}
    if { [lsearch -exact [list_property $file_obj] {LIBRARY}] != -1 } {
      set library [get_property "LIBRARY" $file_obj]
    }
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
    if { {} != $library } {
      set ip_lib_dir_name $library
    }
    if { [lsearch $ip_libs $ip_lib_dir_name] == -1 } {
      lappend ip_libs $ip_lib_dir_name
    }

    # create target library dir
    set target_ip_lib_dir [file join $a_isl_vars(ipstatic_dir) $ip_lib_dir_name]
    if { ![file exists $target_ip_lib_dir] } {
      if {[catch {file mkdir $target_ip_lib_dir} error_msg] } {
        send_msg_id setup_ip_static_library-Tcl-010 ERROR "failed to create the directory ($target_ip_lib_dir): $error_msg\n"
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

    if { [file exists $dst_file] } {
      # skip
    } else {
      isl_copy_files_recursive $ip_hdl_dir $target_ip_lib_dir
    }

    if { [lsearch -exact [list_property $file_obj] {LIBRARY}] != -1 } {
      set library [get_property "LIBRARY" $file_obj]
      set file_type [string tolower [get_property "FILE_TYPE" $file_obj]]
      #set ip_file_path "[xcs_get_relative_file_path $dst_file $a_isl_vars(ipstatic_dir)/$library]"
      set ip_file_path $dst_file
      set data "$library,$ip_file_path,$file_type,static"
      lappend file_paths $ip_file_path,$file_type
      lappend ip_data $data
    }
  }
  isl_create_order_file $ip_data $ip_libs
  isl_copy_incl_file $file_paths
  isl_update_compile_order_data $ip_data
}

proc isl_get_ip_name { src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set ip {}
  set file_obj [lindex [get_files -all -quiet $src_file] 0]
  if { {} == $file_obj } {
    set file_obj [lindex [get_files -all -quiet [file tail $src_file]] 0]
  }

  set props [list_property $file_obj]
  if { [lsearch $props parent_composite_file] != -1 } {
    set ip [get_property parent_composite_file -quiet $file_obj]
  }
  return $ip
}

proc isl_fetch_compile_order_data {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_isl_vars
  variable compile_order_data

  if { ![file exists $a_isl_vars(co_file_list)] } {
    return 0
  }

  if {[catch {open $a_isl_vars(co_file_list) r} fh]} {
    send_msg_id setup_ip_static_library-Tcl-011 ERROR "failed to open file for read ($a_isl_vars(co_file_list))\n"
    return 1
  }

  set compile_order_data [read $fh]
  close $fh

  set compile_order_data [split $compile_order_data "\n"]

  if {[catch {file delete -force $a_isl_vars(co_file_list)} error_msg] } {
    send_msg_id setup_ip_static_library-Tcl-012 ERROR "failed to delete file ($a_isl_vars(co_file_list)): $error_msg\n"
    return 1
  }

  return 0
}

proc isl_update_compile_order_data { ip_data } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_isl_vars
  variable compile_order_data

  # update current data
  foreach ip_data_info $ip_data {
    if { [lsearch $compile_order_data $ip_data_info] == -1 } {
      lappend compile_order_data $ip_data_info
    }
  }

  # now write fresh copy
  set fh 0
  if {[catch {open $a_isl_vars(co_file_list) w} fh]} {
    send_msg_id setup_ip_static_library-Tcl-013 ERROR "failed to open file for append ($a_isl_vars(co_file_list))\n"
    return 1
  }
  foreach data $compile_order_data {
    set data [string trim $data]
    if { [string length $data] == 0 } { continue; }
    puts $fh $data
  }
  close $fh
}

proc isl_add_vao_file {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_isl_vars

  # read compile order data
  set fh 0
  if {[catch {open $a_isl_vars(co_file_list) r} fh]} {
   send_msg_id setup_ip_static_library-Tcl-014 ERROR "failed to open file for read ($a_isl_vars(co_file_list))\n"
   return 1
  }
  set data [read $fh]
  close $fh
  set data [split $data "\n"]

  # delete analyze order file from all libraries (if exist)
  foreach line $data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; }
    set file_str [split $line {,}]
    set library   [string trim [lindex $file_str 0]]
    set vao_file [file normalize [file join $a_isl_vars(ipstatic_dir) $library "vhdl_analyze_order"]]
    if { [file exists $vao_file] } {
      if {[catch {file delete -force $vao_file} error_msg] } {
        send_msg_id setup_ip_static_library-Tcl-015 ERROR "failed to delete file ($vao_file): $error_msg\n"
        return 1
      }
    }
  }

  # create fresh copy of analyze order file for each library containing vhdl files
  foreach line $data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; }
    set file_str [split $line {,}]
    set library   [string trim [lindex $file_str 0]]
    set file_path [string trim [lindex $file_str 1]]
    set file_type [string tolower [string trim [lindex $file_str 2]]]

    # if not vhdl file type? continue
    if { {vhdl} != $file_type } { continue }
    set vao_file [file normalize [file join $a_isl_vars(ipstatic_dir) $library "vhdl_analyze_order"]]
    set fh 0
    if { [file exist $vao_file] } {
      if {[catch {open $vao_file a} fh]} {
        send_msg_id setup_ip_static_library-Tcl-016 ERROR "failed to open file for append ($vao_file)\n"
        continue
      }
    } else {
      if {[catch {open $vao_file w} fh]} {
        send_msg_id setup_ip_static_library-Tcl-017 ERROR "failed to open file for write ($vao_file)\n"
        continue
      }
    }
    puts $fh $file_path
    close $fh
  }
}

proc isl_add_incl_file { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_isl_vars

  # 1. read compile order data
  set fh 0
  if {[catch {open $a_isl_vars(co_file_list) r} fh]} {
   send_msg_id setup_ip_static_library-Tcl-014 ERROR "failed to open file for read ($a_isl_vars(co_file_list))\n"
   return 1
  }
  set data [read $fh]
  close $fh
  set data [split $data "\n"]

  # 2. delete include file from all libraries (if exist)
  isl_delete_include_files $data

  set static_incl_data           [list]
  set dynamic_incl_data          [list]
  set uniq_static_incl_lib_files [list]

  # 3. fetch all static include files from compile order data into incl_files collection (<library>#<file_path>)
  isl_fetch_all_static_include_files $data static_incl_data dynamic_incl_data uniq_static_incl_lib_files
 
  # 4. populate static include files in <library>/include.h with file path information
  isl_populate_static_incl_files $uniq_static_incl_lib_files

  # 5. iterate over all static verilog header files if any and copy to other static library dir (<library>/incl)
  isl_copy_static_include_files $data

  # 6. iterate over all dynamic verilog header files if any and copy to static library dir (<library>/incl)
  set v_filelist [list]
  isl_copy_static_include_with_dynamic_header_files $data $static_incl_data $dynamic_incl_data v_filelist

  # 7. iterate over all dynamic verilog header files if any and copy to static library dir (<library>/incl)
  isl_update_static_include_with_dynamic_header_files $data $v_filelist
} 

proc isl_delete_include_files { data } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_isl_vars
  foreach line $data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; }
    set file_str  [split $line {,}]
    set library   [string trim [lindex $file_str 0]]
    set incl_file [file normalize [file join $a_isl_vars(ipstatic_dir) $library "include.h"]]
    if { [file exists $incl_file] } {
      if { [catch {file delete -force $incl_file} error_msg ] } {
        send_msg_id setup_ip_static_library-Tcl-015 ERROR "failed to delete file ($incl_file): $error_msg\n"
      }
    }
  }
}

proc isl_fetch_all_static_include_files { data static_incl_data_arg dynamic_incl_data_arg uniq_static_incl_lib_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  upvar $static_incl_data_arg           static_incl_data
  upvar $dynamic_incl_data_arg          dynamic_incl_data
  upvar $uniq_static_incl_lib_files_arg uniq_static_incl_lib_files 

  set incl_files [list]
  foreach line $data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; }
    set file_str  [split $line {,}]
    set library   [string trim [lindex $file_str 0]]
    set file_path [string trim [lindex $file_str 1]]
    set file_type [string tolower [string trim [lindex $file_str 2]]]
    set type      [string tolower [string trim [lindex $file_str 3]]]

    if { {static} == $type } {
      lappend static_incl_data $line
    } elseif { {dynamic} == $type } {
      lappend dynamic_incl_data $line
      continue
    }
    if { ({verilog_header} == $file_type) || ({verilog header} == $file_type) } {
      set str "$library#$file_path"
      lappend incl_files $str
    }
  }
  # uniquify include files (just in case found)
  set incl_file_set [list]
  foreach file $incl_files {
    if { [lsearch -exact $incl_file_set $file] == -1 } {
      lappend incl_file_set $file
      lappend uniq_static_incl_lib_files $file
    }
  }
}

proc isl_populate_static_incl_files { uniq_static_incl_lib_files } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_isl_vars
  foreach file_str $uniq_static_incl_lib_files {
    set library   [lindex [split $file_str "#"] 0]
    set file_path [lindex [split $file_str "#"] 1]
    set incl_file [file normalize [file join $a_isl_vars(ipstatic_dir) $library "include.h"]]
    set fh 0
    if { [file exists $incl_file] } {
      if {[catch {open $incl_file a} fh]} {
        send_msg_id setup_ip_static_library-Tcl-028 ERROR "failed to open file for append ($incl_file)\n"
        continue
      }
    } else {
      if {[catch {open $incl_file w} fh]} {
        send_msg_id setup_ip_static_library-Tcl-028 ERROR "failed to open file for write ($incl_file)\n"
        continue
      }
    }
    puts $fh $file_path
    close $fh
  }
}

proc isl_copy_static_include_files { data } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_isl_vars

  # construct list of all static verilog headers
  set static_vh_filelist [list]
  set static_vh_libraries [list]
  
  foreach line $data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; }
    set file_str  [split $line {,}]
    set library   [string trim [lindex $file_str 0]]
    set file_path [string trim [lindex $file_str 1]]
    set file_type [string tolower [string trim [lindex $file_str 2]]]
    
    if { ({verilog_header} == $file_type) || ({verilog header} == $file_type) } {
      lappend static_vh_filelist "$library#$file_path"
      lappend static_vh_libraries "$library"
    }
  }

  # iterate over the compile order data and for all non verilog header static libraries, copy the static verilog headers collected above
  foreach line $data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; }
    set file_str  [split $line {,}]
    set library   [string trim [lindex $file_str 0]]
    set file_path [string trim [lindex $file_str 1]]
    set filename  [file tail $file_path]
    set file_type [string tolower [string trim [lindex $file_str 2]]]
    
    if { ({verilog_header} == $file_type) || ({verilog header} == $file_type) } {
      continue
    }
    
    # work on only those libraries that were not in the static vh libraries
    if { [lsearch $static_vh_libraries $library] != -1 } { continue }

    # if include file exist, get it's current header list, close and then open for update (skip if header already exist, else copy it)
    set incl_file [file normalize [file join $a_isl_vars(ipstatic_dir) $library "include.h"]]
    if { [file exists $incl_file] } {
      # check if the vh file already present
      set fh_exist 0
      if {[catch {open $incl_file r} fh_exist]} {
        send_msg_id setup_ip_static_library-Tcl-028 ERROR "failed to open file for append ($incl_file)\n"
      } else {
        set curr_data [read $fh_exist]
        close $fh_exist
        set curr_data [split $curr_data "\n"]

        # collect current header files from existing include.h
        set curr_vh_filelist [list]
        foreach file $curr_data {
          set file [string trim $file]
          if { [string length $file] == 0 } { continue; }
          set filename [file tail $file]
          lappend curr_vh_filelist $filename
        }

        # open this file for update 
        set fh_update 0
        if {[catch {open $incl_file a} fh_update]} {
          send_msg_id setup_ip_static_library-Tcl-028 ERROR "failed to open file for append ($incl_file)\n"
        } else {
          # check if header already present, if not copy
          foreach vh_file $static_vh_filelist {
            set v_lib       [lindex [split $vh_file {#}] 0]
            set v_file_path [lindex [split $vh_file {#}] 1]
            set v_file_name [file tail $v_file_path]
            if { [lsearch $curr_vh_filelist $v_file_name] == -1 } {
              isl_copy_header $fh_update $v_lib $v_file_path $v_file_name $library
            }
          }
          close $fh_update
        }
      }
    } else {
      # construct new include.h
      set fh_new 0
      if {[catch {open $incl_file w} fh_new]} {
        send_msg_id setup_ip_static_library-Tcl-028 ERROR "failed to open file for append ($incl_file)\n"
        continue
      }
      foreach vh_file $static_vh_filelist {
        set v_lib       [lindex [split $vh_file {#}] 0]
        set v_file_path [lindex [split $vh_file {#}] 1]
        set v_file_name [file tail $v_file_path]
        # copy file
        isl_copy_header $fh_new $v_lib $v_file_path $v_file_name $library
      }
      close $fh_new
    }
  }
}

proc isl_copy_header { fh v_lib v_file_path v_file_name library } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_isl_vars

  puts $fh "vh/$v_file_name"

  set src_file_path [file normalize [file join $a_isl_vars(ipstatic_dir) $v_lib $v_file_path]]
  set dst_dir [file normalize [file join $a_isl_vars(ipstatic_dir) $library "vh"]]

  if { ![file exists $dst_dir] } {
    if {[catch {file mkdir $dst_dir} error_msg] } {
      send_msg_id setup_ip_static_library-Tcl-022 ERROR "failed to create the directory ($dst_dir)): $error_msg\n"
      return
    }
  }

  # copy header file to <library>/vh
  set dst_file [file join $dst_dir $v_file_name]
  if { ![file exists $dst_file] } {
    if {[catch {file copy -force $src_file_path $dst_dir} error_msg] } {
      send_msg_id setup_ip_static_library-Tcl-026 WARNING "Failed to copy file '$src_file_path' to '$dst_dir' : $error_msg\n"
    }
  }
}

proc isl_copy_static_include_with_dynamic_header_files { data static_incl_data dynamic_incl_data v_filelist_arg } { 
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_isl_vars
  upvar $v_filelist_arg v_filelist

  # copy dynamic header files to each static library (<library>/vh/<header file>) and construct the list of all header files that were copied in v_filelist
  foreach line $dynamic_incl_data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; }
    set file_str  [split $line {,}]
    set library   [string trim [lindex $file_str 0]]
    set file_path [string trim [lindex $file_str 1]]
    set filename  [file tail $file_path]

    set src_file_path [file normalize [file join $a_isl_vars(ipstatic_dir) $library $file_path]]

    # now copy this verilog include file to all the static libraries and update include.h
    foreach static_line $static_incl_data {
      set sline [string trim $static_line]
      if { [string length $sline] == 0 } { continue; }
      set sfile_str [split $sline {,}]
      set slibrary  [string trim [lindex $sfile_str 0]]

      set dst_dir [file normalize [file join $a_isl_vars(ipstatic_dir) $slibrary "vh"]]
      if { ![file exists $dst_dir] } {
        if {[catch {file mkdir $dst_dir} error_msg] } {
          send_msg_id setup_ip_static_library-Tcl-022 ERROR "failed to create the directory ($dst_dir)): $error_msg\n"
        }
      }
      set dst_file [file join $dst_dir $filename]

      # update v_filelist with header file (unique list of header files)
      if { [lsearch $v_filelist "$filename"] == -1 } {
        lappend v_filelist "$filename"
      }

      # copy header file to <library>/vh
      if { ![file exists $dst_file] } {
        if {[catch {file copy -force $src_file_path $dst_dir} error_msg] } {
          send_msg_id setup_ip_static_library-Tcl-026 WARNING "Failed to copy file '$src_file_path' to '$dst_dir' : $error_msg\n"
        }
      }
    }
  }
}

proc isl_update_static_include_with_dynamic_header_files { data v_filelist } { 
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_isl_vars

  # 1. construct list of static libraries
  set l_static_libraries [list]

  foreach line $data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; }
    set file_str [split $line {,}]
    set library [string trim [lindex $file_str 0]]
    set type [string tolower [string trim [lindex $file_str 3]]]
    if { {static} == $type } {
      if { [lsearch $l_static_libraries "$library"] == -1 } {
        lappend l_static_libraries "$library"
      }
    }
  }

  # 2. now update include.h in each static library with the header files copied in previous step (v_filelist)
  foreach lib $l_static_libraries {
    set dst_dir [file normalize [file join $a_isl_vars(ipstatic_dir) $lib "vh"]]
    if { ![file exists $dst_dir] } {
      continue
    }
    set incl_file [file normalize [file join $a_isl_vars(ipstatic_dir) $lib "include.h"]]
    set fh 0
    if { [file exists $incl_file] } {
      if {[catch {open $incl_file a} fh]} {
        send_msg_id setup_ip_static_library-Tcl-028 ERROR "failed to open file for append ($incl_file)\n"
        continue
      } 
    } else {
      if {[catch {open $incl_file w} fh]} {
        send_msg_id setup_ip_static_library-Tcl-028 ERROR "failed to open file for write ($incl_file)\n"
        continue
      }
    }
    foreach v_file $v_filelist {
      puts $fh "vh/$v_file"
    }
    close $fh
  } 
}

proc isl_extract_repo_static_files { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_isl_vars
  variable l_ip_repo_paths

  create_project -in_memory
  if { [llength $l_ip_repo_paths] > 0 } {
    foreach repo_path [split [get_property ip_repo_paths [current_project]] " "] {
      lappend l_ip_repo_paths $repo_path
    }
    set ip_repo_path [join $l_ip_repo_paths " "]
    set_property ip_repo_paths "$ip_repo_path" [current_project]
  }

  if { !$a_isl_vars(b_no_update_catalog) } {
    [catch {update_ip_catalog -quiet} err]
  }

  set compile_order_data [list]
  set ip_libs [list]
  set ip_count 0
  set ip_component_filelist [list]
  puts -nonewline "."
  foreach ip_repo_path $l_ip_repo_paths {
    foreach ip_xml [isl_find_ip_comp_xml_files $ip_repo_path] {
      lappend ip_component_filelist $ip_xml
      incr ip_count
    }
  }

  # process single core library
  set b_extract_sub_cores "false"
  set current_index [isl_build_static_library $b_extract_sub_cores $ip_component_filelist ip_libs 0]

  # process multi core library
  set b_extract_sub_cores "true"
  set current_index [isl_build_static_library $b_extract_sub_cores $ip_component_filelist ip_libs $current_index]

  isl_write_compile_order

  close_project
 
  puts ""
  send_msg_id setup_ip_static_library-Tcl-023 INFO "Data extracted from repository. Inspected $ip_count IP libraries.\n\n"
  return 0
}

proc isl_build_static_library { b_extract_sub_cores ip_component_filelist ip_libs_arg coloumn_length } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_isl_vars
  upvar $ip_libs_arg ip_libs

  set max_length 100
  set count 0
  set current_index 0
  set limit $max_length

  if { $b_extract_sub_cores } {
    # continue from last index from previous isl_build_static_library call for single core library 
    set limit [expr $max_length - $coloumn_length]
    incr limit
  }

  foreach ip_xml $ip_component_filelist {
    set ip_dir  [file dirname $ip_xml]
    set ip_comp [ipx::open_core $ip_xml]
    set ip_def_name [get_property name $ip_comp]
    set vlnv    [get_property vlnv $ip_comp]
    puts -nonewline "."
    incr current_index
    
    # add next line if limit reached
    if { $count > $limit } {
      puts ""
      set current_index 0
      set count -2
      set limit $max_length
    }
    incr count

    foreach file_group [ipx::get_file_groups -of $ip_comp] {
      set type [get_property type $file_group]
      if { ([string last "simulation" $type] != -1) && ($type != "examples_simulation") } {
        set sub_lib_cores [get_property component_subcores $file_group]
        set sub_core_len [llength $sub_lib_cores]
        if { ($sub_core_len == 0) && ($b_extract_sub_cores) } { continue }
        if { ($sub_core_len > 0) && (!$b_extract_sub_cores) } { continue }
        set ordered_sub_cores [list]
        foreach sub_vlnv $sub_lib_cores {
          set ordered_sub_cores [linsert $ordered_sub_cores 0 $sub_vlnv]
        } 
        #puts "$vlnv=$ordered_sub_cores"
        foreach sub_vlnv $ordered_sub_cores {
          isl_extract_repo_sub_core_static_files $sub_vlnv $ip_libs
        }

        set ip_lib_dir {}
        set file_paths [list]
        set pcore_libs [list]
        set mcs_lib_name {}
        foreach static_file [ipx::get_files -filter {USED_IN=~"*ipstatic*"} -of $file_group] {
          set file_entry [split $static_file { }]
          lassign $file_entry file_key comp_ref file_group_name file_path
          set ip_file [lindex $file_entry 3]
          set type [isl_get_file_type $file_group $ip_file]
          set library [get_property library_name [ipx::get_files $ip_file -of_objects $file_group]]
          if { {} == $library } {
            puts ""
            send_msg_id setup_ip_static_library-Tcl-022 WARNING "Associated library not defined for '$ip_file' ($ip_def_name,$vlnv)\n"
          }
          if { {xil_defaultlib} == $library } {
            puts ""
            send_msg_id setup_ip_static_library-Tcl-022 WARNING "Associated library incorrectly set to $library for '$ip_file' ($ip_def_name,$vlnv)\n"
            continue
          }
          set full_ip_file_path [file normalize [file join $ip_dir $ip_file]]
          if { [lsearch $ip_libs $library] == -1 } {
            lappend ip_libs $library
          }

          if { [regexp {microblaze_mcs_v} $library] } {
            set mcs_lib_name $library
          } else {
            if { [lsearch $pcore_libs $library] == -1 } {
              lappend pcore_libs $library
            }
          }
          # <ipstatic_dir>/<library>
          set ip_lib_dir [file join $a_isl_vars(ipstatic_dir) $library]
          if { ![file exists $ip_lib_dir] } {
            if {[catch {file mkdir $ip_lib_dir} error_msg] } {
              send_msg_id setup_ip_static_library-Tcl-022 ERROR "failed to create the directory ($ip_lib_dir)): $error_msg\n"
            }
          }
          set data "$library,$full_ip_file_path,$type,static"
          lappend file_paths "$full_ip_file_path,$type"
          isl_add_to_compile_order $library $data
        }

        # for microblaze_mcs, create vao file for each pcore library and then for microblaze_mcs
        if { {microblaze_mcs} == $ip_def_name } {
          foreach pcore_lib $pcore_libs {
            set dir [file join $a_isl_vars(ipstatic_dir) $pcore_lib]
            isl_create_vao_file_pcore $dir $file_paths $pcore_lib
            isl_copy_incl_file $file_paths
          }
          # now create vao file for microblaze_mcs
          set ip_lib_dir [file join $a_isl_vars(ipstatic_dir) $mcs_lib_name]
          isl_create_vao_file_pcore $ip_lib_dir $file_paths $mcs_lib_name
          isl_copy_incl_file $file_paths
        } else {
          isl_create_vao_file $ip_lib_dir $file_paths
          isl_copy_incl_file $file_paths
        }
      }
    }
    ipx::unload_core $ip_comp
  }
  return $current_index
}

proc isl_extract_repo_sub_core_static_files { vlnv ip_libs_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_isl_vars
  upvar ip_libs_arg ip_libs

  set ip_def  [get_ipdefs -quiet -all -vlnv $vlnv]
  set ip_def_comps [split $ip_def {:}]
  set ip_def_name  [lindex $ip_def_comps 2]
  set ip_xml  [get_property xml_file_name $ip_def]
  set ip_dir  [file dirname $ip_xml]
  set ip_comp [ipx::open_core $ip_xml]
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
        isl_extract_repo_sub_core_static_files $sub_vlnv $ip_libs
      }
      set ip_lib_dir {}
      set file_paths [list]
      set pcore_libs [list]
      set mcs_lib_name {}
      foreach static_file [ipx::get_files -filter {USED_IN=~"*ipstatic*"} -of $file_group] {
        set file_entry [split $static_file { }]
        lassign $file_entry file_key comp_ref file_group_name file_path
        set ip_file [lindex $file_entry 3]
        set type [isl_get_file_type $file_group $ip_file]
        set library [get_property library_name [ipx::get_files $ip_file -of_objects $file_group]]
        if { {} == $library } {
          puts ""
          send_msg_id setup_ip_static_library-Tcl-022 WARNING "Associated library not defined for '$ip_file' ($ip_def_name,$vlnv)\n"
        }
        if { {xil_defaultlib} == $library } {
          puts ""
          send_msg_id setup_ip_static_library-Tcl-022 WARNING "Associated library incorrectly set to '$library' for '$ip_file' ($ip_def_name,$vlnv)\n"
          continue
        }
        set full_ip_file_path [file normalize [file join $ip_dir $ip_file]]
        if { [lsearch $ip_libs $library] == -1 } {
          lappend ip_libs $library
        }

        if { [regexp {microblaze_mcs_v} $library] } {
          set mcs_lib_name $library
        } else {
          if { [lsearch $pcore_libs $library] == -1 } {
            lappend pcore_libs $library
          }
        }
        # <ipstatic_dir>/<library>
        set ip_lib_dir [file join $a_isl_vars(ipstatic_dir) $library]
        if { ![file exists $ip_lib_dir] } {
          if {[catch {file mkdir $ip_lib_dir} error_msg] } {
            send_msg_id setup_ip_static_library-Tcl-022 ERROR "failed to create the directory ($ip_lib_dir)): $error_msg\n"
          }
        }
        set data "$library,$full_ip_file_path,$type,static"
        lappend file_paths "$full_ip_file_path,$type"
        isl_add_to_compile_order $library $data
      }
      # for microblaze_mcs, create vao file for each pcore library and then for microblaze_mcs
      if { {microblaze_mcs} == $ip_def_name } {
        foreach pcore_lib $pcore_libs {
          set dir [file join $a_isl_vars(ipstatic_dir) $pcore_lib]
          isl_create_vao_file_pcore $dir $file_paths $pcore_lib
          isl_copy_incl_file $file_paths
        }
        # now create vao file for microblaze_mcs
        set ip_lib_dir [file join $a_isl_vars(ipstatic_dir) $mcs_lib_name]
        isl_create_vao_file_pcore $ip_lib_dir $file_paths $mcs_lib_name
        isl_copy_incl_file $file_paths
      } else {
        isl_create_vao_file $ip_lib_dir $file_paths
        isl_copy_incl_file $file_paths
      }
    }
  }
}

proc isl_write_compile_order { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_isl_vars
  variable compile_order_data
  set fh 0
  if {[catch {open $a_isl_vars(co_file_list) w} fh]} {
    send_msg_id populate_sim_repo-Tcl-011 ERROR "failed to open file for append ($a_isl_vars(co_file_list))\n"
    return 1
  }
  foreach data $compile_order_data {
    set data [string trim $data]
    if { [string length $data] == 0 } { continue; }
    puts $fh $data
  }
  close $fh
  return
}

proc isl_find_ip_comp_xml_files { ip_repo_path } {
  # Summary:
  # Argument Usage:
  # Return Value:

  if { ({} == $ip_repo_path)               ||
       (![file isdirectory $ip_repo_path]) ||
       (![file readable $ip_repo_path]) } {
    return
  }

  set l_xml_file_paths [list]
  set file_to_search "component.xml"

  isl_find_files_recursive $ip_repo_path $file_to_search l_xml_file_paths

  return $l_xml_file_paths
}

proc isl_find_files_recursive { dir file_to_search l_file_paths_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $l_file_paths_arg l_file_paths
  if { [file isdirectory $dir] } {
    foreach file [glob -nocomplain -directory $dir *] {
      if { [file isdirectory $file] } {
        isl_find_files_recursive $file $file_to_search l_file_paths
      } else {
        if { $file_to_search == [file tail $file] } {
          lappend l_file_paths $file
        }
      }
    }
  } else {
    if { $file_to_search == [file tail $dir] } {
      lappend l_file_paths $dir
    }
  }
}

proc isl_extract_install_files { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable l_ip_repo_paths

  # for -install, append default Vivado install IP repository from data tree
  set data_dir [rdi::get_data_dir -quiet -datafile "ip/xilinx"]
  set ip_repo_dir [file normalize [file join $data_dir "ip/xilinx"]]

  lappend l_ip_repo_paths $ip_repo_dir

  isl_extract_repo_static_files
}

proc isl_add_to_compile_order { library l_ip_data } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_isl_vars
  variable compile_order_data
  foreach ip_data_info $l_ip_data {
    if { [lsearch $compile_order_data $ip_data_info] == -1 } {
      lappend compile_order_data $ip_data_info
    }
  }
}

proc isl_copy_file_path { file_to_copy src_ip_dir dst_ip_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set src $src_ip_dir
  set dst $dst_ip_dir
  set comps [lrange [split $file_to_copy "/"] 0 end]
  foreach comp $comps {
    append src "/";append src $comp
    append dst "/";append dst $comp
    if { [file isdirectory $src] } {
      if { ![file exists $dst] } {
        if {[catch {file mkdir $dst} error_msg] } {
          send_msg_id setup_ip_static_library-Tcl-025 ERROR "failed to create the directory ($dst): $error_msg\n"
          return 1
        }
      }
    } else {
      if { ![file exist $dst] } {
        set dst_dir [file dirname $dst]
        if {[catch {file copy -force $src $dst_dir} error_msg] } {
          send_msg_id setup_ip_static_library-Tcl-026 WARNING "Failed to copy file '$src' to '$dst_dir' : $error_msg\n"
        }
      }
    }
  }
}

proc isl_create_vao_file { ip_lib_dir file_paths } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set vhdl_filelist [list]
  set verilog_filelist [list]

  foreach line $file_paths {
    set tokens [split $line {,}]
    set path [lindex $tokens 0]
    set type [lindex $tokens 1]
    if { {vhdl} == $type } {
      lappend vhdl_filelist $path
    } elseif { ({verilog} == $type) || ({system_verilog} == $type) } {
      lappend verilog_filelist $path
    }
  }

  isl_write_analyze_order_file vhdl_filelist    $ip_lib_dir "vhdl_analyze_order"
  isl_write_analyze_order_file verilog_filelist $ip_lib_dir "verilog_analyze_order"
}

proc isl_create_order_file { ip_data ip_libs } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_isl_vars
  foreach library $ip_libs {
    set ip_lib_dir [file join $a_isl_vars(ipstatic_dir) $library]
    set file_paths [list]
    foreach data $ip_data {
      set values [split $data {,}]
      set lib_name  [lindex $values 0]
      set file_path [lindex $values 1]
      set file_type [lindex $values 2]

      if { $lib_name == $library } {
        lappend file_paths $file_path,$file_type 
      }
    } 
    isl_create_vao_file $ip_lib_dir $file_paths
  }
}

proc isl_create_vao_file_pcore { ip_lib_dir file_paths pcore_lib } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set vhdl_filelist [list]
  set verilog_filelist [list]

  foreach line $file_paths {
    set tokens [split $line {,}]
    set path [lindex $tokens 0]
    set type [lindex $tokens 1]
    if { {vhdl} == $type } {
      # for microblaze_mcs_v library, filter pcore specific files (handled in else block)
      if { ([regexp {^microblaze_mcs_v} $pcore_lib]) } {
        if { [regexp {^pcores} $line] } { continue }
        lappend vhdl_filelist $path
      } else {
        # bucket pcore specific files only from the file_paths list
        if { [regexp $pcore_lib $line] } {
          lappend vhdl_filelist $path
        }
      }
    }
  }

  foreach line $file_paths {
    set tokens [split $line {,}]
    set path [lindex $tokens 0]
    set type [lindex $tokens 1]
    if { ({verilog} == $type) || ({system_verilog} == $type) } {
      # for microblaze_mcs_v library, filter pcore specific files (handled in else block)
      if { ([regexp {^microblaze_mcs_v} $pcore_lib]) } {
        if { [regexp {^pcores} $line] } { continue }
        lappend verilog_filelist $path
      } else {
        # bucket pcore specific files only from the file_paths list
        if { [regexp $pcore_lib $line] } {
          lappend verilog_filelist $path
        }
      }
    }
  }

  isl_write_analyze_order_file vhdl_filelist    $ip_lib_dir "vhdl_analyze_order"
  isl_write_analyze_order_file verilog_filelist $ip_lib_dir "verilog_analyze_order"
}

proc isl_write_analyze_order_file { filelist_arg ip_lib_dir order_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $filelist_arg filelist

  if { [llength $filelist] <= 0 } { return }
  
  set fh 0
  set file [file join $ip_lib_dir $order_file]
  if { [file exists $file] } {
    # read current file paths
    if {[catch {open $file r} fh]} {
      send_msg_id setup_ip_static_library-Tcl-027 ERROR "failed to open file for read ($file)\n"
      return
    }
    set file_data [split [read $fh] "\n"]
    close $fh

    # append to existing file paths, if doest not exist
    set fh 0
    if {[catch {open $file a} fh]} {
      send_msg_id setup_ip_static_library-Tcl-027 ERROR "failed to open file for append ($file)\n"
      return
    }
    foreach file $filelist {
      if { [lsearch -exact $file_data $file] == -1 } {
        puts $fh $file
      }
    }
    close $fh
  } else {
    if {[catch {open $file w} fh]} {
      send_msg_id setup_ip_static_library-Tcl-027 ERROR "failed to open file for write ($file)\n"
      return
    }
    foreach file $filelist { puts $fh $file }
    close $fh
  }
}

proc isl_copy_incl_file { file_paths } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_isl_vars

  set filelist [list]
  foreach line $file_paths {
    set tokens [split $line {,}]
    set file_path [lindex $tokens 0]
    set filename [file tail $file_path]
    set type [lindex $tokens 1]
    if { ({verilog_header} == $type) || ({verilog header} == $type) } {
      set src_file_path [file normalize $file_path]
      if { [file exists $src_file_path] } {
        set dst_file [file normalize [file join $a_isl_vars(ip_incl_dir) $filename]]
        if { ![file exists $dst_file] } {
          if {[catch {file copy -force $src_file_path $a_isl_vars(ip_incl_dir)} error_msg] } {
            send_msg_id setup_ip_static_library-Tcl-026 WARNING "Failed to copy file '$src_file_path' to '$a_isl_vars(ip_incl_dir)' : $error_msg\n"
          }
        }
      }
    }
  }
}

proc isl_get_file_type { file_group file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set type "vhdl"
  set file_type [get_property type [ipx::get_files $file -of_objects $file_group]]
  if { ({verilogSource} == $file_type) || ({systemVerilogSource} == $file_type) } {
    set type "verilog"
    if { {systemVerilogSource} == $file_type } {
      set type "system_verilog"
    }
    set is_include [get_property is_include [ipx::get_files $file -of_objects $file_group]]
    if { {1} == $is_include } {
      set type "verilog_header"
    }
  }
  return $type
}

proc isl_copy_files_recursive { src dst } {
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
            send_msg_id setup_ip_static_library-Tcl-029 WARNING "Failed to create directory '$dst_dir' : $error_msg\n"
          }
        }
        isl_copy_files_recursive $file $dst_dir
      } else {
        set filename [file tail $file]
        set dst_file [file join $dst $filename]
        if { ![file exists $dst] } {
          if {[catch {file mkdir $dst} error_msg] } {
            send_msg_id setup_ip_static_library-Tcl-030 WARNING "Failed to create directory '$dst_dir' : $error_msg\n"
          }
        }
        if { ![file exist $dst_file] } {
          if { [isl_filter $file] } {
            # filter these files
          } else {
            if {[catch {file copy -force $file $dst} error_msg] } {
              send_msg_id setup_ip_static_library-Tcl-031 WARNING "Failed to copy file '$file' to '$dst' : $error_msg\n"
            } else {
              #send_msg_id export_ip_files-Tcl-009 STATUS " + Exported file (dynamic):'$dst'\n"
            }
          }
        }
      }
    }
  } else {
    set filename [file tail $src]
    set dst_file [file join $dst $filename]
    if { [isl_filter $src] } {
      # filter these files
    } else {
      if { ![file exist $dst_file] } {
        if {[catch {file copy -force $src $dst} error_msg] } {
          #send_msg_id setup_ip_static_library-Tcl-032 WARNING "Failed to copy file '$src' to '$dst' : $error_msg\n"
        } else {
          #send_msg_id setup_ip_static_library-Tcl-033 STATUS " + Exported file (dynamic):'$dst'\n"
        }
      }
    }
  }
}

proc isl_filter { file } {
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
}
