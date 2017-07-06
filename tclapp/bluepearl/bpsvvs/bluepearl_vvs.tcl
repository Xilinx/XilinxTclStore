###############################################################################
#
# bluepearl_vvs.tcl (Routine for Bluepearl Visual Verification Suite App.)
#
# Script created on 6/2017 by Satrajit Pal (Blue Pearl Software, Inc) 
#                                 Scott Aron Bloom
#
# 2017.1 - v1.1 (rev 1.1)
#  * Updated Initial Version
#
###############################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::bluepearl::bpsvvs {
    # Export procs that should be allowed to import into other namespaces
    namespace export generate_bps_project
    namespace export launch_bps
    namespace export update_vivado_into_bps
}

proc ::tclapp::bluepearl::bpsvvs::relto {reltodir file} {
    set dirList [file split [file normalize $reltodir]]
    set fileList [file split [file normalize $file]]
    global tcl_platform
    set os $tcl_platform(os)
    if {[string match -nocase *windows* $os]} {
        if {![string equal -nocase [lindex $fileList 0] [lindex $dirList 0]]} {
            return $file
        }
    } else {
        if {![string equal [lindex $fileList 0] [lindex $dirList 0]]} {
            return $file
        }
    }

    while {[string equal [lindex $fileList 0] [lindex $dirList 0]] && [llength $dirList]>0 && [llength $fileList]>0} {
        set fileList [lreplace $fileList 0 0]
        set dirList [lreplace $dirList 0 0]
    }

    set prefix ""
    if {[llength $fileList] == 0} {
        set prefix [list .]
    }
    for {set ii 0} {$ii < [llength $dirList]} {incr ii} {
        lappend prefix ..
    }
    return [eval file join $prefix $fileList]
}

proc ::tclapp::bluepearl::bpsvvs::isProtected { fileName } {
    if { [string match *blk_mem_gen* $fileName] } {
        return 1
    } elseif { [string match *fifo_generator* $fileName] } {
        return 1
    } elseif { [string match *mult_gen* $fileName] } {
        return 1
    } elseif { [string match *xbip_addsub* $fileName] } {
        return 1
    } elseif { [string match *dist_mem_gen* $fileName] } {
        return 1
    } elseif { [string match *c_addsub* $fileName] } {
        return 1
    } elseif { [string match *c_reg_fd* $fileName] } {
        return 1
    } elseif { [string match *axi_utils_v2_0* $fileName] } {
        return 1
    } elseif { [string match *c_mux_bit* $fileName] } {
        return 1
    } elseif { [string match *cmpy_* $fileName] } {
        return 1
    } elseif { [string match *floating_point_* $fileName] } {
        return 1
    } elseif { [string match *xbip_counter_* $fileName] } {
        return 1
    } elseif { [string match *c_gate_bit_* $fileName] } {
        return 1
    } elseif { [string match *xff2_* $fileName] } {
        return 1
    } else {
        return 0
    }
}

proc ::tclapp::bluepearl::bpsvvs::findIncludeDirs { files } {
    upvar includeDirs lclIncludeDirs

    foreach file $files {
        set fileObject [lindex [get_files -all [list $file]] 0]
        set fileName [get_property NAME $fileObject]
        set fileType [get_property FILE_TYPE $fileObject]
        set isHeader [get_property IS_GLOBAL_INCLUDE $fileObject]

        if {$isHeader || [string match $fileType "Verilog Header"]} {
            set dir [file dirname $fileName]
            set pos [lsearch $lclIncludeDirs $dir]
            if {$pos != -1} {
                continue
            }
            lappend lclIncludeDirs $dir
        }
    }
}

proc ::tclapp::bluepearl::bpsvvs::addFilesToProject { fileGroupName files project } {
    puts $project "# $fileGroupName"
    set projectDir [get_property DIRECTORY [current_project]]
    set filesMissing 0
    set fileCount 0
    foreach file $files {
        set fileObject [lindex [get_files -all [list $file]] 0]
        set fileName [get_property NAME $fileObject]
        set fileType [get_property FILE_TYPE $fileObject]
        set isHeader [get_property IS_GLOBAL_INCLUDE $fileObject]
        if {[string match $fileType "Verilog"] || [string match $fileType "SystemVerilog"] || [string match $fileType "VHDL"]} {
            if {$isHeader} {
                continue
            }

            upvar allFiles lclAllFiles
            set pos [lsearch $lclAllFiles $fileName]
            if {$pos != -1} {
                continue
            }
            lappend lclAllFiles $fileName
            
            set lib [get_property LIBRARY $fileObject]
            if {[string match $lib "xil_defaultlib"]} {
                set lib "work"
            }

            set libOption "-work $lib "
            if {[string match $lib "work"]} {
                set libOption {}
            } 

            if {![file exists $fileName]} {
                puts "WARNING: File '$fileName' does not exist, but is required for proper synthesis.";
                puts $project "#The following file does not exist, but is required for proper synthesis.";
                puts -nonewline $project "#"
                set filesMissing 1
            } elseif { [isProtected $fileName] } {
                puts "INFO: File '$fileName' is protected.";
                puts -nonewline $project "#"
                set filesMissing 1
            }
            set relToFile [relto $projectDir $fileName]
            puts $project "BPS::add_input_files $libOption\[list \[file join \$BPS::project_rel_to_dir $relToFile\]\]"
            incr fileCount 
        }
    }
    if {$fileCount == 0} {
        puts $project "# No files are required"
    }
    puts $project "\n"
    return $filesMissing
}

proc ::tclapp::bluepearl::bpsvvs::getTopModule {} {
    if { [catch {find_top}] } {
        puts stderr "ERROR: Current project is not set"
        return ""
    }
    set topModule [get_property top [current_fileset]]
    return $topModule
}

proc ::tclapp::bluepearl::bpsvvs::getProjectFile {} {
    if { [catch {find_top}] } {
        puts stderr "ERROR: Current project is not set"
        return ""
    }
    set projectDir [get_property DIRECTORY [current_project]]
    set topModule [getTopModule]
    set bpsProjectFile [file join $projectDir ${topModule}.bluepearl_generated.tcl]
    return $bpsProjectFile
}

proc ::tclapp::bluepearl::bpsvvs::generate_bps_project {} {
    if { ![check_bps_env] } {
        return 0
    }

    # Summary : This proc generates the Blue Pearl tcl project file
    # Argument Usage:
    # Return Value: Returns '1' on successful completion
    # Categories: xilinxtclstore, blue pearl, visual verification suite

    puts "INFO: Calling ::tclapp::bluepearl::bpsvvs::generate_bps_project"

    ## Vivado install dir
    set vivado_dir $::env(XILINX_VIVADO)
    puts "INFO: Using Vivado installation directory $vivado_dir"

    if { [catch {find_top}] } {
        puts stderr "ERROR: Current project is not set"
        return 1
    }

    set bpsProjectFile [getProjectFile]
    if {[file exists $bpsProjectFile]} {
        puts "INFO: Backing up {$bpsProjectFile}"
        file copy -force $bpsProjectFile [file join ${bpsProjectFile}.bak]
    }

    puts "INFO: Generating Blue Pearl tcl project file {$bpsProjectFile}"

    ## Open output file to write
    if { [catch {open $bpsProjectFile w} result] } {
        puts stderr "ERROR: Could not open {$bpsProjectFile} for writing"
        puts stderr "$result"
        return 1
    } else {
        set ofs $result
        puts "INFO: Writing Blue Pearl tcl project file to file {$bpsProjectFile}"
    }

    puts $ofs "#Blue Pearl Visual Verification Suite Project File Generated by Vivado Generator version 1.0"
    puts $ofs "\n"
    puts $ofs "set BPS::project_results_dir Results"
    puts $ofs "\n"
    puts $ofs "BPS::set_msg_check_package Xilinx"
    puts $ofs "BPS::set_xilinx_library 2016.4"
    puts $ofs "\n"
    puts $ofs "BPS::set_check_enabled -enabled false *"
    puts $ofs "BPS::set_package_enabled {UltraFast Design Methodology for Vivado}"
    puts $ofs "\n"
    set topModule [getTopModule]
    puts $ofs "set root_module $topModule" 
    puts $ofs "\n"

    set projectDir [get_property DIRECTORY [current_project]]
    puts $ofs "set BPS::project_rel_to_dir \[list $projectDir\]"
    puts $ofs "\n"

	set fileSet [current_fileset -srcset]
    set includeDirs [get_property include_dirs $fileSet]
    set ips [get_ips -quiet *]

    foreach ip $ips {
        set files [get_files -quiet -compile_order sources -used_in synthesis -of_objects $ip]
        findIncludeDirs $files
    }
    set files [get_files -norecurse -compile_order sources -used_in synthesis]
    findIncludeDirs $files 

	if { $includeDirs != "" } {
        puts $ofs "set veri_include_dirs \[list"
        foreach incdir $includeDirs {
            set curr [relto $projectDir $incdir]
            puts $ofs "    \[file join \$BPS::project_rel_to_dir $curr\]"
        }
        puts $ofs "\]\n" 
	}
	
    puts "INFO: Generating project for IP"
    puts "INFO: Found [llength $ips] IPs in the design"

    set missingFiles 0
    set allFiles [list]

    foreach ip $ips {
        set ipDef [get_property IPDEF $ip]
        set ipName [get_property NAME $ip]

        set files [get_files -quiet -compile_order sources -used_in synthesis -of_objects $ip]
        set fileMissing [addFilesToProject "IP $ipName" $files $ofs]
        if { $fileMissing || $missingFiles } {
            set missingFiles 1
        }
    }

    puts "INFO: Finished generating project for IP"
    puts "INFO: Generating project for User Files"
    set files [get_files -norecurse -compile_order sources -used_in synthesis]
    addFilesToProject "User Files" $files $ofs 
    puts "INFO: Finished generating project for User Files"

    if { $missingFiles } {
        puts $ofs "set auto_create_black_boxes true"
    }

    close $ofs

    puts "INFO: Successfully wrote $bpsProjectFile"

    return 0
}


proc ::tclapp::bluepearl::bpsvvs::launch_bps {} {
    if { ![check_bps_env] } {
        return 0
    }

    set bpsProjectFile [getProjectFile]
    if { $bpsProjectFile == {} } {
        puts stderr "ERROR: Current project is not set"
        return 0
    }

    puts "INFO: Generating Blue Pearl tcl project file {$bpsProjectFile}"
    set aOK [generate_bps_project]
    if { $aOK != 0 } {
        puts stderr "ERROR: Problem generating project file $bpsProjectFile"
        return 0
    }

    puts "INFO: Launching BluePearlVVE '$bpsProjectFile'"
    set vvs [auto_execok BluePearlVVE]
    puts "INFO: Using $vvs"

    if {[catch {eval [list exec BluePearlVVS $bpsProjectFile &]} results]} {
        puts stderr "ERROR: Problems launching BluePearlVVE $results"
        puts stderr "ERROR: $results"
        puts stderr "ERROR: Please check your path."
        return 0
    }   

    return 1
}
proc ::tclapp::bluepearl::bpsvvs::check_bps_env {} {
    set cli [auto_execok BluePearlCLI]
    if { $cli == {} } {
        puts stderr "ERROR: BluePearlCLI could not be found. Please check path."
        return 0;
    }
    set vve [auto_execok BluePearlVVE]
    if { $vve == {} } {
        puts stderr "ERROR: BluePearlVVE could not be found. Please check path."
        return 0;
    }
    return 1
}

proc ::tclapp::bluepearl::bpsvvs::update_vivado_into_bps {} {
    if { ![check_bps_env] } {
        return 0
    }

    set bpsProjectFile [getProjectFile]
    if { $bpsProjectFile == {} } {
        return 0
    }

    puts "INFO: Generating Blue Pearl tcl project file {$bpsProjectFile}"
    set aOK [generate_bps_project]
    if { $aOK != 0 } {
        puts stderr "ERROR: Problem generating project file $bpsProjectFile"
        return 0
    }

    set runs [get_runs]
    set srcSet [current_fileset -srcset]
    puts "INFO: Searching for implementation run for SRCSET $srcSet"
    set synthRun {}
    set implRun {}
    foreach run $runs {
        set flowType [get_property FLOW $run]
        set isImpl [get_property IS_IMPLEMENTATION $run]
        if {!$isImpl} {
            continue;
        }
        set implSrcSet [get_property SRCSET $run]
        if {[string match $srcSet $implSrcSet]} {
            set implRun $run
        }
    }
    if { $implRun == {} } {
        puts "ERROR: Implementation has not been run yet."
        return 0
    }

    puts "INFO: Opening implementation $implRun"
    open_run $implRun
    set loc [get_property DIRECTORY $implRun]

    puts "INFO: Running reports for data extraction"
    puts "INFO: Running timing report"
    set timingRep [file join $loc bps_timing_report.txt]
    report_timing_summary -max_paths 1 -file $timingRep
    puts "INFO: Running utilization report"
    set utilRep [file join $loc bps_utilization_report.txt]

    report_utilization -file [file join $loc bps_utilization_report.txt]
    puts "INFO: Running power report"
    set powerRep [file join $loc bps_power_report.txt]
    report_power -file $powerRep

    ## Open output file to write
    set projectDir [get_property DIRECTORY [current_project]]

    set utilConfigFile [file join $projectDir Xilinx_Vivado_utilconfig.xml]
    if {[file exists $utilConfigFile]} {
        set utilConfig "-config_file {$utilConfigFile}"
    } else {
        set utilConfig ""
    }


    set topModule [getTopModule]
    set execFile [file join $projectDir ${topModule}.execfile.tcl]
    if { [catch {open $execFile w} result] } {
        puts stderr "ERROR: Could not open $execFile for writing"
        puts stderr "$result"
        return 1
    } else {
        set ofs $result
        puts "INFO: Writing Blue Pearl tcl executable file to file {$execFile}"
    }

    puts $ofs "BPS::update_vivado_results -timing {$timingRep}"
    puts $ofs "BPS::update_vivado_results -utilization {$utilRep} $utilConfig"
    puts $ofs "BPS::update_vivado_results -power {$powerRep}"
    puts $ofs "exit"
    close $ofs

    puts "INFO: Launching BluePearlCLI -output Results -tcl $bpsProjectFile -tcl $execFile"
    set cli [auto_execok BluePearlCLI]
    puts "INFO: Using $cli"
    set wd [pwd]
    set projectDir [get_property DIRECTORY [current_project]]
    cd $projectDir
    if {[catch {eval [list exec BluePearlCLI -output Results -tcl $bpsProjectFile -tcl $execFile]} results]} {
        puts stderr "ERROR: Problems launching BluePearlCLI"
        puts stderr "ERROR: $results"
        puts stderr "ERROR: Please check your path."
        cd $wd
        return 0
    }   
    cd $wd
    puts $results
    return 1
}

