####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export archive
}

proc ::tclapp::xilinx::designutils::archive {newProjName} {

    # Summary : Archiving a Project
    
    # Argument Usage:
    # newProjName : project name to write archive to

    # Return Value:
    # none
	
    set currProjDir [file normalize [get_property directory [current_project]]]
    set currProj [file normalize "$currProjDir/[current_project].ppr"]
    puts "DEBUG:  $currProj EXISTS: [file exists $currProj]"
    
    # save the project to a new project name
    if {[file exists "$currProjDir/$newProjName.ppr"]} {
        # will not overwrite a project that already exists
        puts "ERROR:  A project already exists by this name:  $currProjDir/$newProjName.ppr"
        return
    }
    save_project_as -force -dir $currProjDir $newProjName

    # search all the verilog files for 'includes and make sure
    # they are included in the project
    foreach f [get_files -filter "file_type == Verilog"] {
        # search through all files for 'include
        # remove the leading curly brace
        regsub {^\{} $f {} f
        # remove the trailing curly brace
        regsub {\}$} $f {} f
        puts "INFO:  Parsing $f for 'include"
        # normalize the file name - replacing backslashes from windows
        set fh [open [file normalize $f]]
        while {[gets $fh line] >= 0} {
            # work with $line here ...
            if {[regexp {`include\s+\"(\S+)\"} $line matchVar includeFile]} {
                puts "INFO:  Found an include directive $includeFile"
                if {[llength [get_files */$includeFile]] > 0} {
                    puts "INFO:  Good, it is already in the project"
                    # TODO - suppose there are multiple versions in different dirs
                } else {
                    # else add it to the project
                    puts "INFO:  Adding $includeFile to the project"
                    # TODO - this probably should be made a header file
                    # in case it is not compilable as valid verilog standalone
                    add_files [file dirname $includeFile]
                }
            }
        }
        close $fh
    }

    # import all the sources and make them "local" to the project
    import_files [get_files]

    # close the archived project we just saved
    close_project

    # reopen the orig project
    open_project $currProj

    # zip up the archived project
    # TODO - not implemented yet
    # TODO - make it work for both linux and windows
    # exec {C:\Program Files\WinZip\WINZIP32.EXE}
    # -a -r C:\junk\foo.ppr.zip C:\junk\foo.*
    # tar -cvzf foo.ppr.tgz foo.*
}
