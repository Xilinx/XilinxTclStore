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

proc ::tclapp::bluepearl::bpsvvs::addFilesToProject { fileGroupName files project } {
    puts $project "# $fileGroupName"
    set filesMissing 0
    foreach file $files {
        set fileName [get_property NAME [lindex [get_files -all $file] 0]]
        set fileType [get_property FILE_TYPE [lindex [get_files -all $file] 0]]
        if {[string match $fileType "Verilog"] || [string match $fileType "Verilog Header"] || [string match $fileType "SystemVerilog"] || [string match $fileType "VHDL"]} {
            set fileSetName [get_property FILESET_NAME [lindex [get_files -all $file] 0]]
            set lib [get_property LIBRARY [lindex [get_files -all $file] 0]]
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
            }
            puts $project "BPS::add_input_files $libOption{$fileName}"
        }
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
    puts "Generating BPS Project File"
    # Summary : This proc generates the Blue Pearl tcl project file
    # Argument Usage:
    # Return Value: Returns '1' on successful completion
    # Categories: xilinxtclstore, blue pearl, visual verification suite

    puts "Calling ::tclapp::bluepearl::bpsvvs::generate_bps_project"

    ## Vivado install dir
    set vivado_dir $::env(XILINX_VIVADO)
    puts "INFO: Using Vivado installation directory $vivado_dir"

    if { [catch {find_top}] } {
        puts stderr "ERROR: Current project is not set"
        return 1
    }

    set bpsProjectFile [getProjectFile]
    if {[file exists $bpsProjectFile]} {
        puts "INFO: Backing up $bpsProjectFile"
        file copy -force $bpsProjectFile [file join ${bpsProjectFile}.bak]
    }

    puts "INFO: Generating Blue Pearl tcl project file $bpsProjectFile"

    ## Open output file to write
    if { [catch {open $bpsProjectFile w} result] } {
        puts stderr "ERROR: Could not open $bpsProjectFile for writing"
        puts stderr "$result"
        return 1
    } else {
        set ofs $result
        puts "INFO: Writing Blue Pearl tcl project file to file $bpsProjectFile"
    }

    puts $ofs "#Blue Pearl Visual Verification Suite Project File Generated by Vivado Generator version 1.0"
    puts $ofs "\n"
    puts $ofs "set BPS::project_results_dir Results"
    puts $ofs "\n"
    puts $ofs "BPS::set_xilinx_library 2016.4"
    puts $ofs "\n"
    puts $ofs "BPS::set_check_enabled -enabled false *"
    puts $ofs "BPS::set_package_enabled {UltraFast Design Methodology for Vivado}"
    puts $ofs "\n"
    set topModule [getTopModule]
    puts $ofs "set root_module $topModule" 
    puts $ofs "\n"

    set ips [get_ips -quiet *]
    puts "INFO: Found [llength $ips] IPs in the design"

    set missingFiles 0

    foreach ip $ips {
        set ipDef [get_property IPDEF $ip]
        set ipName [get_property NAME $ip]

        set files [get_files -quiet -compile_order sources -used_in synthesis -of_objects $ip]
        set fileMissing [addFilesToProject "IP $ipName" $files $ofs]
        if { $fileMissing || $missingFiles } {
            set missingFiles 1
        }
    }

    set files [get_files -norecurse -compile_order sources -used_in synthesis]
    addFilesToProject "User Files" $files $ofs 

    if { $missingFiles } {
        puts $ofs "set auto_create_black_boxes true"
    }

    close $ofs

    puts "INFO: Successfully wrote $bpsProjectFile"

    return 0
}


proc ::tclapp::bluepearl::bpsvvs::launch_bps {} {
    set bpsProjectFile [getProjectFile]
    if { $bpsProjectFile == {} } {
        puts stderr "ERROR: Current project is not set"
        return 0
    }

    puts "INFO: Generating Blue Pearl tcl project file $bpsProjectFile"
    set aOK [generate_bps_project]
    if { $aOK != 0 } {
        puts stderr "ERROR: Problem generating project file $bpsProjectFile"
        return 0
    }

    puts "INFO: Launching BluePearlVVE '$bpsProjectFile'"

    if {[catch {eval [list exec BluePearlVVE $bpsProjectFile &]} results]} {
        puts stderr "ERROR: Problems launching BluePearlVVE $results"
        return 0
    }   

    return 1
}

proc ::tclapp::bluepearl::bpsvvs::update_vivado_into_bps {} {
    set bpsProjectFile [getProjectFile]
    if { $bpsProjectFile == {} } {
        return 0
    }

    set runs [get_runs]

    puts "INFO: Searching for implementation run"
    set synthRun {}
    set implRun {}
    foreach run $runs {
        set flowType [get_property FLOW $run]
        if {[string match "*Implementation*" $flowType]} {
            set implRun $run
        } else {
            set syntRun $run
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
    report_timing -file [file join $loc bps_timing_report.txt]
    puts "INFO: Running utilization report"
    report_timing -file [file join $loc bps_utilization_report.txt]
    puts "INFO: Running power report"
    report_timing -file [file join $loc bps_power_report.txt]

    puts "INFO: Launching BluePearlCLI -output Results -e \"BPS::update_vivado_results -impl_dir {$loc} -timing bps_timing_report.txt -util bps_utilization_report.txt -power bps_power_report.txt; exit\""
    if {[catch {eval [list exec BluePearlCLI -e [list BPS::update_vivado_results -impl_dir $loc -timing bps_timing_report.txt -util bps_utilization_report.txt -power bps_power_report.txt; exit]]} results]} {
        puts stderr "ERROR: Problems launching BluePearlVVE $results"
        return 0
    }   
    puts $results

    return 1
}

