package require Vivado 1.2017.1

namespace eval ::tclapp::xilinx::x2rp {
    namespace export run
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

    set a_global_vars(verbose) 0
    set a_global_vars(log) ""
    set a_global_vars(log_enabled) 0

    set a_global_vars(top) [get_property TOP [current_fileset -srcset]]
    set a_global_vars(part) [get_property PART [current_project]]
    set a_global_vars(constr_files) [get_files -compile_order constraints -used_in implementation -of_objects [current_fileset -constrset]]
    set a_global_vars(ip_output_repo) [get_property IP_OUTPUT_REPO [current_project]]
    set a_global_vars(xpm_libs) [get_property XPM_LIBRARIES [current_project]]

    set a_global_vars(output_dir) ""

    set a_global_vars(pr_config) {}
    set a_global_vars(wrapper) ""
    set a_global_vars(initial_routed) ""
    set a_global_vars(base_platform) ""
    set a_global_vars(platform) "platform.dcp"
    set a_global_vars(post_link_design_hook) ""

    # internals    
    set a_global_vars(post_link_design) "postlinkdesign.dcp"
    set a_global_vars(post_opt_design) "postopt.dcp"
    set a_global_vars(post_place_design) "postplace.dcp"
    set a_global_vars(full_routed_design) "full_routed.dcp"
    set a_global_vars(post_route_phys_opt) "postrtphysopt.dcp"
    set a_global_vars(full_routed_bit) "full_routed.bit"

    set a_global_vars(reconfig_partitions) {}
    set a_global_vars(reconfig_modules) {}
    set a_global_vars(rm_configs) {}
    set a_global_vars(exclude_constrs) {}
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

    set xdc_norm {}
    foreach xdc $a_global_vars(exclude_constrs) {
        lappend xdc_norm [file normalize $xdc]
        if { ![file exists $xdc_norm] } {
            ::tclapp::xilinx::x2rp::log 004 ERROR "Invalid XDC file path, does not exist at location '[file normalize $xdc]'"
        }
    }
    set a_global_vars(exclude_constrs) $xdc_norm
}

proc ::tclapp::xilinx::x2rp::dump_program_options {} {
    # Summary: 
    # Dumps program options

    # Argument Usage: 

    # Return Value:
    # None

    variable a_global_vars
    set args {pr_config output_dir base_platform platform exclude_constrs log post_link_design_hook}
    ::tclapp::xilinx::x2rp::log 002 INFO "xilinx::x2rp::run is invoked with following options."        
    foreach key [lsort $args] {
        ::tclapp::xilinx::x2rp::log 003 INFO "\t$key = $a_global_vars($key)"
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

proc ::tclapp::xilinx::x2rp::run {args} {
    # Summary: Implements the 2RP Design

    # Argument Usage:
    # -pr_config <arg>: Partial configuration for the implementation run.
    # -output_dir <arg>: Directory to save the results.
    # [-base_platform_dcp <arg>]: Base platform dcp file, contains only static routed region.
    # [-rl_platform_dcp <arg>]: Reconfigurable logic platform dcp file.
    # [-exclude_constrs <arg>]: List of constraint file to be excluded from generation of bit files.
    # [-post_link_design_hook <arg>]: List of tcl commands to execute post link design for bit generation step.

    # Return Value:
    # Generates full and partial bit streams for a 2RP design.
    
    # Categories: xilinxtclstore, x2rp, 2RP, Multiple RL

    variable a_global_vars
    
    reset_global_vars
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
            "-initial_routed_dcp" {
                incr i;            
                if { [regexp {^-} [lindex $args $i]] } {
                    puts "[lindex $args $i]"
                    ::tclapp::xilinx::x2rp::log 001 ERROR "Missing value for the $option option.\nPlease provide a valid dcp immediately following '$option'"
                    return
                }
                set a_global_vars(initial_routed) [file normalize [lindex $args $i]]
                if { ![file exists $a_global_vars(initial_routed)] } {
                    ::tclapp::xilinx::x2rp::log 001 ERROR "Initial routed dcp file doesn't exist. Please provide a valid initial routed dcp file path."
                    return
                }
            }
            "-exclude_constrs" {
                incr i;            
                if { [regexp {^-} [lindex $args $i]] } {
                    puts "[lindex $args $i]"
                    ::tclapp::xilinx::x2rp::log 001 ERROR "Missing value for the $option option.\nPlease provide a list of constraint files to be excluded immediately following '$option'"
                    return
                }
                set a_global_vars(exclude_constrs) [lindex $args $i]
            }   
            "-post_link_design_hook" {
                incr i;            
                if { [regexp {^-} [lindex $args $i]] } {                
                    ::tclapp::xilinx::x2rp::log 001 ERROR "Missing value for the $option option.\nPlease provide a valid list of tcl commands immediately following '$option'"
                    return
                }         
                set a_global_vars(post_link_design_hook) [lindex $args $i]       
            }
        }
    }
    ::tclapp::xilinx::x2rp::log 004 INFO "Processing of command line arguments completed."    

    ::tclapp::xilinx::x2rp::log 005 INFO "Program Options:"
    dump_program_options    

    ::tclapp::xilinx::x2rp::log 006 INFO "Validating command line arguments."
    validate_args
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
    remove_wrapper_from_rps [determine_wrapper]
    
    # extract wrapper post synth dcp
    set a_global_vars(wrapper_post_synth) [extract_post_synth_dcp $a_global_vars(wrapper)]
    ::tclapp::xilinx::x2rp::log 015 INFO "Extracted wrapper post synth dcp : '$a_global_vars(wrapper_post_synth)'."

    if { ![file exists $a_global_vars(platform)] } {
        if { [string equal $a_global_vars(base_platform) ""] } {
            ::tclapp::xilinx::x2rp::log 016 INFO "Generate Base platform step started."
            create_base_platform
            ::tclapp::xilinx::x2rp::log 017 INFO "Generate Base platform step completed."
        }
        
        ::tclapp::xilinx::x2rp::log 018 INFO "Generate RL platform step started."        
        ::tclapp::xilinx::x2rp::log 019 INFO "Executing Cmd: 'generate_rl_platform -use_source $a_global_vars(wrapper_post_synth) -base_platform $a_global_vars(base_platform) -platform [file join $a_global_vars(output_dir) $a_global_vars(platform)] -reconfig_platform [list $a_global_vars(reconfig_partitions)]'"
        generate_rl_platform -use_source "$a_global_vars(wrapper_post_synth)" -base_platform "$a_global_vars(base_platform)" -platform [file join $a_global_vars(output_dir) $a_global_vars(platform)] -reconfig_platform "{[list $a_global_vars(reconfig_partitions)]}"
        set a_global_vars(platform) [file join $a_global_vars(output_dir) $a_global_vars(platform)]
        ::tclapp::xilinx::x2rp::log 020 INFO "Generate RL platform step completed. RL Platform = $a_global_vars(platform)"
        close_project
    }

    # At this stage we must have rl platform knowledge
    if { ![file exists $a_global_vars(platform)] } {
        ::tclapp::xilinx::x2rp::log 021 ERROR "RL platform dcp is not generated, could not proceed any further."
        return
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

    # output from generate step is added here
    ::tclapp::xilinx::x2rp::log 025 INFO "Executing Cmd: add_files $a_global_vars(platform)"
    add_files $a_global_vars(platform)

    ::tclapp::xilinx::x2rp::log 026 INFO "Adding RMs dcp and top source files."
    # add RMs post synthesis DCP files
    foreach rm_config $a_global_vars(rm_configs) {
        set instance_path [lindex [split $rm_config :] 0]
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
    foreach cf $a_global_vars(constr_files) {
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

    ::tclapp::xilinx::x2rp::log 035 INFO "Executing Cmd: set_property PLATFORM.IMPL 1 \[current_design\]"
    set_property PLATFORM.IMPL 1 [current_design]
    
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
    
    ::tclapp::xilinx::x2rp::log 041 INFO "Executing Cmd: opt_design -directive ExploreWithRemap"       
    opt_design -directive ExploreWithRemap
    
    ::tclapp::xilinx::x2rp::log 042 INFO "Executing Cmd: opt_design -merge_equivalent_drivers -sweep"       
    opt_design -merge_equivalent_drivers -sweep
    
    ::tclapp::xilinx::x2rp::log 043 INFO "Executing Cmd: write_checkpoint -force [file join $a_global_vars(output_dir) $a_global_vars(post_opt_design)]"       
    write_checkpoint -force [file join $a_global_vars(output_dir) $a_global_vars(post_opt_design)]

    ::tclapp::xilinx::x2rp::log 044 INFO "Opt design completed"        

    ##################################################
    ### Place design
    #################################################
    ::tclapp::xilinx::x2rp::log 045 INFO "Place design started"        

    ::tclapp::xilinx::x2rp::log 046 INFO "Executing Cmd: place_design -directive Explore -fanout_opt"       
    place_design -directive Explore -fanout_opt

    ::tclapp::xilinx::x2rp::log 047 INFO "Executing Cmd: write_checkpoint -force [file join $a_global_vars(output_dir) $a_global_vars(post_place_design)]"
    write_checkpoint -force [file join $a_global_vars(output_dir) $a_global_vars(post_place_design)]
    
    ::tclapp::xilinx::x2rp::log 048 INFO "Place design completed"        

    ##################################################
    ### Phys Opt design
    ##################################################
    ::tclapp::xilinx::x2rp::log 049 INFO "Physical opt design started"        

    ::tclapp::xilinx::x2rp::log 050 INFO "Executing Cmd: phys_opt_design -directive AggressiveExplore"     
    phys_opt_design -directive AggressiveExplore
    
    ::tclapp::xilinx::x2rp::log 051 INFO "Physical opt design completed"        

    ##################################################
    ### Route design
    ##################################################
    ::tclapp::xilinx::x2rp::log 052 INFO "Route design started"      

    ::tclapp::xilinx::x2rp::log 053 INFO "Executing Cmd: route_design -directive Explore -tns_cleanup"
    route_design -directive Explore -tns_cleanup

    ::tclapp::xilinx::x2rp::log 054 INFO "Executing Cmd: write_checkpoint -force  [file join $a_global_vars(output_dir) $a_global_vars(full_routed_design)]"
    write_checkpoint -force  [file join $a_global_vars(output_dir) $a_global_vars(full_routed_design)]

    ::tclapp::xilinx::x2rp::log 055 INFO "Route design completed"      

    ##################################################
    ### Post Route Phys Opt design (optional same as usual runs)
    ##################################################
    ::tclapp::xilinx::x2rp::log 056 INFO "Post route physical opt design started"      

    ::tclapp::xilinx::x2rp::log 057 INFO "Executing Cmd: phys_opt_design -directive AggressiveExplore"
    phys_opt_design -directive AggressiveExplore

    ::tclapp::xilinx::x2rp::log 058 INFO "Executing Cmd: write_checkpoint -force  [file join $a_global_vars(output_dir) $a_global_vars(post_route_phys_opt)]"
    write_checkpoint -force  [file join $a_global_vars(output_dir) $a_global_vars(post_route_phys_opt)]
    
    ::tclapp::xilinx::x2rp::log 059 INFO "Post route physical opt design completed"   

    ::tclapp::xilinx::x2rp::log 060 INFO "Write bitstream step started"

    ::tclapp::xilinx::x2rp::log 061 INFO "Executing Cmd: set_property PLATFORM.IMPL 2 \[current_design\]"
    set_property PLATFORM.IMPL 2 [current_design]

    ::tclapp::xilinx::x2rp::log 062 INFO "Executing Cmd: write_bitstream -force [file join $a_global_vars(output_dir) $a_global_vars(full_routed_bit)]"
    write_bitstream -force [file join $a_global_vars(output_dir) $a_global_vars(full_routed_bit)]

    ::tclapp::xilinx::x2rp::log 063 INFO "Write bitstream step completed"
    close_project
}

proc ::tclapp::xilinx::x2rp::create_base_platform {} {
    # Summary: 
    # Generates base platform.

    # Argument Usage: 

    # Return Value:
    # None

    variable a_global_vars

    # check if the initial routed dcp is given make use of that to create base platform and return
    if { [file exists $a_global_vars(initial_routed)] } {
        open_checkpoint $a_global_vars(initial_routed)

        set wrapper_cell [get_cells -hierarchical -filter {HD.RECONFIGURABLE == 1} -quiet]
        if { [string equal $wrapper_cell ""] } {
            ::tclapp::xilinx::x2rp::log 002 ERROR "Failed to determine wrapper cell. Wrapper cell should have the HD.RECONFIGURABLE property set to true."
        }

        ::tclapp::xilinx::x2rp::log 003 INFO "Found wrapper cell, with instance path '$wrapper_cell'."

        # Pre-requisites to create base platform
        # (1) for your base platform implementation, create a static PBLOCK and make sure the RP PBLOCK covers the rest of the device 
        # (2) set_property HD.PLATFORM_WRAPPER 1 on your base platform reconfigurable module (wrapper).

        set_property HD.PLATFORM_WRAPPER 1 $wrapper_cell
        update_design -black_box -cells $wrapper_cell
        write_checkpoint -force [file join $a_global_vars(output_dir) base_platform.dcp]
        set a_global_vars(base_platform) [file join $a_global_vars(output_dir) base_platform.dcp]
        close_project
        return
    }

    # initial routed dcp is not provided create it first and then the base platform
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

    set constr_files [get_files -compile_order constraints -used_in implementation -of_objects [current_fileset -constrset]]

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
    foreach cf $constr_files {
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

    ::tclapp::xilinx::x2rp::log 078 INFO "Executing Cmd: write_checkpoint -force [file join $a_global_vars(output_dir) base_platform.dcp]"    
    write_checkpoint -force [file join $a_global_vars(output_dir) base_platform.dcp]

    set a_global_vars(base_platform) [file join $a_global_vars(output_dir) base_platform.dcp]
    close_project
}