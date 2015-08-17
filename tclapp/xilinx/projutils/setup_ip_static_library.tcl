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

  variable a_vars
  set a_vars(ipstatic_dir)      [file normalize "ipstatic"]
  set a_vars(b_dir_specified)   0
  set a_vars(co_file_list)      ""
  variable compile_order_data   [list]
  variable l_static_files
  set l_static_files            [list]
  set_param tcl.statsThreshold  100
}

proc setup_ip_static_library {args} {
  # Summary:
  # Extract static IP files from catalog
  # Argument Usage:
  # [-directory <arg>]: Extract static files in this directory
  # [-force]: Overwrite files

  # Return Value:
  # None

  # Categories: simulation, xilinxtclstore

  variable a_vars
  variable l_static_files

  isl_init_vars
  set a_vars(options) [split $args " "]
  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-directory" { incr i;set a_vars(ipstatic_dir) [lindex $args $i];set a_vars(b_dir_specified) 1 }
      default {
        if { [regexp {^-} $option] } {
          send_msg_id setup_ip_static_library-Tcl-001 ERROR "Unknown option '$option', please type 'setup_ip_static_library -help' for usage info.\n"
        }
      }
    }
  }

  if { {} != [current_project -quiet] } {
    [catch {send_msg_id setup_ip_static_library-Tcl-002 ERROR \
     "Detected a project in opened state. Please close this project and re-run this command again.\n"} err]
    return
  }

  if { $a_vars(b_dir_specified) } {
    set a_vars(ipstatic_dir) [file normalize $a_vars(ipstatic_dir)]
  }
  set a_vars(co_file_list) [file join $a_vars(ipstatic_dir) "compile_order.txt"]
    
  if { [file exists $a_vars(ipstatic_dir)] } {
    foreach file_path [glob -nocomplain -directory $a_vars(ipstatic_dir) *] {
      if {[catch {file delete -force $file_path} error_msg] } {
        [catch {send_msg_id setup_ip_static_library-Tcl-002 ERROR "failed to delete file ($a_vars(file_path)): $error_msg\n"} err]
        return
      }
    }
  } else {
    if {[catch {file mkdir $a_vars(ipstatic_dir)} error_msg] } {
      send_msg_id setup_ip_static_library-Tcl-003 ERROR "failed to create the directory ($a_vars(ipstatic_dir)): $error_msg\n"
      return 1
    }
  }

  isl_extract_files

  return
}

proc isl_extract_files { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  variable l_static_files

  set l_static_files [list]

  create_project -in_memory -part xc7vx485tffg1157-1
  if { ![isl_verify_access] } {
    close_project
    return
  }
  send_msg_id setup_ip_static_library-Tcl-004 INFO "Updating IP catalog..."
  if { ! [update_ip_catalog -quiet] } {
    close_project
    return 1
  }

  send_msg_id setup_ip_static_library-Tcl-005 INFO "Finding IP definitions..."
  set ips [list]
  set ips [get_ipdefs -all -filter sim_precompile==1]
  if { [llength $ips] == 0 } {
    send_msg_id setup_ip_static_library-Tcl-006 ERROR "No IP components found from the catalog!\n"
    return 1
  }

  send_msg_id setup_ip_static_library-Tcl-007 INFO "Extracting static files from IP definitions...(this may take a while, please wait)..."
  set compile_order_data [list]
  set ip_libs [list]
  foreach ip $ips {
    set info_str   [split $ip {:}]
    set ip_name    [lindex $info_str 2]
    set ip_version [lindex $info_str 3]
    regsub -all {\.} $ip_version {_} ip_version
    set library "${ip_name}_v${ip_version}"
    lappend ip_libs $library
    # <ipstatic_dir>/<library>
    set ip_lib_dir [file join $a_vars(ipstatic_dir) $library]
    if { ![file exists $ip_lib_dir] } {
      if {[catch {file mkdir $ip_lib_dir} error_msg] } {
        send_msg_id setup_ip_static_library-Tcl-008 ERROR "failed to create the directory ($ip_lib_dir)): $error_msg\n"
      }
    }

    set l_file_paths [list]
    set l_ip_data    [list]

    set ip_def  [get_ipdefs -all -vlnv $ip]
    set ip_xml  [get_property xml_file_name $ip_def]
    set ip_dir  [file dirname $ip_xml]
    set ip_comp [ipx::open_core $ip_xml]

    foreach file_group [ipx::get_file_groups -of $ip_comp] {
      set type [get_property type $file_group]
      if { ([string last "simulation" $type] != -1) && ($type != "examples_simulation") } {
        set sub_lib_cores [get_property component_subcores $file_group]
        set ordered_sub_cores [list]
        foreach sub_lib $sub_lib_cores {
          set ordered_sub_cores [linsert $ordered_sub_cores 0 $sub_lib]
        } 

        foreach sub_lib $ordered_sub_cores {
          isl_extract_sub_cores $sub_lib l_ip_data
        }

        foreach static_file [ipx::get_files -filter {USED_IN=~"*ipstatic*"} -of $file_group] {
          set file_entry [split $static_file { }]
          lassign $file_entry file_key comp_ref file_group_name file_path
          lappend l_file_paths $file_path

          set type [isl_get_file_type $file_path]
          set data "$library,$file_path,$type"
          lappend l_ip_data $data
          isl_copy_static_source $ip_dir $library $file_path 
        }
      }
    }

    isl_add_to_compile_order $library $l_ip_data
    isl_create_vao_file $ip_lib_dir $l_file_paths
    isl_create_incl_file $ip_lib_dir $l_file_paths
    ipx::unload_core $ip_comp
  }
  isl_write_compile_order
  isl_post_processing ip_libs
  close_project
  send_msg_id setup_ip_static_library-Tcl-009 INFO "Files extracted in '$a_vars(ipstatic_dir)'"
  return 0
}

proc isl_extract_sub_cores { ip l_ip_data_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  upvar $l_ip_data_arg l_ip_data

  set info_str   [split $ip {:}]
  set ip_name    [lindex $info_str 2]
  set ip_version [lindex $info_str 3]

  regsub -all {\.} $ip_version {_} ip_version

  set library "${ip_name}_v$ip_version"
  set ip_lib_dir [file join $a_vars(ipstatic_dir) $library]
  if { ![file exists $ip_lib_dir] } {
    if {[catch {file mkdir $ip_lib_dir} error_msg] } {
      send_msg_id setup_ip_static_library-Tcl-010 ERROR "failed to create the directory ($ip_lib_dir)): $error_msg\n"
    }
  }

  set ip_def  [get_ipdefs -all -vlnv $ip]
  set ip_xml  [get_property xml_file_name $ip_def]
  set ip_dir  [file dirname $ip_xml]
  set ip_comp [ipx::open_core $ip_xml]
  foreach file_group [ipx::get_file_groups -of $ip_comp] {
    set type [get_property type $file_group]
    if { ([string last "simulation" $type] != -1) && ($type != "examples_simulation") } {
      set sub_lib_cores [get_property component_subcores $file_group]
      set ordered_sub_cores [list]
      foreach sub_lib $sub_lib_cores {
        set ordered_sub_cores [linsert $ordered_sub_cores 0 $sub_lib]
      } 
      foreach sub_lib $ordered_sub_cores {
        isl_extract_sub_cores $sub_lib l_ip_data
      }
      foreach static_file [ipx::get_files -filter {USED_IN=~"*ipstatic*"} -of $file_group] {
        set file_entry [split $static_file { }]
        lassign $file_entry file_key comp_ref file_group_name file_path
        set type [isl_get_file_type $file_path]
        set data "$library,$file_path,$type"
        lappend l_ip_data $data
        isl_copy_static_source $ip_dir $library $file_path 
      }
    }
  }
}

proc isl_add_to_compile_order { library l_ip_data } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  variable compile_order_data
  foreach ip_data_info $l_ip_data {
    if { [lsearch $compile_order_data $ip_data_info] == -1 } {
      lappend compile_order_data $ip_data_info
    }
  }
}

proc isl_write_compile_order { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  variable compile_order_data
  set fh 0
  if {[catch {open $a_vars(co_file_list) w} fh]} {
    send_msg_id populate_sim_repo-Tcl-011 ERROR "failed to open file for append ($a_vars(co_file_list))\n"
    return 1
  }

  puts $fh "lib_pkg_v1_0,hdl/src/vhdl/lib_pkg.vhd,vhdl"

  foreach data $compile_order_data {
    set data [string trim $data]
    if { [string length $data] == 0 } { continue; }

    set comps [split $data {,}]
    set library [lindex $comps 0]
    if { {lib_pkg_v1_0} == $library } { continue; }

    puts $fh $data
  }
  close $fh
}

proc isl_post_processing { ip_libs_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  upvar $ip_libs_arg ip_libs
  set ips [list "axi_register_slice_v1_1"    \
                "axi_register_slice_v2_1"    \
                "axis_data_fifo_v1_1"        \
                "axis_dwidth_converter_v1_1" \
                "axis_combiner_v1_1"         \
                "axis_switch_v1_1"           \
                "axis_clock_converter_v1_1"  \
          ]

  foreach lib $ip_libs {
    if { [lsearch $ips $lib] != -1 } {
      set file_paths [list]
      set src_lib "axis_infrastructure_v1_1"
      set vh_file "hdl/verilog/axis_infrastructure_v1_1_0_axis_infrastructure.vh"

      if { {axi_register_slice_v2_1} == $lib } {
        set src_lib "axi_infrastructure_v1_1"
        set vh_file "hdl/verilog/axi_infrastructure_v1_1_0_header.vh"
      }

      lappend file_paths $vh_file

      set src_ip_dir [file join $a_vars(ipstatic_dir) $src_lib]
      set dst_ip_dir [file join $a_vars(ipstatic_dir) "$lib"]

      isl_copy_file_path $vh_file $src_ip_dir $dst_ip_dir
      isl_create_incl_file $dst_ip_dir $file_paths
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
          send_msg_id setup_ip_static_library-Tcl-012 ERROR "failed to create the directory ($dst): $error_msg\n"
          return 1
        }
      }
    } else {
      if { ![file exist $dst] } {
        set dst_dir [file dirname $dst]
        if {[catch {file copy -force $src $dst_dir} error_msg] } {
          send_msg_id setup_ip_static_library-Tcl-013 WARNING "Failed to copy file '$src' to '$dst_dir' : $error_msg\n"
        }
      }
    }
  }
}

proc isl_create_vao_file { ip_lib_dir file_paths } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set filelist [list]
  foreach path $file_paths {
    set type [isl_get_file_type $path]
    if { {vhdl} == $type } {
      lappend filelist $path
    }
  }

  if { [llength $filelist] > 0 } {
    set fh 0
    set file [file join $ip_lib_dir "vhdl_analyze_order"]
    if {[catch {open $file w} fh]} {
      send_msg_id setup_ip_static_library-Tcl-014 ERROR "failed to open file for write ($file)\n"
      return
    }
    foreach file $filelist {
      puts $fh $file
    }
    close $fh
  }
}

proc isl_create_incl_file { ip_lib_dir file_paths } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set filelist [list]
  foreach path $file_paths {
    set type [isl_get_file_type $path]
    if { {verilog_header} == $type } {
      lappend filelist $path
    }
  }

  if { [llength $filelist] > 0 } {
    set fh 0
    set file [file join $ip_lib_dir "include.h"]
    if {[catch {open $file w} fh]} {
      send_msg_id setup_ip_static_library-Tcl-015 ERROR "failed to open file for write ($file)\n"
      return
    }
    foreach file $filelist {
      puts $fh $file
    }
    close $fh
  }
}

proc isl_copy_static_source { src_ip_dir library file_path } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vars
  set hdl_dir_file [string map {\\ /} $file_path]
  set target_ip_lib_dir [file join $a_vars(ipstatic_dir) $library]
  set dst_file [file join $target_ip_lib_dir $hdl_dir_file]

  isl_copy_file_path $hdl_dir_file $src_ip_dir $target_ip_lib_dir
}

proc isl_get_file_type { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set type "vhdl"
  set extn [file extension [file tail $file]]
  if { {.v} == $extn  } { set type "verilog" }
  if { {.vh} == $extn } { set type "verilog_header" }
  return $type
}

proc isl_verify_access {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  if { [get_property sim.ipstatic.use_precompiled_libs [current_project]] } {
    return 1
  }
  return 0
}
}
