package require Vivado 1.2017.1

namespace eval ::tclapp::xilinx::x2rp {
    namespace export run
    namespace export open_checkpoint_for_dsa_generation
}

proc ::tclapp::xilinx::x2rp::log {idx type msg} {
    # Summary: 
    # Logs the msg in log file and vivado tcl interpreter

    # Argument Usage: 
    # idx: Log message id
    # type: Log message type
    # msg: Log message

    # Return Value:
    # None
  
    variable a_global_vars
    send_msg_id vivado-x2rp-$idx $type $msg

    if { $a_global_vars(log_enabled) } {
        set fp [open $a_global_vars(log) {WRONLY CREAT APPEND}]
        fconfigure $fp -encoding utf-8
        set ts [clock format [clock seconds] -format "%m%d%Y %H:%M:%S"]
        puts $fp "\[$ts\] \[$type\] \[vivado-x2rp-$idx\] $msg"
        close $fp
    }
}
proc ::tclapp::xilinx::x2rp::reset_global_vars {} {
    # Summary: 
    # Resets global variables
    
    # Argument Usage:

    # Return Value:
    # None

    variable a_global_vars
    variable dsa_props

    set a_global_vars(verbose) 0
    set a_global_vars(log) ""
    set a_global_vars(log_enabled) 0

    set a_global_vars(top) [get_property TOP [current_fileset -srcset]]
    set a_global_vars(part) [get_property PART [current_project]]
    set a_global_vars(constrset) ""
    set a_global_vars(constrs_files) {} 
    
    set a_global_vars(ip_output_repo) [get_property IP_OUTPUT_REPO [current_project]]
    set a_global_vars(xpm_libs) [get_property XPM_LIBRARIES [current_project]]

    set a_global_vars(output_dir) ""

    set a_global_vars(pr_config) {}
    set a_global_vars(wrapper) ""
    set a_global_vars(base_platform) ""
    set a_global_vars(base_reset_partial_bit) "base_reset_partial.bit"
    set a_global_vars(platform) "platform.dcp"
    set a_global_vars(post_link_design_hook) ""
    set a_global_vars(cl_sh_bb_routed_dcp) ""

    # internals    
    set a_global_vars(post_link_design) "postlinkdesign.dcp"
    set a_global_vars(post_opt_design) "postopt.dcp"
    set a_global_vars(post_place_design) "postplace.dcp"
    set a_global_vars(post_place_phys_opt) "postplphysopt.dcp" 
    set a_global_vars(post_route_phys_opt) "postrtphysopt.dcp"
    set a_global_vars(full_routed_design) "full_routed.dcp"
    set a_global_vars(full_routed_bit) "full_routed.bit"

    set a_global_vars(reconfig_partitions) {}
    set a_global_vars(reconfig_modules) {}
    set a_global_vars(rm_configs) {}
    set a_global_vars(exclude_constrs) {}

    set a_global_vars(shell) ""
    set a_global_vars(base_platform_provided) 0
    set a_global_vars(rl_platform_provided) 0
    set a_global_vars(cl_sh_bb_routed_dcp_provided) 0
    set a_global_vars(exclude_constrs_provided) 0
    set a_global_vars(generate_dsa) 0
    set a_global_vars(generate_base_only) 0

    # directives - defaults
    set a_global_vars(enable_post_place_phys_opt) 0
    set a_global_vars(opt_directive) "ExploreWithRemap"
    set a_global_vars(place_directive) "Explore -fanout_opt"
    set a_global_vars(post_place_phys_opt_directive) "AggressiveExplore"
    set a_global_vars(route_directive) "Explore -tns_cleanup"
    set a_global_vars(post_route_phys_opt_directive) "AggressiveExplore"

    gather_dsa_props_from_project [current_project]
}

proc ::tclapp::xilinx::x2rp::validate_args {} {
    # Summary: 
    # Validates arguments

    # Argument Usage: 

    # Return Value:
    # None

    variable a_global_vars

    if { [string equal $a_global_vars(part) ""] } {
        ::tclapp::xilinx::x2rp::log 004 ERROR "Project board part is invalid."
    }

    if { [string equal $a_global_vars(output_dir) ""] } {
        ::tclapp::xilinx::x2rp::log 004 ERROR "Output directory does not have a valid path. Please provide a valid path after '-output_dir' switch."
    }

    if { ![file exists $a_global_vars(output_dir)] } {
        ::tclapp::xilinx::x2rp::log 004 ERROR "Output directory '$a_global_vars(output_dir)' does not exists."
    } else {
        if { ![file isdirectory $a_global_vars(output_dir)] } {
            ::tclapp::xilinx::x2rp::log 004 ERROR "Output directory '$a_global_vars(output_dir)' is invalid. Make sure ouput directory is a valid writable directory path."
        }
    }

    if { !$a_global_vars(base_platform_provided) && !$a_global_vars(rl_platform_provided) && !$a_global_vars(exclude_constrs_provided) } {
        ::tclapp::xilinx::x2rp::log 004 ERROR "Missing option '-exclude_constrs'."
    }

    set xdc_norm {}
    foreach xdc $a_global_vars(exclude_constrs) {
        lappend xdc_norm [file normalize $xdc]
        if { ![file exists $xdc_norm] } {
            ::tclapp::xilinx::x2rp::log 004 ERROR "Invalid XDC file path, does not exist at location '[file normalize $xdc]'"
        }
    }
    set a_global_vars(exclude_constrs) $xdc_norm

    if { !$a_global_vars(cl_sh_bb_routed_dcp_provided) && !$a_global_vars(rl_platform_provided) && [string equal $a_global_vars(shell) ""] } {
        ::tclapp::xilinx::x2rp::log 004 ERROR "Missing value for option '-shell'. '-shell' must be provided when '-rl_platform_dcp' or '-cl_sh_bb_routed_dcp' option is not used."
    }

    if { [string equal $a_global_vars(constrset) ""] } {
        ::tclapp::xilinx::x2rp::log 004 ERROR "Missing value for option '-constrset'."
    }

    if { [llength $a_global_vars(constrs_files)] == 0 } {
        if { [string equal $a_global_vars(constrset) ""] } {
            ::tclapp::xilinx::x2rp::log 004 CRITICAL_WARNING "No constraint files found."
        } else {
            ::tclapp::xilinx::x2rp::log 004 CRITICAL_WARNING "No constraint files found for constraint set '$a_global_vars(constrset)'."
        }
    }
}

proc ::tclapp::xilinx::x2rp::dump_program_options {} {
    # Summary: 
    # Dumps program options

    # Argument Usage: 

    # Return Value:
    # None

    variable a_global_vars
    variable dsa_props

    set args {pr_config output_dir constrset constrs_files base_platform platform exclude_constrs log post_link_design_hook shell opt_directive place_directive enable_post_place_phys_opt post_place_phys_opt_directive route_directive post_route_phys_opt_directive cl_sh_bb_routed_dcp}
    ::tclapp::xilinx::x2rp::log 002 INFO "xilinx::x2rp::run is invoked with following options."        
    foreach key [lsort $args] {
        if { [info exists a_global_vars($key)] } {
            ::tclapp::xilinx::x2rp::log 003 INFO "\t$key = $a_global_vars($key)"
        }
    }
    
    if { [array exists dsa_props] } {
        ::tclapp::xilinx::x2rp::log 002 INFO "Project DSA properties:-"        
        foreach key [lsort [array names dsa_props]] {
            ::tclapp::xilinx::x2rp::log 003 INFO "\t$key = $dsa_props($key)"                
        }
    }
    
    if { $a_global_vars(verbose) } {
        ::tclapp::xilinx::x2rp::log 002 INFO "xilinx::x2rp::run all internal options."        
        foreach key [lsort [array names a_global_vars]] {
            ::tclapp::xilinx::x2rp::log 003 INFO "$key = $a_global_vars($key)"
        }        
    }
} 

proc ::tclapp::xilinx::x2rp::determine_wrapper {} {
    # Summary: 
    # Determines the wrapper cell in the design.

    # Argument Usage: 

    # Return Value:
    # wrapper instance path

    variable a_global_vars
    if { [llength $a_global_vars(reconfig_partitions)] == 0 } {
        ::tclapp::xilinx::x2rp::log 005 ERROR "Could not determine the wrapper partial configuration is invalid."
        return
    }


    foreach rp $a_global_vars(reconfig_partitions) {
        if { [llength [lsearch -all -regexp $a_global_vars(reconfig_partitions) $rp]] == [llength $a_global_vars(reconfig_partitions)] } {
            set a_global_vars(wrapper) $rp
            ::tclapp::xilinx::x2rp::log 005 INFO "Found '$rp' is a wrapper."
            return [lsearch -exact $a_global_vars(reconfig_partitions) $rp]
        }
    }

    ::tclapp::xilinx::x2rp::log 005 ERROR "Could not determine the wrapper partial configuration is invalid."    
}

proc ::tclapp::xilinx::x2rp::extract_post_synth_dcp {rm} {
    # Summary: 
    # Extracts RM post synth DCP

    # Argument Usage: 
    # rm: RM for which post synth DCP needs to be extracted

    # Return Value:
    # post synth dcp of an rm

    variable a_global_vars
    foreach rm_config $a_global_vars(rm_configs) {
        set instance_path [lindex [split $rm_config :] 0]
        if {[string equal $instance_path $rm]} {
            return [lindex [split $rm_config :] 2]
        }
    }
}

proc ::tclapp::xilinx::x2rp::remove_wrapper_from_rps {index} {
    # Summary: 
    # Removes wrapper from the reconfig partitions list

    # Argument Usage: 
    # index: index of the wrapper to be removed from reconfig partitions list

    # Return Value:
    # None

    variable a_global_vars
    set a_global_vars(reconfig_partitions) [lreplace $a_global_vars(reconfig_partitions) $index $index]
}

proc ::tclapp::xilinx::x2rp::gather_dsa_props_from_project {project} {
    variable dsa_props

    set props [list_property -regexp $project DSA.*]

    foreach prop $props {
        set dsa_props($prop) [get_property $prop $project]
    }
}

proc ::tclapp::xilinx::x2rp::apply_dsa_properties_to_project {project} {
    variable dsa_props
    foreach key [array names dsa_props] {
        set_property $key $dsa_props($key) $project
    }
}

proc ::tclapp::xilinx::x2rp::open_checkpoint_for_dsa_generation {args} {
    # Summary: Opens routed design checkpoint in the current project context for DSA generation.

    # Argument Usage:
    # -routed_dcp <arg>: Routed dcp for which DSA generation is required.
    # [-exclude_constrs <arg>]: List of constraint file to be excluded from generation of DSA.

    # Return Value:
    # Open routed design checkpoint in the current project context.
    
    # Categories: xilinxtclstore, x2rp, 2RP, Multiple RL

    set verbose 0    
    set exclude_constrs {}
    for {set i 0} {$i < [llength $args]} {incr i} {
        set option [string trim [lindex $args $i]]
        puts $option
        switch -regexp -- $option {
            "-verbose" {
                set verbose 1
            }
            "-routed_dcp" {
                incr i;            
                if { [regexp {^-} [lindex $args $i]] } {
                    send_msg_id vivado-x2rp-001 ERROR "Missing value for the $option option.\nPlease provide a valid dcp file immediately following '$option'"
                    return
                }
                set routed_dcp [file normalize [lindex $args $i]]
                if { ![file exists $routed_dcp] } {
                    send_msg_id vivado-x2rp-001 ERROR "Routed dcp file doesn't exist. Please provide a valid routed dcp file path."
                    return
                }
            }
            "-exclude_constrs" {
                incr i;            
                if { [regexp {^-} [lindex $args $i]] } {
                    puts "[lindex $args $i]"
                    send_msg_id vivado-x2rp-001 ERROR "Missing value for the $option option.\nPlease provide a list of constraint files to be excluded immediately following '$option'"
                    return
                }
                set exclude_constrs [lindex $args $i]
            } 
        }
    }

    send_msg_id vivado-x2rp-087 INFO "Opening routed dcp in current project context for DSA generation."
    
    set result 0
    set einfo ""
    set ecode "NONE"
    set resulttext ""
    
    # enable the param here which enables to open checkpoint in current project context
    set_param project.enableOpenCheckpointWithCurrentProject 1

    # disable excluded constraint files before opening the checkpoint 
    foreach cf $exclude_constrs {
        set_property IS_ENABLED 0 [get_files $cf]
    }

    set result [ catch { open_checkpoint $routed_dcp } resulttext]
    if {$result} {
        set ecode $::errorCode
        set einfo $::errorInfo
    }

    # disable the param here which enables to open checkpoint in current project context
    set_param project.enableOpenCheckpointWithCurrentProject 0

    # enable excluded constraint files before opening the checkpoint 
    foreach cf $exclude_constrs {
        set_property IS_ENABLED 1 [get_files $cf]
    }
    
    if { $result } {
        send_msg_id vivado-x2rp-088 INFO "Failed to open routed dcp in current project context for DSA generation."
        return -code $result -errorcode $ecode -errorinfo $einfo $resulttext
    } else {
        send_msg_id vivado-x2rp-089 INFO "Opened routed dcp in current project context for DSA generation successfully."
    }
}

proc ::tclapp::xilinx::x2rp::run {args} {
    # Summary: Implements the 2RP Design.

    # Argument Usage:
    # -pr_config <arg>: Partial configuration for the implementation run.
    # -output_dir <arg>: Directory to save the results.
    # -constrset <arg>: Constraints set to be use with the pr configuration provided in option '-pr_config'.
    # [-exclude_constrs <arg>]: List of constraint file to be excluded from generation of bit files.
    # [-shell <arg>]: RL/Shell instance path. Must be mentioned in case rl_platform_dcp option is not provided.
    # [-base_platform_dcp <arg>]: Base platform dcp file, contains only static routed region.
    # [-rl_platform_dcp <arg>]: Reconfigurable logic platform dcp file.
    # [-cl_sh_bb_routed_dcp <arg>]: CL and SH blackbox routed dcp. (for update CL, SH or both)
    # [-post_link_design_hook <arg>]: List of tcl commands to execute post link design for bit generation step.
    # [-opt_directive <arg> = ExploreWithRemap]: Directive for opt design step.
    # [-place_directive <arg> = Explore -fanout_opt]: Directive for place design step.
    # [-enable_post_place_phys_opt]: Enable post place physical optimization (Default: 0).
    # [-post_place_phys_opt_directive <arg> = AggressiveExplore]: Directive for post place phys opt design step.
    # [-route_directive <arg> = Explore -tns_cleanup]: Directive for route design step.
    # [-post_route_phys_opt_directive <arg> = AggressiveExplore]: Directive for post route phys opt design step.    
    # [-generate_dsa]: Opens routed design checkpoint in current project context for DSA generation. (Default: 0)
    # [-generate_base_only]: Only generates base platform dcp. (Default: 0)

    # Return Value:
    # Generates full and partial bit streams for a 2RP design.
    
    # Categories: xilinxtclstore, x2rp, 2RP, Multiple RL

    variable a_global_vars
    
    ::tclapp::xilinx::x2rp::reset_global_vars
    ::tclapp::xilinx::x2rp::log 002 INFO "Resetting of global arguments completed."
    # process_args $args    
    ::tclapp::xilinx::x2rp::log 003 INFO "Processing command line arguments."
    for {set i 0} {$i < [llength $args]} {incr i} {
        set option [string trim [lindex $args $i]]
        puts $option
        switch -regexp -- $option {
            "-verbose" {
                set a_global_vars(verbose) 1
            }
            "-generate_dsa" {
                set a_global_vars(generate_dsa) 1
            }   
            "-generate_base_only" {
                set a_global_vars(generate_base_only) 1
            }                    
            "-enable_post_place_phys_opt" {
                set a_global_vars(enable_post_place_phys_opt) 1
            } 
            "-base_platform_dcp" {
                incr i;            
                if { [regexp {^-} [lindex $args $i]] } {
                    ::tclapp::xilinx::x2rp::log 001 ERROR "Missing value for the $option option.\nPlease provide a valid dcp file immediately following '$option'"
                    return
                }
                set a_global_vars(base_platform) [file normalize [lindex $args $i]]
                if { ![file exists $a_global_vars(base_platform)] } {
                    ::tclapp::xilinx::x2rp::log 001 ERROR "Base platform dcp file doesn't exist. Please provide a valid base platform dcp file path."
                    return
                }
                set a_global_vars(base_platform_provided) 1
            }
            "-rl_platform_dcp" {
                incr i;            
                if { [regexp {^-} [lindex $args $i]] } {
                    ::tclapp::xilinx::x2rp::log 001 ERROR "Missing value for the $option option.\nPlease provide a valid dcp file immediately following '$option'"
                    return
                }
                set a_global_vars(platform) [file normalize [lindex $args $i]]
                if { ![file exists $a_global_vars(platform)] } {
                    ::tclapp::xilinx::x2rp::log 001 ERROR "Reconfigurable logic dcp file doesn't exist. Please provide a valid rl platform dcp file path."
                    return
                }
                set a_global_vars(rl_platform_provided) 1
            }
            "-cl_sh_bb_routed_dcp" {
                incr i;            
                if { [regexp {^-} [lindex $args $i]] } {
                    ::tclapp::xilinx::x2rp::log 001 ERROR "Missing value for the $option option.\nPlease provide a valid dcp file immediately following '$option'"
                    return
                }
                set a_global_vars(cl_sh_bb_routed_dcp) [file normalize [lindex $args $i]]
                if { ![file exists $a_global_vars(cl_sh_bb_routed_dcp)] } {
                    ::tclapp::xilinx::x2rp::log 001 ERROR "CL and SH black box routed dcp file doesn't exist. Please provide a valid CL and SH black box routed dcp file path."
                    return
                }
                set a_global_vars(cl_sh_bb_routed_dcp_provided) 1
            }
            "-pr_config" {
                incr i;            
                if { [regexp {^-} [lindex $args $i]] } {
                    puts "[lindex $args $i]"
                    ::tclapp::xilinx::x2rp::log 001 ERROR "Missing value for the $option option.\nPlease provide a valid pr configuration immediately following '$option'"
                    return
                }
                set a_global_vars(pr_config) [lindex $args $i]
            }
            "-output_dir" {
                incr i;            
                if { [regexp {^-} [lindex $args $i]] } {
                    puts "[lindex $args $i]"
                    ::tclapp::xilinx::x2rp::log 001 ERROR "Missing value for the $option option.\nPlease provide a valid directory path immediately following '$option'"
                    return
                }
                if { ![string equal [lindex $args $i] ""] } {
                    set a_global_vars(output_dir) [file normalize [lindex $args $i]]
                    if { ![file exists $a_global_vars(output_dir)] } {
                        file mkdir $a_global_vars(output_dir)
                    }
                }

                set a_global_vars(log) [file normalize [file join $a_global_vars(output_dir) "x2rp.log"]]
                if { [file exists $a_global_vars(log)] } {
                    set dn [file dirname $a_global_vars(log)]
                    set fp [open $a_global_vars(log) "r"]
                    gets $fp line
                    if { [llength [split $line :]] == 2 } {
                        set pid_ts [lindex [split $line :] 1]
                        file rename -force $a_global_vars(log) "[file rootname $a_global_vars(log)]_${pid_ts}[file extension $a_global_vars(log)]"
                    }
                }

                set fp [open $a_global_vars(log) {WRONLY CREAT APPEND}]
                fconfigure $fp -encoding utf-8
                set fn [pid]_[clock format [clock seconds] -format "%d-%m-%Y_%H-%M-%S"]
                puts $fp "File Name:$fn"
                close $fp

                set a_global_vars(log_enabled) 1  
            }  
            "-constrset" {
                incr i;            
                if { [regexp {^-} [lindex $args $i]] } {
                    puts "[lindex $args $i]"
                    ::tclapp::xilinx::x2rp::log 001 ERROR "Missing value for the $option option.\nPlease provide a valid constraint set immediately following '$option'"
                    return
                }
                set a_global_vars(constrset) [lindex $args $i]
                set a_global_vars(constrs_files) [get_files -compile_order constraints -used_in implementation -of_objects [get_filesets $a_global_vars(constrset)]]
            }
            "-exclude_constrs" {
                incr i;            
                if { [regexp {^-} [lindex $args $i]] } {
                    puts "[lindex $args $i]"
                    ::tclapp::xilinx::x2rp::log 001 ERROR "Missing value for the $option option.\nPlease provide a list of constraint files to be excluded immediately following '$option'"
                    return
                }
                set a_global_vars(exclude_constrs) [lindex $args $i]
                set a_global_vars(exclude_constrs_provided) 1
            }   
            "-post_link_design_hook" {
                incr i;            
                if { [regexp {^-} [lindex $args $i]] } {                
                    ::tclapp::xilinx::x2rp::log 001 ERROR "Missing value for the $option option.\nPlease provide a valid list of tcl commands immediately following '$option'"
                    return
                }         
                set a_global_vars(post_link_design_hook) [lindex $args $i]       
            }
            "-shell" {
                incr i;            
                if { [regexp {^-} [lindex $args $i]] } {                
                    ::tclapp::xilinx::x2rp::log 001 ERROR "Missing value for the $option option.\nPlease provide a valid shell instance path immediately following '$option'"
                    return
                }         
                set a_global_vars(shell) [lindex $args $i]       
            }
            "-opt_directive" {
                incr i;            
                if { [regexp {^-} [lindex $args $i]] } {                
                    ::tclapp::xilinx::x2rp::log 001 ERROR "Missing value for the $option option.\nPlease provide a valid directive immediately following '$option'"
                    return
                }         
                set a_global_vars(opt_directive) [lindex $args $i]    
            }
            "-place_directive" {
                incr i;            
                if { [regexp {^-} [lindex $args $i]] } {                
                    ::tclapp::xilinx::x2rp::log 001 ERROR "Missing value for the $option option.\nPlease provide a valid directive immediately following '$option'"
                    return
                }         
                set a_global_vars(place_directive) [lindex $args $i]                    
            }
            "-post_place_phys_opt_directive" {
                incr i;            
                if { [regexp {^-} [lindex $args $i]] } {                
                    ::tclapp::xilinx::x2rp::log 001 ERROR "Missing value for the $option option.\nPlease provide a valid directive immediately following '$option'"
                    return
                }         
                set a_global_vars(post_place_phys_opt_directive) [lindex $args $i]                
            }             
            "-route_directive" {
                incr i;            
                if { [regexp {^-} [lindex $args $i]] } {                
                    ::tclapp::xilinx::x2rp::log 001 ERROR "Missing value for the $option option.\nPlease provide a valid directive immediately following '$option'"
                    return
                }         
                set a_global_vars(route_directive) [lindex $args $i]                
            }
            "-post_route_phys_opt_directive" {
                incr i;            
                if { [regexp {^-} [lindex $args $i]] } {                
                    ::tclapp::xilinx::x2rp::log 001 ERROR "Missing value for the $option option.\nPlease provide a valid directive immediately following '$option'"
                    return
                }         
                set a_global_vars(post_route_phys_opt_directive) [lindex $args $i]                
            }                                    
        }
    }
    ::tclapp::xilinx::x2rp::log 004 INFO "Processing of command line arguments completed."    

    ::tclapp::xilinx::x2rp::log 005 INFO "Program Options:"
    ::tclapp::xilinx::x2rp::dump_program_options    

    ::tclapp::xilinx::x2rp::log 006 INFO "Validating command line arguments."
    ::tclapp::xilinx::x2rp::validate_args
    ::tclapp::xilinx::x2rp::log 007 INFO "Validation of command line arguments completed."

    # resetting the vars again
    set a_global_vars(reconfig_partitions) {}
    set a_global_vars(reconfig_modules) {}
    set a_global_vars(rm_configs) {}

    # identifying wrapper and other RMs
    ::tclapp::xilinx::x2rp::log 008 INFO "Identifying wrapper and other partition defs information."
    foreach config $a_global_vars(pr_config) {
        set instance_path [lindex [split $config :] 0]
        lappend a_global_vars(reconfig_partitions) $instance_path

        set rm [lindex [split $config :] 1]
        lappend a_global_vars(reconfig_modules) $rm

        ::tclapp::xilinx::x2rp::log 009 INFO "$instance_path has rm $rm"
        set rm_synth_run_filter "IS_SYNTHESIS == 1 && SRCSET == $rm"
        set rm_synth_run [get_runs -filter $rm_synth_run_filter]
        set rm_synth_run_dir [get_property DIRECTORY $rm_synth_run]
        set rmFS [get_filesets -of_objects [get_reconfig_modules $rm]]
        set pdefName [get_property PARTITION_DEF [get_reconfig_modules $rm]]
        set rm_top [get_property TOP $rmFS]
        set rm_top_file [get_property TOP_FILE $rmFS]
        set rm_synth_dcp_file [file normalize [file join $rm_synth_run_dir $rm_top.dcp]] 
        
        if { [string equal $rm_top_file ""] } {
            set rm_top_file [get_files $rm_top.bd]
        }

        lappend a_global_vars(rm_configs) $config:$rm_synth_dcp_file:$rm_top_file
        ::tclapp::xilinx::x2rp::log 010 INFO "Partition Def : $pdefName | RM = $rm"
        ::tclapp::xilinx::x2rp::log 011 INFO "\tDCP File : $rm_synth_dcp_file"
        ::tclapp::xilinx::x2rp::log 012 INFO "\tTop Source File : $rm_top_file"
    }
    ::tclapp::xilinx::x2rp::log 013 INFO "Identification of wrapper and other partition defs information."

    # determine and remove wrapper from the RPs
    ::tclapp::xilinx::x2rp::log 014 INFO "Determining wrapper and reconfig partitions."
    ::tclapp::xilinx::x2rp::remove_wrapper_from_rps [::tclapp::xilinx::x2rp::determine_wrapper]
    
    # extract wrapper post synth dcp
    set a_global_vars(wrapper_post_synth) [extract_post_synth_dcp $a_global_vars(wrapper)]
    ::tclapp::xilinx::x2rp::log 015 INFO "Extracted wrapper post synth dcp : '$a_global_vars(wrapper_post_synth)'."  

    # check to figure out if user wants to run normal flow or CL/SH update flow
    if { !$a_global_vars(cl_sh_bb_routed_dcp_provided) } {
        if { ![file exists $a_global_vars(platform)] } {
            if { [string equal $a_global_vars(base_platform) ""] } {
                ::tclapp::xilinx::x2rp::log 016 INFO "Generate Base platform step started."
                ::tclapp::xilinx::x2rp::create_base_platform
                ::tclapp::xilinx::x2rp::log 017 INFO "Generate Base platform step completed."
            }

            if { $a_global_vars(generate_base_only) } {
                return
            }
            
            ::tclapp::xilinx::x2rp::log 018 INFO "Generate RL platform step started."        
            ::tclapp::xilinx::x2rp::log 019 INFO "Executing Cmd: 'generate_rl_platform -use_source $a_global_vars(wrapper_post_synth) -base_platform $a_global_vars(base_platform) -platform [file join $a_global_vars(output_dir) $a_global_vars(platform)] -reconfig_platform {$a_global_vars(shell)}'"
            generate_rl_platform -use_source "$a_global_vars(wrapper_post_synth)" -base_platform "$a_global_vars(base_platform)" -platform [file join $a_global_vars(output_dir) $a_global_vars(platform)] -reconfig_platform "{$a_global_vars(shell)}"
            set a_global_vars(platform) [file join $a_global_vars(output_dir) $a_global_vars(platform)]
            ::tclapp::xilinx::x2rp::log 020 INFO "Generate RL platform step completed. RL Platform = $a_global_vars(platform)"
            close_project
        }

        # At this stage we must have rl platform knowledge
        if { ![file exists $a_global_vars(platform)] } {
            ::tclapp::xilinx::x2rp::log 021 ERROR "RL platform dcp is not generated, could not proceed any further."
            return
        }
    }

    ::tclapp::xilinx::x2rp::log 022 INFO "Link step started"
    ### Create in-memory project
    ::tclapp::xilinx::x2rp::log 023 INFO "Executing Cmd: create_project -part $a_global_vars(part) -in_memory"
    create_project -part $a_global_vars(part) -in_memory

    ::tclapp::xilinx::x2rp::log 024 INFO "Setting project properties"
    set_param project.singleFileAddWarning.threshold 0
    set_property design_mode GateLvl [current_fileset]
    set_property ip_output_repo $a_global_vars(ip_output_repo) [current_project]
    set_property ip_cache_permissions {read write} [current_project]
    set_property XPM_LIBRARIES $a_global_vars(xpm_libs) [current_project]

    # apply dsa properties
    ::tclapp::xilinx::x2rp::log 024 INFO "*** Applying dsa properties."
    apply_dsa_properties_to_project [current_project]

    #if it CL/SH update mode then add cl_sh_bb_routed_dcp other wise add dcp generated from generate_rl_platform step
    if { $a_global_vars(cl_sh_bb_routed_dcp_provided) } {
        ::tclapp::xilinx::x2rp::log 025 INFO "Executing Cmd: add_files $a_global_vars(cl_sh_bb_routed_dcp)"
        add_files $a_global_vars(cl_sh_bb_routed_dcp)
    } else {
        # output from generate step is added here
        ::tclapp::xilinx::x2rp::log 025 INFO "Executing Cmd: add_files $a_global_vars(platform)"
        add_files $a_global_vars(platform)
    }

    ::tclapp::xilinx::x2rp::log 026 INFO "Adding RMs dcp and top source files."
    # add RMs post synthesis DCP files
    foreach rm_config $a_global_vars(rm_configs) {
        set instance_path [lindex [split $rm_config :] 0]

        # add wrapper bd file
        if { [string equal $a_global_vars(wrapper) $instance_path] } {
            set rm_top_file [lindex [split $rm_config :] 3]
            
            if { [file exists $rm_top_file] } {
                set_param project.isImplRun true
                ::tclapp::xilinx::x2rp::log 027 INFO "Executing Cmd: add_files -quiet $rm_top_file"
                add_files -quiet $rm_top_file
                set_param project.isImplRun false
            } else {
                ::tclapp::xilinx::x2rp::log 028 ERROR "Failed to add top bd file for rm instance '$instance_path'."
            }
        }

        if { [lsearch -exact $a_global_vars(reconfig_partitions) $instance_path] != -1} {
            set rm_top_file [lindex [split $rm_config :] 3]

            # adding RM top source file
            if { [file exists $rm_top_file] } {
                set_param project.isImplRun true
                ::tclapp::xilinx::x2rp::log 027 INFO "Executing Cmd: add_files -quiet $rm_top_file"
                add_files -quiet $rm_top_file
                set_param project.isImplRun false
            } else {
                ::tclapp::xilinx::x2rp::log 028 ERROR "Failed to add top bd file for rm instance '$instance_path'."
            }

            # adding RM DCP file
            set dcp_file [lindex [split $rm_config :] 2]
            if { [file exists $dcp_file] } {
                ::tclapp::xilinx::x2rp::log 029 INFO "Executing Cmd: add_files $dcp_file"
                add_files $dcp_file
                ::tclapp::xilinx::x2rp::log 030 INFO "Executing Cmd: set_property SCOPED_TO_CELLS [list $instance_path] [get_files $dcp_file]"
                set_property SCOPED_TO_CELLS [list $instance_path] [get_files $dcp_file]
            } else {
                ::tclapp::xilinx::x2rp::log 031 ERROR "Failed to add post synthesis dcp file for rm instance '$instance_path'."
            }
        }
    }

    # add constraint files
    foreach cf $a_global_vars(constrs_files) {
        if { [lsearch -exact $a_global_vars(exclude_constrs) $cf] == -1 } {
            add_files $cf    
            ::tclapp::xilinx::x2rp::log 032 INFO "Adding constraint file $cf"
        } else {
            ::tclapp::xilinx::x2rp::log 033 INFO "Ignored constraint file $cf"
        }
    }

    # link the design
    ::tclapp::xilinx::x2rp::log 034 INFO "Executing Cmd: link_design -top $a_global_vars(top) -part $a_global_vars(part) -reconfig_partitions [list $a_global_vars(reconfig_partitions)]"
    link_design -top $a_global_vars(top) -part $a_global_vars(part) -reconfig_partitions $a_global_vars(reconfig_partitions)

    if { $a_global_vars(cl_sh_bb_routed_dcp_provided) } {
        ::tclapp::xilinx::x2rp::log 035 INFO "Executing Cmd: set_property PLATFORM.IMPL 2 \[current_design\]"
        set_property PLATFORM.IMPL 2 [current_design]    
    } else {
        ::tclapp::xilinx::x2rp::log 035 INFO "Executing Cmd: set_property PLATFORM.IMPL 1 \[current_design\]"
        set_property PLATFORM.IMPL 1 [current_design]
    }
    
    ::tclapp::xilinx::x2rp::log 036 INFO "Executing Cmd: write_checkpoint -force [file join $a_global_vars(output_dir) $a_global_vars(post_link_design)]"
    write_checkpoint -force [file join $a_global_vars(output_dir) $a_global_vars(post_link_design)]
    
    ::tclapp::xilinx::x2rp::log 037 INFO "Link step completed"

    ::tclapp::xilinx::x2rp::log 038 INFO "Implementation step started"        
    # There may be additional param or less params to be set here this is what is being used at this time
    # set_param hd.supportClockNetCrossDiffReconfigurablePartitions 1
    ::tclapp::xilinx::x2rp::log 039 INFO "Setting parameters for implementation"        
    set_param route.enableGlobalRouting false
    set_param route.ignTgtRelaxFactor true
    set_param route.dlyCostCoef 1.141
    set_param route.thresholdCongForDlyCoeff 8
    set_param logicopt.replicateStartupElement false
    set_param place.blockFlopsEscapeRatioThresholdUSPlus 0
    set_param hd.reducePartPinAssignmentOnAbuttedRPs false
    ::tclapp::xilinx::x2rp::log 039 INFO "a) Executing post link design hook tcl commands"
    foreach tc $a_global_vars(post_link_design_hook) {
        ::tclapp::xilinx::x2rp::log 039 INFO "a) *** Executing post link design hook tcl command : $tc"
        eval $tc
    }

    # TODO: fix this part where we need to identify CL cell and set param for it
    # set_param hd.skipPartitionPinReductionOnCell $a_global_vars(stc_cl) 

    ##################################################
    ### Opt design
    ##################################################
    ::tclapp::xilinx::x2rp::log 040 INFO "Opt design started" 
    
    ::tclapp::xilinx::x2rp::log 041 INFO "Executing Cmd: opt_design -directive $a_global_vars(opt_directive)"       
    set opt_design_cmd "opt_design -directive $a_global_vars(opt_directive)"
    eval $opt_design_cmd
    
    ::tclapp::xilinx::x2rp::log 042 INFO "Executing Cmd: opt_design -merge_equivalent_drivers -sweep"       
    opt_design -merge_equivalent_drivers -sweep
    
    ::tclapp::xilinx::x2rp::log 043 INFO "Executing Cmd: write_checkpoint -force [file join $a_global_vars(output_dir) $a_global_vars(post_opt_design)]"       
    write_checkpoint -force [file join $a_global_vars(output_dir) $a_global_vars(post_opt_design)]

    ::tclapp::xilinx::x2rp::log 044 INFO "Opt design completed"        

    ##################################################
    ### Place design
    #################################################
    ::tclapp::xilinx::x2rp::log 045 INFO "Place design started"        

    ::tclapp::xilinx::x2rp::log 046 INFO "Executing Cmd: place_design -directive $a_global_vars(place_directive)"       
    set place_design_cmd "place_design -directive $a_global_vars(place_directive)"
    eval $place_design_cmd

    ::tclapp::xilinx::x2rp::log 047 INFO "Executing Cmd: write_checkpoint -force [file join $a_global_vars(output_dir) $a_global_vars(post_place_design)]"
    write_checkpoint -force [file join $a_global_vars(output_dir) $a_global_vars(post_place_design)]
    
    ::tclapp::xilinx::x2rp::log 048 INFO "Place design completed"        

    ##################################################
    ### Phys Opt design
    ##################################################
    if { $a_global_vars(enable_post_place_phys_opt) } {
        ::tclapp::xilinx::x2rp::log 049 INFO "Physical opt design started"        

        ::tclapp::xilinx::x2rp::log 050 INFO "Executing Cmd: phys_opt_design -directive $a_global_vars(post_place_phys_opt_directive)"     
        set post_place_phys_opt_design_cmd "phys_opt_design -directive $a_global_vars(post_place_phys_opt_directive)"
        eval $post_place_phys_opt_design_cmd
        
        ::tclapp::xilinx::x2rp::log 051 INFO "Executing Cmd: write_checkpoint -force  [file join $a_global_vars(output_dir) $a_global_vars(post_place_phys_opt)]"
        write_checkpoint -force  [file join $a_global_vars(output_dir) $a_global_vars(post_place_phys_opt)]

        ::tclapp::xilinx::x2rp::log 051 INFO "Physical opt design completed"
    }

    ##################################################
    ### Route design
    ##################################################
    ::tclapp::xilinx::x2rp::log 052 INFO "Route design started"      

    ::tclapp::xilinx::x2rp::log 053 INFO "Executing Cmd: route_design -directive $a_global_vars(route_directive)"
    set route_design_cmd "route_design -directive $a_global_vars(route_directive)"
    eval $route_design_cmd

    ::tclapp::xilinx::x2rp::log 054 INFO "Executing Cmd: write_checkpoint -force  [file join $a_global_vars(output_dir) $a_global_vars(full_routed_design)]"
    write_checkpoint -force  [file join $a_global_vars(output_dir) $a_global_vars(full_routed_design)]

    ::tclapp::xilinx::x2rp::log 055 INFO "Route design completed"      

    ##################################################
    ### Post Route Phys Opt design (optional same as usual runs)
    ##################################################
    ::tclapp::xilinx::x2rp::log 056 INFO "Post route physical opt design started"      

    ::tclapp::xilinx::x2rp::log 057 INFO "Executing Cmd: phys_opt_design -directive $a_global_vars(post_route_phys_opt_directive)"
    set post_route_phys_opt_design_cmd "phys_opt_design -directive $a_global_vars(post_route_phys_opt_directive)"
    eval $post_route_phys_opt_design_cmd

    ::tclapp::xilinx::x2rp::log 058 INFO "Executing Cmd: write_checkpoint -force  [file join $a_global_vars(output_dir) $a_global_vars(post_route_phys_opt)]"
    write_checkpoint -force  [file join $a_global_vars(output_dir) $a_global_vars(post_route_phys_opt)]
    
    ::tclapp::xilinx::x2rp::log 059 INFO "Post route physical opt design completed"   

    ::tclapp::xilinx::x2rp::log 060 INFO "Write bitstream step started"

    ::tclapp::xilinx::x2rp::log 061 INFO "Executing Cmd: set_property PLATFORM.IMPL 2 \[current_design\]"
    set_property PLATFORM.IMPL 2 [current_design]

    ::tclapp::xilinx::x2rp::log 062 INFO "Write partial and full bitstream step started."
    catch { write_mem_info -force [file join $a_global_vars(output_dir) ${a_global_vars(top)}.mmi] }
    write_bitstream -force -no_partial_bitfile [file join $a_global_vars(output_dir) $a_global_vars(top).bit]
    foreach rm_config $a_global_vars(pr_config) {
        set instance_path [lindex [split $rm_config :] 0]
        set rm [lindex [split $rm_config :] 1]

        if { [lsearch -exact $a_global_vars(reconfig_partitions) $instance_path] != -1} {
            set partial_bit_name [string map {/ _} "${instance_path}_${rm}_partial"]
            write_bitstream -force -cell $instance_path [file join $a_global_vars(output_dir) ${partial_bit_name}.bit]
        }
    }

    catch { write_sysdef -hwdef [file join $a_global_vars(output_dir) $a_global_vars(top).hwdef] -bitfile [file join $a_global_vars(output_dir) $a_global_vars(top).bit] -meminfo [file join $a_global_vars(output_dir) $a_global_vars(top).mmi] -file [file join $a_global_vars(output_dir) $a_global_vars(top).sysdef] }
    catch  {write_debug_probes -no_partial_ltxfile -quiet -force [file join $a_global_vars(output_dir) $a_global_vars(top)] }
    catch {file copy -force [file join $a_global_vars(output_dir) $a_global_vars(top).ltx] [file join $a_global_vars(output_dir) debug_nets.ltx] }

    foreach rm_config $a_global_vars(pr_config) {
        set instance_path [lindex [split $rm_config :] 0]
        set rm [lindex [split $rm_config :] 1]

        if { [lsearch -exact $a_global_vars(reconfig_partitions) $instance_path] != -1} {
            set partial_bit_name [string map {/ _} "${instance_path}_${rm}_partial"]            
            catch {write_debug_probes -quiet -force -cell $instance_path -file [file join $a_global_vars(output_dir) ${partial_bit_name}.ltx ]}        
        }
    }
    ::tclapp::xilinx::x2rp::log 063 INFO "Write partial and full bitstream step completed"

    # if app is not ran in CL/SH update mode, only then generate the CL_SH_BB_routed.dcp
    if { !$a_global_vars(cl_sh_bb_routed_dcp_provided) } {
        ::tclapp::xilinx::x2rp::log 082 INFO "Write CL_SH_BB_routed.dcp step started."
        ::tclapp::xilinx::x2rp::generate_cl_sh_bb_routed_dcp
        ::tclapp::xilinx::x2rp::log 086 INFO "Write CL_SH_BB_routed.dcp step completed."
    }
    close_project

    # Opening the routed dcp for DSA generation
    if { $a_global_vars(generate_dsa) } {
        set routed_dcp [file join $a_global_vars(output_dir) $a_global_vars(full_routed_design)]

        if { [file exists $routed_dcp] } {
            ::tclapp::xilinx::x2rp::open_checkpoint_for_dsa_generation -routed_dcp $routed_dcp 
        }
    }
}

proc ::tclapp::xilinx::x2rp::generate_cl_sh_bb_routed_dcp {} {
    variable a_global_vars

    ::tclapp::xilinx::x2rp::log 083 INFO "Executing Cmd: update_design -black_box -cells [list $a_global_vars(reconfig_partitions)]"
    # this loop is required because currently update_design doesn't work with list of cells (CR-1001665). Remove loop once CR-1001665 gets fixed.
    foreach rp $a_global_vars(reconfig_partitions) {
        update_design -black_box -cells $rp
    }
    ::tclapp::xilinx::x2rp::log 084 INFO "Executing Cmd: lock_design -level routing"
    lock_design -level routing
    ::tclapp::xilinx::x2rp::log 085 INFO "Executing Cmd: write_checkpoint -force [file join $a_global_vars(output_dir) CL_SH_BB_routed.dcp]"
    write_checkpoint -force [file join $a_global_vars(output_dir) CL_SH_BB_routed.dcp]
}

proc ::tclapp::xilinx::x2rp::create_base_platform {} {
    # Summary: 
    # Generates base platform.

    # Argument Usage: 

    # Return Value:
    # None

    variable a_global_vars

    # getting required properties from current project
    set currentFS [current_fileset]
    set project_name [get_property NAME [current_project]]
    set project_dir [get_property DIRECTORY [current_project]]
    set wt_parent_dir [file normalize [file join $project_dir $project_name.cache wt]]
    set proj_xpr_file [file normalize [file join $project_dir $project_name.xpr]]
    set ip_output_repo [get_property IP_OUTPUT_REPO [current_project]]
    set xpm_libs [get_property XPM_LIBRARIES [current_project]]

    set currentSS [current_fileset -srcset]
    set top [get_property TOP [current_fileset -srcset]]
    set top_file [get_files -norecurse -of_objects [get_filesets $currentSS] -filter {FILE_TYPE == "Block Designs"}]
    set part [get_property PART [current_project]]
    set synth_1_run_filter "IS_SYNTHESIS == 1 && SRCSET == $currentSS"
    set synth_1_run [get_runs -filter $synth_1_run_filter]
    set synth_1_run_dir [get_property DIRECTORY $synth_1_run]

    set constrs_files [get_files -compile_order constraints -used_in implementation -of_objects [get_filesets $a_global_vars(constrset)]]

    if {![string equal [get_property PROGRESS $synth_1_run] 100%] } {
        ::tclapp::xilinx::x2rp::log 064 ERROR "Sythesis is not completed yet. Run command 'launch_runs [get_property NAME $synth_1_run]'"
    }

    # creating dummy config 
    # this pr_config will be an input to the script
    # set pr_config {design_1_i/p1_0:rm1 design_1_i/p1_0/p2_0:rm2} 
    set pr_config $a_global_vars(pr_config)
    set rps {}
    set rms {}
    set rm_configs {}
    foreach config $pr_config {
        set instance_path [lindex [split $config :] 0]
        lappend rps $instance_path

        set rm [lindex [split $config :] 1]
        lappend rms $rm
        ::tclapp::xilinx::x2rp::log 001 INFO "$instance_path has rm $rm"
        set rm_synth_run_filter "IS_SYNTHESIS == 1 && SRCSET == $rm"
        set rm_synth_run [get_runs -filter $rm_synth_run_filter]
        set rm_synth_run_dir [get_property DIRECTORY $rm_synth_run]
        set rmFS [get_filesets -of_objects [get_reconfig_modules $rm]]
        set rm_top [get_property TOP $rmFS]
        set rm_top_file [get_property TOP_FILE $rmFS]
        set rm_synth_dcp_file [file normalize [file join $rm_synth_run_dir $rm_top.dcp]] 
        
        if { [string equal $rm_top_file ""] } {
            set rm_top_file [get_files $rm_top.bd]
        }

        lappend rm_configs $config:$rm_synth_dcp_file:$rm_top_file
    }

    create_project -in_memory -part $part
    set_param project.enableOOCBDReference 1
    set_param project.enableReferenceBd 1
    set_param project.enable2RP 1
    set_param project.enablePRFlowIPI 1
    set_param project.keepTmpDir 1
    set_param bd.enableTeamBD 1
    set_param simulation.resolveDataDirEnvPathForXSim 1
    set_param project.singleFileAddWarning.threshold 0

    set_property design_mode GateLvl [current_fileset]
    set_property webtalk.parent_dir $wt_parent_dir [current_project]
    set_property ip_output_repo $ip_output_repo [current_project]
    set_property ip_cache_permissions {read write} [current_project]
    set_property XPM_LIBRARIES $xpm_libs [current_project]

    # add top bd file
    set_param project.isImplRun true
    add_files -quiet $top_file
    set_param project.isImplRun false

    # add top dcp file
    add_files -quiet [file normalize [file join $synth_1_run_dir $top.dcp]] 
    set_msg_config -source 4 -id {BD 41-1661} -limit 0

    foreach rm_config $rm_configs {
        set instance_path [lindex [split $rm_config :] 0]
        set rm [lindex [split $rm_config :] 1]
        set rm_synth_dcp_file [lindex [split $rm_config :] 2]
        set rm_top_file [lindex [split $rm_config :] 3]

        puts "$instance_path $rm $rm_synth_dcp_file $rm_top_file"

        # add rm top bd file
        set_param project.isImplRun true
        add_files -quiet $rm_top_file
        set_param project.isImplRun false

        # add rm dcp file
        add_files -quiet $rm_synth_dcp_file
        set_property SCOPED_TO_CELLS $instance_path [get_files $rm_synth_dcp_file]
        set_property netlist_only true [get_files $rm_synth_dcp_file]
    }

    # add constraint files
    foreach cf $constrs_files {
        add_files $cf    
    }

    #link design
    set_param project.isImplRun true

    ::tclapp::xilinx::x2rp::log 065 INFO "Executing Cmd: link_design -top $top -part $part -reconfig_partitions $a_global_vars(wrapper)"
    link_design -top $top -part $part -reconfig_partitions $a_global_vars(wrapper)
    
    ::tclapp::xilinx::x2rp::log 066 INFO "Executing Cmd: set_property PLATFORM.IMPL 1 \[current_design\]"
    set_property PLATFORM.IMPL 1 [current_design]
    set_param project.isImplRun false
    ::tclapp::xilinx::x2rp::log 067 INFO "Executing Cmd: write_hwdef -force -file [file join $a_global_vars(output_dir) $top.hwdef]"
    write_hwdef -force -file [file join $a_global_vars(output_dir) $top.hwdef]

    # opt design
    ::tclapp::xilinx::x2rp::log 068 INFO "Executing Cmd: opt_design"
    opt_design 

    ::tclapp::xilinx::x2rp::log 069 INFO "Executing Cmd: write_checkpoint -force [file join $a_global_vars(output_dir) ${top}_opt.dcp]"
    write_checkpoint -force [file join $a_global_vars(output_dir) ${top}_opt.dcp]

    # place design
    ::tclapp::xilinx::x2rp::log 070 INFO "Executing Cmd: place_design"
    place_design
    
    ::tclapp::xilinx::x2rp::log 071 INFO "Executing Cmd: write_checkpoint -force [file join $a_global_vars(output_dir) ${top}_placed.dcp]"
    write_checkpoint -force [file join $a_global_vars(output_dir) ${top}_placed.dcp]

    # route design
    ::tclapp::xilinx::x2rp::log 072 INFO "Executing Cmd: route_design"
    route_design 

    ::tclapp::xilinx::x2rp::log 073 INFO "Executing Cmd: write_checkpoint -force [file join $a_global_vars(output_dir) ${top}_routed.dcp]"
    write_checkpoint -force [file join $a_global_vars(output_dir) ${top}_routed.dcp]

    set wrapper_cell [get_cells -hierarchical -filter {HD.RECONFIGURABLE == 1} -quiet]

    if { [string equal $wrapper_cell ""] } {
        ::tclapp::xilinx::x2rp::log 074 ERROR "Failed to determine wrapper cell. Wrapper cell should have the HD.RECONFIGURABLE property set to true."
    }

    ::tclapp::xilinx::x2rp::log 075 INFO "Found wrapper cell, with instance path '$wrapper_cell'."

    # Pre-requisites to create base platform
    # (1) for your base platform implementation, create a static PBLOCK and make sure the RP PBLOCK covers the rest of the device 
    # (2) set_property HD.PLATFORM_WRAPPER 1 on your base platform reconfigurable module (wrapper).
    # check where to set this
    ::tclapp::xilinx::x2rp::log 076 INFO "Executing Cmd: set_property HD.PLATFORM_WRAPPER 1 $wrapper_cell"
    set_property HD.PLATFORM_WRAPPER 1 $wrapper_cell
    
    ::tclapp::xilinx::x2rp::log 077 INFO "Executing Cmd: update_design -black_box -cells $wrapper_cell"    
    update_design -black_box -cells $wrapper_cell

    ::tclapp::xilinx::x2rp::log 077 INFO "*** a) Executing Cmd: lock_design -level routing"
    lock_design -level routing

    ::tclapp::xilinx::x2rp::log 078 INFO "Executing Cmd: write_bitstream -cell $wrapper_cell [file join $a_global_vars(output_dir) $a_global_vars(base_reset_partial_bit)]"
    write_bitstream -force -cell $wrapper_cell [file join $a_global_vars(output_dir) $a_global_vars(base_reset_partial_bit)]

    ::tclapp::xilinx::x2rp::log 079 INFO "Executing Cmd: write_checkpoint -force [file join $a_global_vars(output_dir) base_platform.dcp]"    
    write_checkpoint -force [file join $a_global_vars(output_dir) base_platform.dcp]

    set a_global_vars(base_platform) [file join $a_global_vars(output_dir) base_platform.dcp]
    close_project
}