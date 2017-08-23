###############################################################################
#
# bluepearl_vvs.tcl (Routine for Bluepearl Visual Verification Suite App.)
#
# Script created on 6/2017 by Scott Aron Bloom (Blue Pearl Software, Inc) 
#                                 Scott Aron Bloom
#
# 2017.1 - v1.0 (rev 1.0)
#  * Initial Version
# 2017.2 - v1.1 (rev 1.1)
#  * Fix for missing global includes
#  * Fix for black boxed IP
#
###############################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::bluepearl::bpsvvs {
    # Export procs that should be allowed to import into other namespaces
    namespace export generate_bps_project
    namespace export launch_bps
    namespace export update_vivado_into_bps
    variable runBPS
    set runBPS 1
}

proc ::tclapp::bluepearl::bpsvvs::relto {reltodir file} {
    # Summary: Returns the relative path of $file to $reltodir

    # Argument Usage:
    # reltodir: The relative directory
    # file: The file or directory to return a relative path of

    # Return Value: the relative path of $file to $reltodir

    # Categories: xilinxtclstore, bpsvvs, bluepearl, visualverificationsuite

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
    # Summary: Returns true if the file is considered protected

    # Argument Usage:
    # fileName: The filename to check

    # Return Value: true or false

    # Categories: xilinxtclstore, bpsvvs, bluepearl, visualverificationsuite

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
    } elseif { [string match *c_counter_binary* $fileName] } {
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
    } elseif { [string match *xfft_* $fileName] } {
        return 1
    } else {
        return 0
    }
}

proc ::tclapp::bluepearl::bpsvvs::findIncludeDirs { files } {
    # Summary: Finds the include directories for a given list of files from an IP file list
    #          modifies the variable includeDirs of the calling function

    # Argument Usage:
    # files: The list of files from an IP file list

    # Return Value: none 

    # Categories: xilinxtclstore, bpsvvs, bluepearl, visualverificationsuite

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

proc ::tclapp::bluepearl::bpsvvs::addFilesToProject { fileGroupName files projectFS } {
    # Summary: Adds files to the project from for a given list of files from an IP file list

    # Argument Usage:
    # fileGroupName: The name of the file list, typically the name of the IP
    # files: the file list from the IP block
    # projectFS: the project file stream

    # Return Value: true if a file was missing or protected 

    # Categories: xilinxtclstore, bpsvvs, bluepearl, visualverificationsuite

    puts $projectFS "# $fileGroupName"
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
                puts $projectFS "#The following file does not exist, but is required for proper synthesis.";
                puts -nonewline $projectFS "#"
                set filesMissing 1
            } elseif { [isProtected $fileName] } {
                puts "INFO: File '$fileName' is protected.";
                puts -nonewline $projectFS "#"
                set filesMissing 1
            }
            set relToFile [relto $projectDir $fileName]
            puts $projectFS "BPS::add_input_files $libOption\[list \[file join \$BPS::project_rel_to_dir $relToFile\]\]"
            incr fileCount 
        }
    }
    if {$fileCount == 0} {
        puts $projectFS "# No files are required"
    }
    puts $projectFS "\n"
    return $filesMissing
}

proc ::tclapp::bluepearl::bpsvvs::getTopModule {} {
    # Summary: Determines the top module for the project

    # Argument Usage:

    # Return Value: returns the name of the top module

    # Categories: xilinxtclstore, bpsvvs, bluepearl, visualverificationsuite

    if { [catch {find_top}] } {
        puts stderr "ERROR: Current project is not set"
        return ""
    }
    set topModule [get_property top [current_fileset]]
    return $topModule
}

proc ::tclapp::bluepearl::bpsvvs::getProjectFile {} {
    # Summary: Determines the name of the project file

    # Argument Usage:

    # Return Value: returns the name of the project file

    # Categories: xilinxtclstore, bpsvvs, bluepearl, visualverificationsuite

    if { [catch {find_top}] } {
        puts stderr "ERROR: Current project is not set"
        return ""
    }
    set projectDir [get_property DIRECTORY [current_project]]
    set topModule [getTopModule]
    set bpsProjectFile [file join $projectDir ${topModule}.bluepearl_generated.tcl]
    return $bpsProjectFile
}

proc ::tclapp::bluepearl::bpsvvs::check_bps_env {} {
    # Summary : Checks the Blue Pearl environment for proper setup in the path

    # Argument Usage:

    # Return Value: Returns '1' on successful completion '0' on failure

    # Categories: xilinxtclstore, bpsvvs, bluepearl, visualverificationsuite

    variable runBPS
    if { !$runBPS } {
        puts "INFO: Running BPS has been disabled"
        return 1
    }

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


proc ::tclapp::bluepearl::bpsvvs::generate_bps_project {} {
    # Summary : Generates the Blue Pearl Tcl project file

    # Argument Usage:

    # Return Value: Returns '1' on successful completion '0' on failure

    # Categories: xilinxtclstore, bpsvvs, bluepearl, visualverificationsuite

    if { ![check_bps_env] } {
        return 0
    }

    puts "INFO: Calling ::tclapp::bluepearl::bpsvvs::generate_bps_project"

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

    puts $ofs "#Blue Pearl Visual Verification Suite Project File Generated by Vivado Generator version 1.1"
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
    set files [get_files -filter {FILE_TYPE == "Verilog Header"} -of [get_filesets]]
    findIncludeDirs $files 

    set files [get_files -norecurse -compile_order sources -used_in synthesis]
    findIncludeDirs $files 

	if { $includeDirs != "" } {
        foreach incdir $includeDirs {
            set curr [relto $projectDir $incdir]
            puts $ofs "set veri_include_dirs \[lappend veri_include_dirs \[file join \$BPS::project_rel_to_dir $curr\]\]"
        }
        puts $ofs ""
	}
	
    puts "INFO: Generating project for IP"
    puts "INFO: Found [llength $ips] IPs in the design"

    set missingFiles 0
    set allFiles [list]

    foreach ip $ips {
        set ipDef [get_property IPDEF $ip]
        set ipName [get_property NAME $ip]

        set files [get_files -quiet -compile_order sources -used_in synthesis -of_objects $ip]
        if {[llength $files] == 0} {
            set fileMissing 1
        } else {
            set fileMissing [addFilesToProject "IP $ipName" $files $ofs]
        }
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
    # Summary : Launches Blue Pearl Visual Verification Suite

    # Argument Usage:

    # Return Value: Returns '1' on successful completion '0' on failure

    # Categories: xilinxtclstore, bpsvvs, bluepearl, visualverificationsuite

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
    variable runBPS
    if { $runBPS } {
        set vvs [auto_execok BluePearlVVE]
        puts "INFO: Using $vvs"

        if {[catch {eval [list exec BluePearlVVE $bpsProjectFile &]} results]} {
            puts stderr "ERROR: Problems launching BluePearlVVE $results"
            puts stderr "ERROR: $results"
            puts stderr "ERROR: Please check your path."
            return 0
        }   
    }

    return 1
}

proc ::tclapp::bluepearl::bpsvvs::update_vivado_into_bps {} {
    # Summary : Updates the current results into the Blue Pearl Visual Verification Suite

    # Argument Usage:

    # Return Value: Returns '1' on successful completion '0' on failure

    # Categories: xilinxtclstore, bpsvvs, bluepearl, visualverificationsuite

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


    set topModule [getTopModule]
    puts "INFO: Running/Finding reports for data extraction"

    set timingRep [file join $loc ${topModule}_timing_summary_routed.rpt]
    if {[file exists $timingRep]} {
        puts "INFO: Using existing timing report '$timingRep'"
    } else {
        puts "INFO: Running timing report"
        report_timing_summary -max_paths 1 -file $timingRep
    }

    set utilRep [file join $loc ${topModule}_utilization_placed.rpt]
    if {[file exists $utilRep]} {
        puts "INFO: Using existing utilization report '$utilRep'"
    } else {
        puts "INFO: Running utilization report"
        report_utilization -file [file join $loc $utilRep]
    }

    set powerRep [file join $loc ${topModule}_power_routed.rpt]
    if {[file exists $powerRep]} {
        puts "INFO: Using existing power report '$powerRep'"
    } else {
        puts "INFO: Running power report"
        report_power -file $powerRep
    }

    ## Open output file to write
    set projectDir [get_property DIRECTORY [current_project]]

    set utilConfigFile [file join $projectDir Xilinx_Vivado_utilconfig.xml]
    if {[file exists $utilConfigFile]} {
        set utilConfig "-config_file {$utilConfigFile}"
    } else {
        set utilConfig ""
    }


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
    set wd [pwd]
    set projectDir [get_property DIRECTORY [current_project]]
    cd $projectDir
    variable runBPS
    if { $runBPS } {
        set cli [auto_execok BluePearlCLI]
        puts "INFO: Using $cli"
        if {[catch {eval [list exec BluePearlCLI -output Results -tcl $bpsProjectFile -tcl $execFile]} results]} {
            puts stderr "ERROR: Problems launching BluePearlCLI"
            puts stderr "ERROR: $results"
            puts stderr "ERROR: Please check your path."
            cd $wd
            return 0
        }   
    } else {
        set results "BluePearlCLI not run"
    }
    cd $wd
    puts $results
    return 1
}

